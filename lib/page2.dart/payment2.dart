// lib/page2.dart/payment2.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:intl/intl.dart';

class Payment2 extends StatefulWidget {
  const Payment2({super.key});

  @override
  State<Payment2> createState() => _Payment2State();
}

class _Payment2State extends State<Payment2> {
  String? wallet, id;
  bool isLoading = false;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> pendingPayments = [];
  List<Map<String, dynamic>> completedJobs = [];
  double totalEarnings = 0; // เพิ่มตัวแปรนี้เพื่อเก็บยอดรายได้ทั้งหมด

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _calculateTotalEarnings(); // เพิ่มการเรียกฟังก์ชันนี้
    _loadTransactions();
    _loadPendingPayments();
    _loadCompletedJobs();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      wallet = await SharedPreferenceHelper().getUserWallet();
      id = await SharedPreferenceHelper().getUserId();

      if (wallet == null || wallet!.isEmpty) {
        if (_currentUser != null) {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(_currentUser!.uid).get();

          if (userDoc.exists) {
            Map<String, dynamic>? userData =
                userDoc.data() as Map<String, dynamic>?;
            wallet = userData?['wallet'] ?? "0";
            await SharedPreferenceHelper().saveUserWallet(wallet!);
          } else {
            wallet = "0";
            await SharedPreferenceHelper().saveUserWallet(wallet!);
          }
        } else {
          wallet = "0";
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
      wallet = "0";
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    if (_currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      setState(() {
        transactions = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print("Error loading transactions: $e");
    }
  }

  Future<void> _calculateTotalEarnings() async {
    try {
      if (_currentUser == null) return;

      // ดึงข้อมูลการจองที่สถานะ 'completed'
      final completedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      // ดึงข้อมูลการจองที่สถานะ 'accepted' (งานที่กำลังดำเนินการ)
      final acceptedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      // คำนวณรายได้ทั้งหมด
      double earnings = 0;

      // จากงานที่เสร็จสิ้นแล้ว
      for (var doc in completedSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('totalPrice')) {
          earnings += (data['totalPrice'] as num).toDouble();
        }
      }

      // จากงานที่กำลังดำเนินการ
      for (var doc in acceptedSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('totalPrice')) {
          earnings += (data['totalPrice'] as num).toDouble();
        }
      }

      setState(() {
        totalEarnings = earnings;
      });
    } catch (e) {
      print("Error calculating total earnings: $e");
    }
  }

  Future<void> _loadPendingPayments() async {
    if (_currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('paymentStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> payments = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> booking = doc.data() as Map<String, dynamic>;

        // ดึงข้อมูลเจ้าของแมว
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(booking['userId']).get();

        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? 'Unknown User';

        payments.add({
          'id': doc.id,
          'amount': booking['totalPrice'],
          'userName': userName,
          'status': booking['status'],
          'date': booking['createdAt'],
        });
      }

      setState(() {
        pendingPayments = payments;
      });
    } catch (e) {
      print("Error loading pending payments: $e");
    }
  }

  Future<void> _loadCompletedJobs() async {
    if (_currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> jobs = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> booking = doc.data() as Map<String, dynamic>;

        // ดึงข้อมูลเจ้าของแมว
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(booking['userId']).get();

        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? 'Unknown User';

        jobs.add({
          'id': doc.id,
          'amount': booking['totalPrice'],
          'userName': userName,
          'paymentStatus': booking['paymentStatus'] ?? 'pending',
          'date': booking['completedAt'] ?? booking['createdAt'],
        });
      }

      setState(() {
        completedJobs = jobs;
      });
    } catch (e) {
      print("Error loading completed jobs: $e");
    }
  }

  Future<void> _withdrawMoney() async {
    if (_currentUser == null) return;

    // แสดงหน้าต่างให้ใส่จำนวนเงินที่ต้องการถอน
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ถอนเงิน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'จำนวนเงินที่ต้องการถอน',
                hintText: 'ยืนยันจำนวนเงินที่ต้องการถอน',
                prefixText: '฿ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')),
                );
                return;
              }

              if (amount > int.parse(wallet ?? "0")) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ยอดเงินไม่เพียงพอ')),
                );
                return;
              }

              Navigator.pop(context);
              await _processWithdrawal(amount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawal(int amount) async {
    if (_currentUser == null) return;

    setState(() => isLoading = true);

    try {
      // 1. อัพเดทยอดเงินใน wallet
      final currentWallet = int.parse(wallet ?? "0");
      final newWallet = currentWallet - amount;

      if (newWallet < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance')),
        );
        setState(() => isLoading = false);
        return;
      }

      wallet = newWallet.toString();

      // 2. อัพเดท SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(wallet!);

      // 3. อัพเดท Firestore
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'wallet': wallet});

      // 4. บันทึกประวัติการทำธุรกรรม
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .add({
        'amount': amount,
        'type': 'withdraw',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'processing', // ต้องรอการตรวจสอบจากแอดมิน
        'description': 'Withdraw to bank account',
      });

      // 5. บันทึกคำขอถอนเงิน
      await _firestore.collection('withdrawals').add({
        'userId': _currentUser!.uid,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. โหลดข้อมูลธุรกรรมใหม่
      _loadTransactions();

      // 7. แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal request for ฿$amount submitted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error processing withdrawal: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing withdrawal: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: const Text(
          'รายได้ของคุณ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _calculateTotalEarnings(); // เพิ่มการเรียกฟังก์ชันนี้
                await _loadTransactions();
                await _loadPendingPayments();
                await _loadCompletedJobs();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEarningsCard(),
                    const SizedBox(height: 20),
                    _buildEarningsSummary(), // เพิ่มส่วนนี้
                    const SizedBox(height: 20),
                    if (pendingPayments.isNotEmpty)
                      _buildPendingPaymentsSection(),
                    if (pendingPayments.isNotEmpty) const SizedBox(height: 20),
                    if (completedJobs.isNotEmpty) _buildCompletedJobsSection(),
                    if (completedJobs.isNotEmpty) const SizedBox(height: 20),
                    _buildTransactionHistorySection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _withdrawMoney,
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text('ถอนเงิน'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal, Colors.tealAccent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายได้จากการรับเลี้ยงแมว',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Icon(
                Icons.payments,
                color: Colors.white,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '฿${totalEarnings.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'เงินในระบบ: ฿${wallet ?? "0"}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'รายได้ทั้งหมด',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEarningsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปรายได้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEarningsStat(
                'งานที่เสร็จแล้ว',
                '${completedJobs.length}',
                Icons.check_circle_outline,
                Colors.green,
              ),
              _buildEarningsStat(
                'รอการชำระเงิน',
                '${pendingPayments.length}',
                Icons.pending_actions,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingPaymentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingPayments.length,
            itemBuilder: (context, index) {
              final payment = pendingPayments[index];
              final timestamp = payment['date'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final formattedDate = '${date.day}/${date.month}/${date.year}';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    child: const Icon(
                      Icons.pending_actions,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(
                    'Booking from ${payment['userName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      Text('Status: ${payment['status']} • $formattedDate'),
                  trailing: Text(
                    '฿${payment['amount']}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedJobsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Jobs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedJobs.length,
            itemBuilder: (context, index) {
              final job = completedJobs[index];
              final timestamp = job['date'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final formattedDate = '${date.day}/${date.month}/${date.year}';
              final isPaid = job['paymentStatus'] == 'completed';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPaid
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    child: Icon(
                      isPaid ? Icons.check_circle : Icons.access_time,
                      color: isPaid ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    'Job for ${job['userName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      '${isPaid ? 'Paid' : 'Payment pending'} • $formattedDate'),
                  trailing: Text(
                    '฿${job['amount']}',
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ประวัติรายรับ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          transactions.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'ไม่มีประวัติรายรับ',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isWithdraw = transaction['type'] == 'withdraw';
                    final isIncome = transaction['type'] == 'income';
                    final timestamp = transaction['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();
                    final formattedDate =
                        '${date.day}/${date.month}/${date.year}';

                    Color iconColor;
                    IconData iconData;

                    if (isWithdraw) {
                      iconColor = Colors.red;
                      iconData = Icons.account_balance_wallet;
                    } else if (isIncome) {
                      iconColor = Colors.green;
                      iconData = Icons.attach_money;
                    } else {
                      iconColor = Colors.blue;
                      iconData = Icons.swap_horiz;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.2),
                          child: Icon(
                            iconData,
                            color: iconColor,
                          ),
                        ),
                        title: Text(
                          transaction['description'] ??
                              (isWithdraw
                                  ? 'Withdrawal'
                                  : (isIncome
                                      ? 'Payment received'
                                      : 'Transaction')),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${transaction['status'] ?? 'completed'} • $formattedDate'),
                        trailing: Text(
                          '${isWithdraw ? '-' : '+'}฿${transaction['amount']}',
                          style: TextStyle(
                            color: isWithdraw ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
