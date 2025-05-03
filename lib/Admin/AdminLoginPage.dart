import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Admin/AdminPage.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({Key? key}) : super(key: key);

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _emailController =
      TextEditingController(text: "admin@admin.com"); // กำหนดค่าเริ่มต้น
  final TextEditingController _passwordController =
      TextEditingController(text: "admin123456"); // กำหนดค่าเริ่มต้น
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // รหัสแอดมินที่กำหนดไว้ล่วงหน้า
  final String _adminEmail = "admin@admin.com";
  final String _adminPassword = "admin123456";

  @override
  void initState() {
    super.initState();
    // ตรวจสอบและสร้างแอดมินเมื่อเปิดหน้าจอ
    _checkAndCreateAdmin();
  }

  // ตรวจสอบและสร้างแอดมินอัตโนมัติเมื่อเปิดหน้าจอ (ถ้ายังไม่มีในระบบ)
  Future<void> _checkAndCreateAdmin() async {
    try {
      // ตรวจสอบว่ามีผู้ใช้แอดมินอยู่แล้วหรือไม่
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminQuery.docs.isEmpty) {
        // ยังไม่มีแอดมิน ให้สร้างใหม่
        await _createAdmin();
      }
    } catch (e) {
      print("Error checking admin: $e");
    }
  }

  Future<void> _loginAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ตรวจสอบว่าเป็นรหัสแอดมินที่กำหนดไว้หรือไม่
      if (_emailController.text.trim() == _adminEmail &&
          _passwordController.text.trim() == _adminPassword) {
        // สร้างแอดมินหากยังไม่มี
        await _createAdmin();

        // พยายามล็อกอิน
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: _adminEmail, password: _adminPassword);
        } catch (e) {
          print("Error signing in: $e");
          // กรณีที่ล็อกอินไม่ได้แต่เป็นรหัสที่ถูกต้อง ให้เข้าสู่หน้าแอดมินเลย
        }

        // เข้าสู่ระบบสำเร็จ - นำทางไปที่หน้า Admin Panel
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdminPanel()),
        );
      } else {
        // รหัสไม่ถูกต้อง
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อีเมลหรือรหัสผ่านของแอดมินไม่ถูกต้อง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ฟังก์ชันสำหรับสร้างผู้ดูแลระบบ
  Future<void> _createAdmin() async {
    try {
      // ตรวจสอบว่ามี user ในระบบ Authentication แล้วหรือไม่
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _adminEmail, password: _adminPassword);
        print("Created admin in Authentication");
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
          // ถ้ามีอีเมลนี้อยู่แล้ว ไม่ต้องทำอะไร
          print("Admin already exists in Authentication");
        } else {
          // หากเกิดข้อผิดพลาดอื่นๆ ให้ throw exception
          rethrow;
        }
      }

      // ตรวจสอบว่ามีข้อมูลใน Firestore แล้วหรือไม่
      String uid = "";

      // ดึง UID ของแอดมิน
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: _adminEmail, password: _adminPassword);
        uid = userCredential.user!.uid;
      } catch (e) {
        print("Error getting admin UID: $e");
        // ในกรณีที่ไม่สามารถล็อกอินได้ แต่อาจมีแอดมินในระบบแล้ว
        // ทำการดึงข้อมูลแอดมินจาก Firestore (ถ้ามี)
        final adminQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _adminEmail)
            .where('role', isEqualTo: 'admin')
            .get();

        if (adminQuery.docs.isNotEmpty) {
          print("Admin already exists in Firestore, no need to create");
          return; // มีแอดมินแล้ว ไม่ต้องสร้างใหม่
        }
      }

      if (uid.isNotEmpty) {
        // ตรวจสอบว่ามีข้อมูลในคอลเลกชัน users แล้วหรือไม่
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (!userDoc.exists) {
          // สร้างข้อมูลผู้ใช้
          Map<String, dynamic> userInfoMap = {
            'name': 'Admin',
            'email': _adminEmail,
            'username': 'admin',
            'photo': 'images/User.png',
            'id': uid,
            'role': 'admin',
            'status': 'approved',
            'SearchKey': 'A',
          };

          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set(userInfoMap);

          print("Created admin in Firestore");
        } else {
          print("Admin already exists in Firestore");
        }
      }
    } catch (e) {
      print("Error creating admin: $e");
      throw Exception("ไม่สามารถสร้างแอดมินได้: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('เข้าสู่ระบบผู้ดูแล'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                Icon(
                  Icons.admin_panel_settings,
                  size: 100,
                  color: Colors.orange,
                ),
                SizedBox(height: 20),
                Text(
                  'เข้าสู่ระบบสำหรับผู้ดูแลระบบ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'admin@admin.com / admin123456',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'อีเมล',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกอีเมล';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่าน',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกรหัสผ่าน';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            'เข้าสู่ระบบ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'กลับไปหน้าเข้าสู่ระบบปกติ',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(height: 30),
                Divider(),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'หมายเหตุสำหรับผู้ดูแลระบบ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'หน้านี้สำหรับผู้ดูแลระบบเท่านั้น หากคุณเป็นผู้ใช้งานทั่วไป โปรดกลับไปยังหน้าเข้าสู่ระบบปกติ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // ปุ่มสร้างแอดมินแบบบังคับ
                ElevatedButton(
                  onPressed: () async {
                    try {
                      setState(() {
                        _isLoading = true;
                      });
                      await _createAdmin();
                      setState(() {
                        _isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('สร้างแอดมินสำเร็จ'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      setState(() {
                        _isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เกิดข้อผิดพลาด: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: Text('สร้างแอดมินใหม่ (admin@admin.com)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
