import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/page2.dart/nevbarr..dart';
import 'package:myproject/pages.dart/buttomnav.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/services/shared_pref.dart';

class CheckStatusWrapper extends StatefulWidget {
  const CheckStatusWrapper({Key? key}) : super(key: key);

  @override
  State<CheckStatusWrapper> createState() => _CheckStatusWrapperState();
}

class _CheckStatusWrapperState extends State<CheckStatusWrapper> {
  bool _isLoading = true;
  Widget? _targetWidget;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบว่ามีการล็อกอินอยู่หรือไม่
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        // ไม่มีการลงชื่อเข้าใช้ -> ไปที่หน้าล็อกอิน
        setState(() {
          _targetWidget = LogIn();
          _isLoading = false;
        });
        return;
      }

      // ดึงข้อมูลผู้ใช้จาก Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        // ไม่พบข้อมูลผู้ใช้ -> ออกจากระบบและไปที่หน้าล็อกอิน
        await FirebaseAuth.instance.signOut();
        setState(() {
          _targetWidget = LogIn();
          _isLoading = false;
        });
        return;
      }

      // ตรวจสอบข้อมูลผู้ใช้
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'] ?? 'user';
      String status = userData['status'] ?? 'approved';

      // บันทึกข้อมูลใน SharedPreferences
      await SharedPreferenceHelper()
          .saveUserDisplayName(userData['name'] ?? '');
      await SharedPreferenceHelper().saveUserName(userData['username'] ?? '');
      await SharedPreferenceHelper().saveUserId(currentUser.uid);
      await SharedPreferenceHelper().saveUserPic(userData['photo'] ?? '');
      await SharedPreferenceHelper().saveUserRole(role);
      await SharedPreferenceHelper().saveUserStatus(status);

      // ตรวจสอบสถานะของผู้รับเลี้ยงแมว
      if (role == 'sitter' && status == 'pending') {
        // ผู้รับเลี้ยงแมวที่ยังไม่ได้รับการอนุมัติ -> ออกจากระบบและไปที่หน้าล็อกอิน
        await FirebaseAuth.instance.signOut();
        setState(() {
          _targetWidget = LogIn();
          _isLoading = false;
        });

        // แสดงข้อความแจ้งเตือน
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บัญชีของคุณยังอยู่ระหว่างรอการอนุมัติ'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        });

        return;
      }

      if (role == 'sitter' && status == 'rejected') {
        // ผู้รับเลี้ยงแมวที่ถูกปฏิเสธ -> ออกจากระบบและไปที่หน้าล็อกอิน
        String rejectionReason = userData['rejectionReason'] ?? 'ไม่ระบุเหตุผล';
        await FirebaseAuth.instance.signOut();
        setState(() {
          _targetWidget = LogIn();
          _isLoading = false;
        });

        // แสดงข้อความแจ้งเตือน
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บัญชีของคุณถูกปฏิเสธ: $rejectionReason'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        });

        return;
      }

      // ผู้ใช้ได้รับการอนุมัติแล้ว -> ไปที่หน้าหลักตามบทบาท
      if (role == 'sitter') {
        setState(() {
          _targetWidget = Nevbarr();
          _isLoading = false;
        });
      } else {
        setState(() {
          _targetWidget = BottomNav();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking user status: $e');
      // กรณีเกิดข้อผิดพลาด -> ไปที่หน้าล็อกอิน
      setState(() {
        _targetWidget = LogIn();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'images/logo.png',
                width: 150,
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              SizedBox(height: 20),
              Text(
                'กำลังตรวจสอบข้อมูล...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _targetWidget!;
  }
}
