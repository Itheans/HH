import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:fl_chart/fl_chart.dart';

class ScheduleIncomePage extends StatefulWidget {
  const ScheduleIncomePage({Key? key}) : super(key: key);

  @override
  State<ScheduleIncomePage> createState() => _ScheduleIncomePageState();
}

class _ScheduleIncomePageState extends State<ScheduleIncomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ปฏิทิน
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // ข้อมูลการจอง
  Map<DateTime, List<dynamic>> _bookingEvents = {};
  // ข้อมูลเกี่ยวกับรายได้
  double _totalIncome = 0;
  double _monthlyIncome = 0;
  double _weeklyIncome = 0;
  bool _isLoading = true;

  // ข้อมูลสำหรับกราฟ
  List<FlSpot> _incomeChartData = [];
  double _maxY = 1000; // ค่าเริ่มต้นสำหรับแกน Y

  // รายการการจองตามวันที่เลือก
  List<dynamic> _selectedEvents = [];

  // เพิ่มแคชข้อมูลผู้ใช้เพื่อลดการเรียก Firestore ซ้ำๆ
  Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _loadBookingEvents();
    _loadIncomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // เพิ่มฟังก์ชันในการดึงข้อมูลผู้ใช้
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    // ตรวจสอบแคชข้อมูลก่อน
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        // เก็บข้อมูลในแคช
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // โหลดข้อมูลการจอง
  Future<void> _loadBookingEvents() async {
    setState(() => _isLoading = true);

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ดึงข้อมูลการจองที่ได้รับการยอมรับแล้ว
      final QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', whereIn: [
        'accepted',
        'completed'
      ]) // รวมทั้งสถานะ accepted และ completed
          .get();

      final Map<DateTime, List<dynamic>> events = {};

      for (var doc in snapshot.docs) {
        // สร้าง ID สำหรับการจอง
        final bookingId = doc.id;

        // ดึงข้อมูลจากเอกสาร
        final data = doc.data() as Map<String, dynamic>;

        // เพิ่ม ID เข้าไปในข้อมูล
        data['id'] = bookingId;

        // ดึงข้อมูลวันที่
        final List<dynamic> dates = data['dates'] ?? [];

        // ล่วงหน้าโหลดข้อมูลผู้ใช้เพื่อแคช
        if (data.containsKey('userId')) {
          final userId = data['userId'] as String;
          await _getUserData(userId);
        }

        for (var dateData in dates) {
          final DateTime date = (dateData as Timestamp).toDate();
          final DateTime dateKey = DateTime(date.year, date.month, date.day);

          if (events[dateKey] != null) {
            events[dateKey]!.add(data);
          } else {
            events[dateKey] = [data];
          }
        }
      }

      setState(() {
        _bookingEvents = events;
        _selectedEvents = _getEventsForDay(_selectedDay!);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking events: $e');
      setState(() => _isLoading = false);
    }
  }

  // โหลดข้อมูลรายได้
  Future<void> _loadIncomeData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      // ดึงข้อมูลการจองที่ยอมรับแล้ว
      final QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['accepted', 'completed']).get();

      double total = 0;
      double monthly = 0;
      double weekly = 0;

      // ข้อมูลรายได้ตามเดือน สำหรับกราฟ
      Map<int, double> monthlyData = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['totalPrice'] ?? 0).toDouble();
        final createdAt = data['createdAt'] as Timestamp?;

        if (createdAt != null) {
          final date = createdAt.toDate();

          // รายได้ทั้งหมด
          total += price;

          // รายได้รายเดือน
          if (date.isAfter(startOfMonth) ||
              date.isAtSameMomentAs(startOfMonth)) {
            monthly += price;
          }

          // รายได้รายสัปดาห์
          if (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek)) {
            weekly += price;
          }

          // รวบรวมข้อมูลสำหรับกราฟ
          final int monthKey = date.month;
          if (monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = monthlyData[monthKey]! + price;
          } else {
            monthlyData[monthKey] = price;
          }
        }
      }

      // สร้างข้อมูลสำหรับกราฟ
      List<FlSpot> chartData = [];
      double maxIncome = 0;

      monthlyData.forEach((month, income) {
        chartData.add(FlSpot(month.toDouble(), income));
        if (income > maxIncome) maxIncome = income;
      });

      // เรียงลำดับตามเดือน
      chartData.sort((a, b) => a.x.compareTo(b.x));

      setState(() {
        _totalIncome = total;
        _monthlyIncome = monthly;
        _weeklyIncome = weekly;
        _incomeChartData = chartData;
        _maxY = maxIncome > 0
            ? maxIncome * 1.2
            : 1000; // เพิ่มพื้นที่ด้านบนของกราฟ 20%
      });
    } catch (e) {
      print('Error loading income data: $e');
    }
  }

  // แก้ไขฟังก์ชัน _completeBooking
  Future<void> _completeBooking(String bookingId) async {
    try {
      // ดึงข้อมูลการจองเพื่อเอายอดเงิน
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('ไม่พบข้อมูลการจอง');
      }

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;
      double bookingAmount = 0;
      if (bookingData.containsKey('totalPrice')) {
        bookingAmount = (bookingData['totalPrice'] as num).toDouble();
      }

      // ดึงข้อมูล wallet ปัจจุบัน
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      // คำนวณยอดเงินใหม่
      double currentWallet = 0;
      if (userData != null && userData.containsKey('wallet')) {
        String walletStr = userData['wallet'] ?? "0";
        currentWallet = double.tryParse(walletStr) ?? 0;
      }

      double newWallet = currentWallet + bookingAmount;
      String walletStr = newWallet.toStringAsFixed(0);

      // อัพเดตสถานะงานและเพิ่มยอดเงินใน wallet พร้อมกัน
      await _firestore.runTransaction((transaction) async {
        // อัพเดตสถานะงาน
        transaction.update(_firestore.collection('bookings').doc(bookingId), {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'paymentStatus': 'completed', // เพิ่มสถานะการชำระเงิน
        });

        // อัพเดตยอดเงินใน wallet
        transaction
            .update(_firestore.collection('users').doc(currentUser.uid), {
          'wallet': walletStr,
        });
      });

      // บันทึกประวัติการทำธุรกรรม
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('transactions')
          .add({
        'amount': bookingAmount,
        'type': 'income',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'description': 'รายได้จากการรับเลี้ยงแมว',
        'bookingId': bookingId,
      });

      // อัพเดต SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(walletStr);

      // รีโหลดข้อมูล
      await _loadBookingEvents();
      await _loadIncomeData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('การดูแลเสร็จสิ้นเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error completing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  // ดึงรายการการจองตามวันที่
  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _bookingEvents[normalizedDay] ?? [];
  }

  void _showBookingDetailsDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('รายละเอียดการจอง'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('ชื่อผู้จอง', booking['userName'] ?? 'ไม่ระบุ'),
                _buildDetailRow('วันที่', booking['date'] ?? 'ไม่ระบุ'),
                _buildDetailRow('เวลา', booking['time'] ?? 'ไม่ระบุ'),
                _buildDetailRow('บริการ', booking['serviceName'] ?? 'ไม่ระบุ'),
                _buildDetailRow('ราคา', '${booking['totalPrice'] ?? 0} บาท'),
                _buildDetailRow('สถานะ', booking['status'] ?? 'ไม่ระบุ'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ตารางงานและรายได้',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ตารางงาน'),
            Tab(text: 'รายได้'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleTab(),
          _buildIncomeTab(),
        ],
      ),
    );
  }

  // แท็บตารางงาน
  Widget _buildScheduleTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // ปฏิทิน
              TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedEvents = _getEventsForDay(selectedDay);
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'รายการการจองในวันที่เลือก',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _selectedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่มีรายการในวันที่เลือก',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _selectedEvents.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final booking =
                              _selectedEvents[index] as Map<String, dynamic>;
                          final String userId =
                              booking['userId'] as String? ?? '';

                          // แสดงตัวโหลดขณะรอข้อมูลผู้ใช้
                          if (userId.isEmpty) {
                            return _buildBookingCardSkeleton();
                          }

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _getUserData(userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return _buildBookingCardSkeleton();
                              }

                              if (!snapshot.hasData || snapshot.data == null) {
                                return _buildBookingCardError(booking);
                              }

                              final userData = snapshot.data!;
                              final userName =
                                  userData['name'] ?? 'ไม่ระบุชื่อ';
                              final userPhoto = userData['photo'] ?? '';

                              return _buildBookingCard(
                                  booking, userName, userPhoto);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
  }

  // สร้าง Card แบบ Skeleton (โครงร่าง) สำหรับแสดงขณะกำลังโหลดข้อมูล
  Widget _buildBookingCardSkeleton() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 90,
        child: Row(
          children: [
            // Skeleton สำหรับรูปโปรไฟล์
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Skeleton สำหรับชื่อ
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Skeleton สำหรับข้อมูลเพิ่มเติม
                  Container(
                    width: 180,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Skeleton สำหรับไอคอน
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // สร้าง Card แสดงข้อผิดพลาด
  Widget _buildBookingCardError(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.red[50],
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Colors.red[100],
          child: const Icon(Icons.error_outline, color: Colors.red),
        ),
        title: const Text(
          'ไม่สามารถโหลดข้อมูลผู้ใช้',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('การจองรหัส: ${booking['id'] ?? "ไม่ระบุ"}'),
            Row(
              children: [
                Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${(booking['catIds'] as List<dynamic>?)?.length ?? 0} ตัว',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payments, size: 16, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  '${booking['totalPrice'] ?? 0} บาท',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () {
          // แสดงรายละเอียดการจอง
          _showBookingDetailsDialog(booking);
        },
      ),
    );
  }

  // สร้าง Card แสดงข้อมูลการจอง
  Widget _buildBookingCard(
      Map<String, dynamic> booking, String userName, String userPhoto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundImage:
              userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
          child: userPhoto.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(
          userName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${(booking['catIds'] as List<dynamic>?)?.length ?? 0} ตัว',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payments, size: 16, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  '${booking['totalPrice'] ?? 0} บาท',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () {
          // แสดงรายละเอียดการจอง
          _showBookingDetailsDialog(booking);
        },
      ),
    );
  }

  // แท็บรายได้
  Widget _buildIncomeTab() {
    final currencyFormat =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // สรุปรายได้
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายได้ทั้งหมด',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(_totalIncome),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // รายได้รายเดือนและรายสัปดาห์
            Row(
              children: [
                Expanded(
                  child: _buildIncomeCard(
                    'รายได้เดือนนี้',
                    _monthlyIncome,
                    Colors.blue,
                    Icons.calendar_month,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildIncomeCard(
                    'รายได้สัปดาห์นี้',
                    _weeklyIncome,
                    Colors.amber,
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // สถิติรายได้
            const Text(
              'สถิติรายได้รายเดือน',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _incomeChartData.isEmpty
                  ? _buildEmptyChartMessage()
                  : _buildIncomeChart(),
            ),
            const SizedBox(height: 24),

            // การวิเคราะห์รายได้
            _buildIncomeAnalysis(),
          ],
        ),
      ),
    );
  }

  // ข้อความเมื่อไม่มีข้อมูลกราฟ
  Widget _buildEmptyChartMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีข้อมูลรายได้',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ข้อมูลจะแสดงเมื่อคุณมีรายได้จากการรับเลี้ยงแมว',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // การ์ดแสดงรายได้
  Widget _buildIncomeCard(
      String title, double amount, Color color, IconData icon) {
    final currencyFormat =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // กราฟรายได้
  Widget _buildIncomeChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        minX: 1,
        maxX: 12,
        minY: 0,
        maxY: _maxY,
        lineBarsData: [
          LineChartBarData(
            spots: _incomeChartData,
            isCurved: true,
            color: Colors.teal,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.teal.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // การวิเคราะห์รายได้
  Widget _buildIncomeAnalysis() {
    final currencyFormat =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'การวิเคราะห์รายได้',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildAnalysisRow(
          'รายได้เฉลี่ยต่อเดือน',
          currencyFormat.format(_totalIncome / 12),
        ),
        const SizedBox(height: 8),
        _buildAnalysisRow(
          'รายได้เฉลี่ยต่อสัปดาห์',
          currencyFormat.format(_totalIncome / 52),
        ),
        const SizedBox(height: 8),
        _buildAnalysisRow(
          'รายได้เฉลี่ยต่อวัน',
          currencyFormat.format(_totalIncome / 365),
        ),
      ],
    );
  }

  // แถวการวิเคราะห์รายได้
  Widget _buildAnalysisRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
