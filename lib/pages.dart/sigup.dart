import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/login.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:random_string/random_string.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = '', password = '', name = '';
  String role = 'user'; // บทบาทเริ่มต้น
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();

  // ฟังก์ชันลงทะเบียน
  registration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // สร้างผู้ใช้ใน Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: emailController.text.trim(),
                password: passwordController.text.trim());

        String uid = userCredential.user!.uid; // ID ของผู้ใช้

        // สร้างข้อมูลผู้ใช้
        Map<String, dynamic> userInfoMap = {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'username': nameController.text.trim(),
          'photo': 'images/User.png',
          'id': uid,
          'role': role,
          'wallet': "0",
          'SearchKey': nameController.text.substring(0, 1).toUpperCase(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userInfoMap);

        // เก็บข้อมูลใน SharedPreferences
        await SharedPreferenceHelper().saveUserDisplayName(nameController.text);
        await SharedPreferenceHelper().saveUserPic('images/User.png');
        await SharedPreferenceHelper().saveUserRole(role);

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ'),
            backgroundColor: Colors.green,
          ),
        );

        // นำไปยังหน้า Login
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LogIn()));
      } catch (e) {
        // จัดการข้อผิดพลาด
        String errorMessage = 'เกิดข้อผิดพลาดในการสมัครสมาชิก';

        if (e is FirebaseAuthException) {
          if (e.code == 'email-already-in-use') {
            errorMessage = 'อีเมลนี้ถูกใช้งานแล้ว';
          } else if (e.code == 'weak-password') {
            errorMessage = 'รหัสผ่านไม่ปลอดภัย';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.orange.shade700,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนหัว
              Center(
                child: Image.asset(
                  'images/logo.png',
                  height: 120,
                ),
              ),
              SizedBox(height: 30),
              Text(
                'สมัครสมาชิก',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
              Text(
                'สร้างบัญชีผู้ใช้เพื่อใช้บริการฝากเลี้ยงแมว',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 30),

              // แบบฟอร์มสมัครสมาชิก
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ชื่อ
                    TextFormField(
                      controller: nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'ชื่อผู้ใช้',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon: Icon(Icons.person_outline,
                            color: Colors.orange.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // อีเมล
                    TextFormField(
                      controller: emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกอีเมล';
                        } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'อีเมล',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon: Icon(Icons.email_outlined,
                            color: Colors.orange.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // รหัสผ่าน
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน';
                        } else if (value.length < 6) {
                          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        floatingLabelStyle:
                            TextStyle(color: Colors.orange.shade700),
                        prefixIcon: Icon(Icons.lock_outline,
                            color: Colors.orange.shade400),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                              color: Colors.orange.shade400, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // เลือกบทบาท
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_pin, color: Colors.orange.shade400),
                          SizedBox(width: 10),
                          Text(
                            'บทบาท:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: role,
                                isExpanded: true,
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.orange.shade700),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                items: <String>['user', 'sitter']
                                    .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value == 'user'
                                          ? 'ผู้ใช้ทั่วไป'
                                          : 'ผู้รับเลี้ยงแมว',
                                      style: TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    role = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),

                    // ปุ่มสมัครสมาชิก
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : registration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                          shadowColor: Colors.orange.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : Text(
                                'สมัครสมาชิก',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 30),

                    // ลิงก์ไปหน้า Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'มีบัญชีอยู่แล้ว? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LogIn()));
                          },
                          child: Text(
                            'เข้าสู่ระบบ',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
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
}
