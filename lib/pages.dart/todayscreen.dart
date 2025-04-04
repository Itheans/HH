import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:image_picker/image_picker.dart'; // เพิ่มเพื่อใช้ถ่ายรูป
import 'dart:io';

class Todayscreen extends StatefulWidget {
  // เพิ่มพารามิเตอร์เพื่อรับข้อมูลจากหน้า ChatPage
  final String? chatRoomId;
  final String? receiverName;
  final String? senderUsername;

  const Todayscreen({
    Key? key,
    this.chatRoomId,
    this.receiverName,
    this.senderUsername,
  }) : super(key: key);

  @override
  State<Todayscreen> createState() => _TodayscreenState();
}

class _TodayscreenState extends State<Todayscreen> {
  double screenHeight = 0;
  double screenWidth = 0;
  Color primary = const Color(0xffeef444c);

  // เพิ่มตัวแปรสำหรับการถ่ายรูป (จากการแก้ไขครั้งก่อน)
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  String? _imagePath;

  // เพิ่มตัวแปรสำหรับเวลาเข้างาน
  TimeOfDay _checkInTime = TimeOfDay(hour: 9, minute: 30);
  TimeOfDay? _checkOutTime;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;

// ฟังก์ชันสำหรับเลือกเวลาเข้างาน
  Future<void> _selectCheckInTime(BuildContext context) async {
    if (_hasCheckedIn) return; // ถ้าเช็คอินแล้วไม่ให้เปลี่ยนเวลา

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _checkInTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            buttonTheme: ButtonThemeData(
              colorScheme: ColorScheme.light(
                primary: primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && pickedTime != _checkInTime) {
      setState(() {
        _checkInTime = pickedTime;
      });
    }
  }

  // ฟังก์ชันสำหรับเช็คอิน
  // ฟังก์ชันสำหรับเช็คอิน
  void _checkIn() {
    if (widget.chatRoomId != null && widget.receiverName != null) {
      // แสดงไดอะล็อกยืนยันการเช็คอินและส่งข้อความ
      _showCheckInConfirmDialog();
    } else {
      // ถ้าไม่ได้มาจากหน้าแชท ให้เช็คอินปกติ
      setState(() {
        _hasCheckedIn = true;
      });
    }
  }

// เพิ่มฟังก์ชันแสดงไดอะล็อกยืนยัน
  // ฟังก์ชันแสดงไดอะล็อกยืนยันการเช็คอิน
  void _showCheckInConfirmDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('ยืนยันการบันทึกเวลา'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'คุณต้องการบันทึกเวลาและแจ้ง ${widget.receiverName} หรือไม่?'),
              SizedBox(height: 15),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'เพิ่มข้อความ (ถ้ามี)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                // บันทึกการเช็คอิน
                setState(() {
                  _hasCheckedIn = true;
                });

                // ปิดไดอะล็อก
                Navigator.pop(context);

                // ส่งข้อมูลกลับไปที่หน้าแชท
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, {
                    'checkedIn': true,
                    'checkInTime': _checkInTime.format(context),
                    'note': noteController.text,
                    'imagePath': _imagePath, // ส่งพาธของรูปภาพกลับไป
                    'capturedImage': _capturedImage, // ส่งไฟล์รูปภาพกลับไป
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('บันทึกและแจ้งเตือน'),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันสำหรับเช็คเอาท์
  void _checkOut() {
    final TimeOfDay currentTime = TimeOfDay.now();

    setState(() {
      _checkOutTime = currentTime;
      _hasCheckedOut = true;
    });

    // คุณสามารถเพิ่มโค้ดบันทึกเวลาเช็คเอาท์ลงในฐานข้อมูลหรือ API ตรงนี้
  }

  // ฟังก์ชันสำหรับการถ่ายรูป
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
          _imagePath = photo.path;
        });
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการถ่ายรูป: $e");
    }
  }

  DateTime _currentDateTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // อัพเดตเวลาทุกวินาที
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentDateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(top: 32),
              child: Text(
                "Welcome",
                style: TextStyle(
                  color: Colors.black54,
                  fontFamily: "NexaRegular",
                  fontSize: screenWidth / 20,
                ),
              ),
            ),
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                "Employee",
                style: TextStyle(
                  fontFamily: "NexaRegular",
                  fontSize: screenWidth / 18,
                ),
              ),
            ),

            // เพิ่มส่วนแสดงรูปภาพที่ถ่าย
            Container(
              margin: const EdgeInsets.only(top: 20),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: _capturedImage != null
                  ? GestureDetector(
                      onTap: _showFullImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          _capturedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                    ),
            ),

            // เพิ่มปุ่มถ่ายรูป
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _takePicture,
                icon: Icon(Icons.camera_alt),
                label: Text("ถ่ายรูป"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(top: 32),
              child: Text(
                "Today's Status",
                style: TextStyle(
                  fontFamily: "NexaRegular",
                  fontSize: screenWidth / 18,
                ),
              ),
            ),

            // ส่วนที่เหลือยังคงเหมือนเดิม
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 32),
              height: 150,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectCheckInTime(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Check In",
                            style: TextStyle(
                              fontFamily: "NexaRegular",
                              fontSize: screenWidth / 20,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_checkInTime.format(context)}",
                            style: TextStyle(
                              fontFamily: "NexaBold",
                              fontSize: screenWidth / 18,
                              color:
                                  _hasCheckedIn ? Colors.green : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _hasCheckedIn ? null : _checkIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: Text(
                              _hasCheckedIn ? "เช็คอินแล้ว" : "เช็คอิน",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Check Out",
                          style: TextStyle(
                            fontFamily: "NexaRegular",
                            fontSize: screenWidth / 20,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _checkOutTime == null
                              ? "--:--"
                              : "${_checkOutTime!.format(context)}",
                          style: TextStyle(
                            fontFamily: "NexaBold",
                            fontSize: screenWidth / 18,
                            color: _hasCheckedOut ? Colors.red : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: (!_hasCheckedIn || _hasCheckedOut)
                              ? null
                              : _checkOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            disabledBackgroundColor: Colors.grey,
                          ),
                          child: Text(
                            _hasCheckedOut ? "เช็คเอาท์แล้ว" : "เช็คเอาท์",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  text: "${_currentDateTime.day}",
                  style: TextStyle(
                    color: primary,
                    fontFamily: "NexaBold",
                    fontSize: screenWidth / 18,
                  ),
                  children: [
                    TextSpan(
                      text: DateFormat(' MMM yyyy').format(_currentDateTime),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth / 20,
                        fontFamily: "NexaBold",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('hh:mm:ss a').format(_currentDateTime),
                style: TextStyle(
                  fontFamily: "NexaRegular",
                  fontSize: screenWidth / 20,
                  color: Colors.black54,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 24),
              child: Builder(builder: (context) {
                final GlobalKey<SlideActionState> key = GlobalKey();

                return SlideAction(
                  text: "Slide to Check Out",
                  textStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: screenWidth / 20,
                    fontFamily: "NexaRegular",
                  ),
                  outerColor: Colors.white,
                  innerColor: primary,
                  key: key,
                  onSubmit: () {
                    if (_hasCheckedIn && !_hasCheckedOut) {
                      _checkOut();

                      // ถ้ามีข้อมูลแชทให้ส่งข้อมูลกลับ
                      if (widget.chatRoomId != null &&
                          Navigator.canPop(context)) {
                        Future.delayed(Duration(seconds: 1), () {
                          Navigator.pop(context, {
                            'checkedOut': true,
                            'checkOutTime': _checkOutTime?.format(context) ??
                                TimeOfDay.now().format(context),
                            'imagePath': _imagePath, // ส่งพาธของรูปภาพกลับไป
                            'capturedImage':
                                _capturedImage, // ส่งไฟล์รูปภาพกลับไป
                          });
                        });
                      }
                    }

                    // รีเซ็ต slider
                    Future.delayed(Duration(seconds: 1), () {
                      key.currentState!.reset();
                    });
                  },
                  enabled: _hasCheckedIn && !_hasCheckedOut,
                );
              }),
            )
          ],
        ),
      ),
    );
  }

  void _showFullImage() {
    if (_capturedImage == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: double.infinity,
            height: screenHeight * 0.6,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(_capturedImage!),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
