import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Admin/SitterApprovalPage.dart';
import 'package:myproject/Admin/UserManagementPage.dart';
import 'package:myproject/Admin/BookingManagementPage.dart';
import 'package:myproject/Admin/SitterIncomeReport.dart';
import 'package:myproject/pages.dart/login.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ตัวแปรเก็บข้อมูลสถิติ
  int _pendingSittersCount = 0;
  int _approvedSittersCount = 0;
  int _totalUsersCount = 0;
  int _totalBookingsCount = 0;
  bool _isLoading = true;
  String _adminName = "ผู้ดูแลระบบ";
  String _adminEmail = "";
  String _adminPhoto = ""; // เพิ่มตัวแปรเก็บรูปโปรไฟล์แอดมิน

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadDashboardData();
  }

  // โหลดข้อมูลผู้ดูแลระบบ
  Future<void> _loadAdminInfo() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _adminName = userData['name'] ?? "ผู้ดูแลระบบ";
            _adminEmail = userData['email'] ?? "";
            _adminPhoto = userData['photo'] ?? ""; // เพิ่มการดึงค่ารูปโปรไฟล์
          });
        }
      }
    } catch (e) {
      print('Error loading admin info: $e');
    }
  }

  // โหลดข้อมูลสำหรับแสดงผลบน Dashboard
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // จำนวนผู้รับเลี้ยงแมวที่รอการอนุมัติ
      final pendingSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'pending')
          .get();

      // จำนวนผู้รับเลี้ยงแมวทั้งหมดที่อนุมัติแล้ว
      final approvedSittersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'approved')
          .get();

      // จำนวนผู้ใช้ทั้งหมด
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // จำนวนการจองทั้งหมด
      final bookingsSnapshot =
          await FirebaseFirestore.instance.collection('bookings').get();

      setState(() {
        _pendingSittersCount = pendingSittersSnapshot.docs.length;
        _approvedSittersCount = approvedSittersSnapshot.docs.length;
        _totalUsersCount = usersSnapshot.docs.length;
        _totalBookingsCount = bookingsSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันออกจากระบบ
  Future<void> _signOut() async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout,
                  color: Colors.deepOrange), // เปลี่ยนสีเป็น deepOrange
              SizedBox(width: 10),
              Text('ออกจากระบบ'),
            ],
          ),
          content: Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LogIn()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange, // เปลี่ยนสีเป็น deepOrange
              ),
              child: Text('ออกจากระบบ'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แดชบอร์ดผู้ดูแลระบบ'), // เปลี่ยนชื่อหัวข้อ
        backgroundColor: Colors.deepOrange, // เปลี่ยนสีเป็น deepOrange
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: Colors.deepOrange)) // เปลี่ยนสีเป็น deepOrange
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepOrange.shade50,
                    Colors.white
                  ], // เปลี่ยนสีเป็น deepOrange
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนข้อมูลผู้ดูแลระบบ
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: _adminPhoto.isNotEmpty
                                  ? NetworkImage(_adminPhoto)
                                  : null,
                              backgroundColor: _adminPhoto.isEmpty
                                  ? Colors.deepOrange.shade200
                                  : null,
                              child: _adminPhoto.isEmpty
                                  ? Icon(
                                      Icons.admin_panel_settings,
                                      size: 40,
                                      color: Colors.deepOrange.shade800,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ยินดีต้อนรับ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _adminName,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange
                                          .shade800, // เปลี่ยนสีเป็น deepOrange
                                    ),
                                  ),
                                  if (_adminEmail.isNotEmpty)
                                    Text(
                                      _adminEmail,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // สรุปข้อมูลทั่วไป
                    Row(
                      children: [
                        Icon(Icons.dashboard,
                            color: Colors.deepOrange), // เพิ่มไอคอนหน้าหัวข้อ
                        SizedBox(width: 8),
                        Text(
                          'ภาพรวมระบบ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // แสดงข้อมูลสรุป
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _buildStatCard(
                          'ผู้รับเลี้ยงแมวรออนุมัติ',
                          _pendingSittersCount.toString(),
                          Icons.pending_actions,
                          Colors.amber, // เปลี่ยนสีเป็น amber
                          _pendingSittersCount > 0,
                        ),
                        _buildStatCard(
                          'ผู้รับเลี้ยงแมวทั้งหมด',
                          _approvedSittersCount.toString(),
                          Icons.check_circle,
                          Colors.green,
                          false,
                        ),
                        _buildStatCard(
                          'ผู้ใช้ทั้งหมด',
                          _totalUsersCount.toString(),
                          Icons.people,
                          Colors.blue,
                          false,
                        ),
                        _buildStatCard(
                          'การจองทั้งหมด',
                          _totalBookingsCount.toString(),
                          Icons.calendar_month,
                          Colors.purple,
                          false,
                        ),
                      ],
                    ),

                    SizedBox(height: 30),

                    // เมนูการจัดการระบบ
                    Row(
                      children: [
                        Icon(Icons.settings,
                            color: Colors.deepOrange), // เพิ่มไอคอนหน้าหัวข้อ
                        SizedBox(width: 8),
                        Text(
                          'การจัดการระบบ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // เมนูต่างๆ ใช้ฟังก์ชัน _buildMenuCard
                    _buildMenuCard(
                      'อนุมัติผู้รับเลี้ยงแมว',
                      'จัดการคำขอสมัครเป็นผู้รับเลี้ยงแมว',
                      Icons.person_add,
                      Colors.amber,
                      _pendingSittersCount.toString(),
                      _pendingSittersCount > 0 ? Colors.red : Colors.grey,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SitterApprovalPage(),
                          ),
                        ).then((_) => _loadDashboardData());
                      },
                    ),
                    SizedBox(height: 10),

                    _buildMenuCard(
                      'จัดการผู้ใช้งาน',
                      'ดูและจัดการข้อมูลผู้ใช้ทั้งหมด',
                      Icons.people,
                      Colors.blue,
                      _totalUsersCount.toString(),
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserManagementPage(), // เปลี่ยนเป็นเรียกใช้คลาสที่แยกออกไป
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10),

                    _buildMenuCard(
                      'จัดการการจอง',
                      'ดูและจัดการข้อมูลการจองทั้งหมด',
                      Icons.calendar_month,
                      Colors.purple,
                      _totalBookingsCount.toString(),
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookingManagementPage(), // เปลี่ยนเป็นเรียกใช้คลาสที่แยกออกไป
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 10),

                    // เพิ่มเมนูรายงานรายได้พี่เลี้ยง
                    _buildMenuCard(
                      'รายงานรายได้พี่เลี้ยง',
                      'ดูรายงานรายได้ของพี่เลี้ยงแมวทั้งหมด',
                      Icons.attach_money,
                      Colors.green,
                      '',
                      Colors.transparent,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SitterIncomeReport(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 30),

                    // ข้อความเกี่ยวกับระบบ
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Colors.blue,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ข้อมูลระบบ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'แอปพลิเคชันรับเลี้ยงแมวนี้ช่วยให้ผู้ดูแลระบบสามารถจัดการผู้รับเลี้ยงแมวได้อย่างมีประสิทธิภาพ เพื่อให้ระบบมีความน่าเชื่อถือและปลอดภัยสำหรับผู้ใช้งาน',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'เวอร์ชัน 1.0.0 - อัพเดทล่าสุด: พฤษภาคม 2025', // เพิ่มข้อมูลเวอร์ชัน
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget สำหรับสร้างการ์ดแสดงข้อมูลสถิติ
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, bool highlight) {
    return Card(
      elevation: highlight ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: highlight ? color : Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // เพิ่มฟังก์ชัน _buildMenuCard สำหรับทำเมนูให้เป็นระเบียบ
  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    String badgeText,
    Color badgeColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
