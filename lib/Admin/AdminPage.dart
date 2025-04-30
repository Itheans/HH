import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Admin/SitterApprovalPage.dart';
import 'package:myproject/pages.dart/login.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  // ตัวแปรเก็บข้อมูลสถิติ
  int _pendingSittersCount = 0;
  int _approvedSittersCount = 0;
  int _totalUsersCount = 0;
  int _totalBookingsCount = 0;
  bool _isLoading = true;
  String _adminName = "ผู้ดูแลระบบ";
  String _adminEmail = "";

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
              Icon(Icons.logout, color: Colors.orange),
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
                backgroundColor: Colors.orange,
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
        title: Text('ผู้ดูแลระบบ'),
        backgroundColor: Colors.orange,
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
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade50, Colors.white],
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
                              backgroundColor: Colors.orange.shade200,
                              child: Icon(
                                Icons.admin_panel_settings,
                                size: 40,
                                color: Colors.orange.shade800,
                              ),
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
                                      color: Colors.orange.shade800,
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
                    Text(
                      'ภาพรวมระบบ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
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
                          Colors.orange,
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
                    Text(
                      'การจัดการระบบ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),

                    // เมนูการอนุมัติผู้รับเลี้ยงแมว
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SitterApprovalPage(),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  color: Colors.orange.shade700,
                                  size: 30,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'อนุมัติผู้รับเลี้ยงแมว',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'จัดการคำขอสมัครเป็นผู้รับเลี้ยงแมว',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _pendingSittersCount > 0
                                      ? Colors.red
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_pendingSittersCount',
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
                    ),
                    SizedBox(height: 10),

                    // สามารถเพิ่มเมนูอื่นๆ ได้ในอนาคต เช่น
                    // - จัดการรายงานปัญหา
                    // - ดูรายงานสรุป
                    // - จัดการผู้ใช้ทั้งหมด
                    // - การตั้งค่าระบบ
                    // โดยเพิ่มแต่ละเมนูในรูปแบบเดียวกับด้านบน

                    SizedBox(height: 40),

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
                            'ระบบรับเลี้ยงแมวนี้ช่วยให้ผู้ดูแลระบบสามารถจัดการผู้รับเลี้ยงแมวได้อย่างมีประสิทธิภาพ เพื่อให้ระบบมีความน่าเชื่อถือและปลอดภัยสำหรับผู้ใช้งาน',
                            style: TextStyle(
                              color: Colors.blue.shade800,
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
}
