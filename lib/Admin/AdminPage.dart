import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/ApprovalPage.dart';
import 'package:myproject/Admin/BookingDetailPage.dart';
import 'package:myproject/Admin/SitterIncomeReport.dart';

class AdminPage extends StatefulWidget {
  final int pendingApprovals;

  const AdminPage({Key? key, this.pendingApprovals = 0}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 4, vsync: this); // เปลี่ยนจาก 3 เป็น 4
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ฟังก์ชันลบข้อมูลผู้ใช้
  Future<void> _deleteUser(String userId, String userType) async {
    try {
      setState(() => _isLoading = true);

      // ลบข้อมูลผู้ใช้จาก Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // ถ้าเป็น user ให้ลบข้อมูลแมวด้วย
      if (userType == 'user') {
        final catsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cats')
            .get();

        // ลบรูปแมวจาก Storage
        for (var doc in catsSnapshot.docs) {
          final catData = doc.data();
          if (catData['imagePath'] != null) {
            try {
              await FirebaseStorage.instance
                  .refFromURL(catData['imagePath'])
                  .delete();
            } catch (e) {
              print('Error deleting cat image: $e');
            }
          }
          // ลบข้อมูลแมวจาก Firestore
          await doc.reference.delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบข้อมูลสำเร็จ')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันลบแมว
  Future<void> _deleteCat(
      String userId, String catId, String? imagePath) async {
    try {
      setState(() => _isLoading = true);

      // ลบรูปแมวจาก Storage (ถ้ามี)
      if (imagePath != null) {
        try {
          await FirebaseStorage.instance.refFromURL(imagePath).delete();
        } catch (e) {
          print('Error deleting cat image: $e');
        }
      }

      // ลบข้อมูลแมวจาก Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cats')
          .doc(catId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบข้อมูลแมวสำเร็จ')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        actions: [
          // เพิ่มปุ่มดูรายงานรายได้
          IconButton(
            icon: const Icon(Icons.monetization_on),
            tooltip: 'รายงานรายได้',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SitterIncomeReport()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ผู้ใช้ทั่วไป'),
            Tab(text: 'พี่เลี้ยง'),
            Tab(text: 'แมว'),
            Tab(text: 'การจอง'), // เพิ่มแท็บใหม่
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList('user'),
                      _buildUserList('sitter'),
                      _buildCatsList(),
                      _buildBookingsList(), // เพิ่มหน้าแสดงการจอง
                    ],
                  ),
          ),
          ListTile(
            leading: Icon(Icons.approval, color: Colors.green),
            title: Text(
              'อนุมัติผู้รับเลี้ยงแมว',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ApprovalPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(String userType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: userType)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return Center(
              child: Text(
                  'ไม่พบข้อมูล${userType == 'user' ? 'ผู้ใช้' : 'พี่เลี้ยง'}'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: userData['photo'] != null
                      ? NetworkImage(userData['photo'])
                      : null,
                  child: userData['photo'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(userData['name'] ?? 'ไม่ระบุชื่อ'),
                subtitle: Text(userData['email'] ?? 'ไม่ระบุอีเมล'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(
                    users[index].id,
                    userType,
                    userData['name'] ?? 'ผู้ใช้นี้',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${userSnapshot.error}'));
        }

        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: userSnapshot.data!.docs.length,
          itemBuilder: (context, userIndex) {
            final userId = userSnapshot.data!.docs[userIndex].id;
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('cats')
                  .snapshots(),
              builder: (context, catSnapshot) {
                if (catSnapshot.hasError || !catSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final cats = catSnapshot.data!.docs;
                if (cats.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'แมวของ: ${(userSnapshot.data!.docs[userIndex].data() as Map<String, dynamic>)['name'] ?? 'ไม่ระบุชื่อ'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...cats.map((cat) {
                      final catData = cat.data() as Map<String, dynamic>;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: catData['imagePath'] != null
                                ? NetworkImage(catData['imagePath'])
                                : null,
                            child: catData['imagePath'] == null
                                ? const Icon(Icons.pets)
                                : null,
                          ),
                          title: Text(catData['name'] ?? 'ไม่ระบุชื่อแมว'),
                          subtitle:
                              Text(catData['breed'] ?? 'ไม่ระบุสายพันธุ์'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteCatConfirmation(
                              userId,
                              cat.id,
                              catData['name'] ?? 'แมวตัวนี้',
                              catData['imagePath'],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!.docs;

        if (bookings.isEmpty) {
          return const Center(child: Text('ไม่พบข้อมูลการจอง'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final bookingData = bookings[index].data() as Map<String, dynamic>;
            final bookingId = bookings[index].id;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(bookingData['userId'])
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final userData = userSnapshot.data!.exists
                    ? userSnapshot.data!.data() as Map<String, dynamic>
                    : {'name': 'ไม่พบข้อมูลผู้ใช้'};

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(bookingData['sitterId'])
                      .get(),
                  builder: (context, sitterSnapshot) {
                    if (!sitterSnapshot.hasData) {
                      return const Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    final sitterData = sitterSnapshot.data!.exists
                        ? sitterSnapshot.data!.data() as Map<String, dynamic>
                        : {'name': 'ไม่พบข้อมูลพี่เลี้ยง'};

                    final statusColor =
                        _getStatusColor(bookingData['status'] ?? 'pending');
                    final statusText =
                        _getStatusText(bookingData['status'] ?? 'pending');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        // เพิ่ม InkWell เพื่อให้คลิกได้
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingDetailPage(
                                bookingId: bookingId,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'รหัสการจอง: ${bookingId.substring(0, 8)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ผู้จอง',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          userData['name'] ?? 'ไม่ระบุชื่อ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'พี่เลี้ยง',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          sitterData['name'] ?? 'ไม่ระบุชื่อ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'วันที่',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDates(
                                              bookingData['dates'] ?? []),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ราคา',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '฿${bookingData['totalPrice'] ?? 0}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (bookingData['status'] == 'pending')
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _updateBookingStatus(
                                            bookingId, 'cancelled'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                              color: Colors.red),
                                        ),
                                        child: const Text('ยกเลิก'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _updateBookingStatus(
                                            bookingId, 'confirmed'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Text('ยืนยัน'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes = dates
        .map((date) => date is Timestamp ? date.toDate() : DateTime.now())
        .toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('อัพเดทสถานะเป็น ${_getStatusText(newStatus)} สำเร็จ')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation(String userId, String userType, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบข้อมูลของ $name ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(userId, userType);
              },
              child: const Text(
                'ลบ',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCatConfirmation(
      String userId, String catId, String name, String? imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบข้อมูลของ $name ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCat(userId, catId, imagePath);
              },
              child: const Text(
                'ลบ',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
