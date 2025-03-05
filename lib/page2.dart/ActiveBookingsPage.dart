import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ActiveBookingsPage extends StatefulWidget {
  const ActiveBookingsPage({Key? key}) : super(key: key);

  @override
  State<ActiveBookingsPage> createState() => _ActiveBookingsPageState();
}

class _ActiveBookingsPageState extends State<ActiveBookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _activeBookings = [];

  @override
  void initState() {
    super.initState();
    _loadActiveBookings();
  }

  Future<void> _loadActiveBookings() async {
    setState(() => _isLoading = true);

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ดึงข้อมูลการจองที่สถานะ 'accepted'
      final snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> bookings = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> booking = doc.data();
        booking['id'] = doc.id;

        // ดึงข้อมูลเจ้าของแมว
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(booking['userId']).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          booking['userName'] = userData['name'] ?? 'ไม่ระบุชื่อ';
          booking['userPhoto'] = userData['photo'] ?? '';
        }

        bookings.add(booking);
      }

      setState(() {
        _activeBookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading active bookings: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
        );
      }
    }
  }

  Future<void> _completeBooking(String bookingId) async {
    try {
      // แสดงกล่องยืนยันก่อนทำเครื่องหมายเสร็จสิ้น
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ยืนยันการเสร็จสิ้นงาน'),
          content: const Text(
              'คุณต้องการยืนยันว่างานนี้เสร็จสิ้นแล้วใช่หรือไม่? หลังจากยืนยันแล้วไม่สามารถเปลี่ยนกลับได้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _firestore.collection('bookings').doc(bookingId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // รีโหลดข้อมูล
        _loadActiveBookings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('งานเสร็จสิ้นเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error completing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'งานที่กำลังดำเนินการ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.work_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ไม่มีงานที่กำลังดำเนินการ',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activeBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _activeBookings[index];
                    final dates = (booking['dates'] as List<dynamic>?)
                            ?.map((date) => (date as Timestamp).toDate())
                            .toList() ??
                        [];

                    // จัดการกับวันที่
                    String dateRange;
                    if (dates.isEmpty) {
                      dateRange = 'ไม่ระบุวันที่';
                    } else if (dates.length == 1) {
                      dateRange = DateFormat('d MMM yyyy').format(dates[0]);
                    } else {
                      dates.sort();
                      dateRange =
                          '${DateFormat('d MMM').format(dates[0])} - ${DateFormat('d MMM yyyy').format(dates.last)}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: Colors.teal.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              radius: 30,
                              backgroundImage: booking['userPhoto'] != null &&
                                      booking['userPhoto'].isNotEmpty
                                  ? NetworkImage(booking['userPhoto'])
                                  : null,
                              child: booking['userPhoto'] == null ||
                                      booking['userPhoto'].isEmpty
                                  ? const Icon(Icons.person, size: 30)
                                  : null,
                            ),
                            title: Text(
                              booking['userName'] ?? 'ไม่ระบุชื่อ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('วันที่: $dateRange'),
                                Text(
                                    'จำนวนแมว: ${(booking['catIds'] as List<dynamic>?)?.length ?? 0} ตัว'),
                                Text('ราคา: ฿${booking['totalPrice'] ?? 0}'),
                              ],
                            ),
                          ),
                          const Divider(height: 0),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // ดูรายละเอียดแมว
                                    _showCatDetails(booking);
                                  },
                                  icon: const Icon(Icons.pets),
                                  label: const Text('ดูข้อมูลแมว'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.teal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _completeBooking(booking['id']),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('เสร็จสิ้น'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _showCatDetails(Map<String, dynamic> booking) async {
    try {
      final List<dynamic> catIds = booking['catIds'] ?? [];
      if (catIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีข้อมูลแมว')),
        );
        return;
      }

      // ดึงข้อมูลแมว
      List<Map<String, dynamic>> cats = [];
      for (String catId in catIds) {
        DocumentSnapshot catDoc = await _firestore
            .collection('users')
            .doc(booking['userId'])
            .collection('cats')
            .doc(catId)
            .get();

        if (catDoc.exists) {
          Map<String, dynamic> catData = catDoc.data() as Map<String, dynamic>;
          catData['id'] = catDoc.id;
          cats.add(catData);
        }
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ข้อมูลแมว',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                if (cats.isEmpty)
                  const Center(child: Text('ไม่พบข้อมูลแมว'))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final cat = cats[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: cat['imagePath'] != null &&
                                        cat['imagePath'].isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(cat['imagePath']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: cat['imagePath'] == null ||
                                      cat['imagePath'].isEmpty
                                  ? const Icon(Icons.pets, color: Colors.grey)
                                  : null,
                            ),
                            title: Text(
                              cat['name'] ?? 'ไม่ระบุชื่อ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('พันธุ์: ${cat['breed'] ?? 'ไม่ระบุ'}'),
                                Text(
                                    'วัคซีน: ${cat['vaccinations'] ?? 'ไม่ระบุ'}'),
                                if (cat['description'] != null &&
                                    cat['description'].isNotEmpty)
                                  Text('รายละเอียด: ${cat['description']}'),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error showing cat details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }
}
