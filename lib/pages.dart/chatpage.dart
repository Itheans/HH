import 'dart:math';
import 'package:myproject/pages.dart/todayscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myproject/pages.dart/chat.dart';
import 'package:myproject/services/database.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:random_string/random_string.dart';

class ChatPage extends StatefulWidget {
  String name, profileurl, username, role;
  ChatPage(
      {required this.name,
      required this.profileurl,
      required this.username,
      required this.role});

  @override
  State<ChatPage> createState() => _ChatpageState();
}

class _ChatpageState extends State<ChatPage> {
  TextEditingController messageController = new TextEditingController();
  String? myUserName,
      myProfilePic,
      myName,
      myEmail,
      messageId,
      chatRoomId,
      myRole;
  Stream? messageStream;
  bool _isSending = false;

  getthesharedpref() async {
    myUserName = await SharedPreferenceHelper().getUserName();
    myProfilePic = await SharedPreferenceHelper().getUserPic();
    myName = await SharedPreferenceHelper().getDisplayName();
    myEmail = await SharedPreferenceHelper().getUserEmail();
    myRole = await SharedPreferenceHelper().getUserRole();

    chatRoomId = getChatRoomIdbyUsername(widget.username, myUserName!);
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    await getAndSetMessages();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ontheload();
  }

  getChatRoomIdbyUsername(String a, String b) {
    if (a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)) {
      return "$b\_$a";
    } else {
      return "$a\_$b";
    }
  }

  Widget chatMessageTile(String message, bool sendByMe, String timestamp) {
    return Align(
      alignment: sendByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(
          crossAxisAlignment:
              sendByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: sendByMe ? Colors.orange.shade500 : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft:
                      sendByMe ? Radius.circular(20) : Radius.circular(0),
                  bottomRight:
                      sendByMe ? Radius.circular(0) : Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: sendByMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                timestamp,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget chatMessage() {
    return StreamBuilder(
        stream: messageStream,
        builder: (context, AsyncSnapshot snapshot) {
          return snapshot.hasData
              ? ListView.builder(
                  padding: EdgeInsets.only(bottom: 90, top: 10),
                  itemCount: snapshot.data.docs.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    DocumentSnapshot ds = snapshot.data.docs[index];
                    return chatMessageTile(
                      ds["message"],
                      myUserName == ds["sendBy"],
                      ds["ts"] ?? "",
                    );
                  })
              : Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                );
        });
  }

  addMessage(bool sendClicked) async {
    if (messageController.text != "") {
      setState(() {
        _isSending = true;
      });

      String message = messageController.text;
      messageController.text = "";

      DateTime now = DateTime.now();
      String formattedDate = DateFormat('h:mm a').format(now);
      Map<String, dynamic> messageInfoMap = {
        "message": message,
        "sendBy": myUserName,
        "ts": formattedDate,
        "time": FieldValue.serverTimestamp(),
        "imgUrl": myProfilePic,
      };
      messageId ??= randomAlphaNumeric(10);

      try {
        await DatabaseMethods()
            .addMessage(chatRoomId!, messageId!, messageInfoMap);

        Map<String, dynamic> lastMessageInfoMap = {
          "lastMessage": message,
          "lastMessageSendTs": formattedDate,
          "time": FieldValue.serverTimestamp(),
          "lastMessageSendBy": myUserName,
        };

        await DatabaseMethods()
            .updateLastMessageSend(chatRoomId!, lastMessageInfoMap);

        if (sendClicked) {
          messageId = null;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งข้อความ: $e')),
        );
      } finally {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  getAndSetMessages() async {
    messageStream = await DatabaseMethods().getChatRoomMessages(chatRoomId);
    setState(() {});
  }

  void _navigateToTodayscreen(BuildContext context) async {
    // ส่งข้อมูลคู่สนทนาไปยังหน้า Todayscreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Todayscreen(
          chatRoomId: chatRoomId,
          receiverName: widget.name,
          senderUsername: myUserName,
        ),
      ),
    );

    if (result != null) {
      // กรณีเช็คอิน
      if (result['checkedIn'] == true) {
        String checkInTime = result['checkInTime'] ?? DateTime.now().toString();
        String additionalNote = result['note'] ?? '';

        // สร้างข้อความ
        String message = "✅ ฉันได้มาดูแมวแล้วเมื่อ $checkInTime";
        if (additionalNote.isNotEmpty) {
          message += "\n📝 หมายเหตุ: $additionalNote";
        }

        // บันทึกข้อความลงในกล่องข้อความ
        messageController.text = message;

        // ส่งข้อความ
        addMessage(true);
      }

      // กรณีเช็คเอาท์
      if (result['checkedOut'] == true) {
        String checkOutTime =
            result['checkOutTime'] ?? DateTime.now().toString();

        // สร้างข้อความ
        String message = "🚶‍♂️ ฉันได้เสร็จสิ้นการดูแลแมวเมื่อ $checkOutTime";

        // บันทึกข้อความลงในกล่องข้อความ
        messageController.text = message;

        // ส่งข้อความ
        addMessage(true);
      }
    }
  }

  // ฟังก์ชันแสดงไดอะล็อกยืนยันการบันทึกการมาดูแมว
  void _showCheckInDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('บันทึกการมาดูแมว'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณต้องการบันทึกการมาดูแมวและแจ้ง ${widget.name} หรือไม่?'),
              SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(
                  hintText: 'ระบุข้อความเพิ่มเติม (ถ้ามี)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                maxLines: 2,
                controller: TextEditingController(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.check),
              label: Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                // รับข้อความเพิ่มเติม (ถ้ามี)
                String additionalMessage = '';
                if (context.findRenderObject() != null) {
                  final dialogContext = context;
                  final textField =
                      dialogContext.findAncestorWidgetOfExactType<TextField>();
                  if (textField != null && textField.controller != null) {
                    additionalMessage = textField.controller!.text;
                  }
                }

                Navigator.pop(context);
                _sendCheckInMessage(additionalMessage);
              },
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันส่งข้อความบันทึกการมาดูแมว
  void _sendCheckInMessage(String additionalMessage) {
    // สร้างข้อความแจ้งเตือน
    final now = DateTime.now();
    final formattedTime = DateFormat('dd/MM/yyyy HH:mm').format(now);

    String message = "✅ ฉันได้มาดูแมวแล้วเมื่อ $formattedTime";
    if (additionalMessage.isNotEmpty) {
      message += "\n📝 หมายเหตุ: $additionalMessage";
    }

    // บันทึกข้อความลงในกล่องข้อความ
    messageController.text = message;

    // ส่งข้อความ
    addMessage(true);

    // แสดง SnackBar แจ้งผู้ใช้
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('บันทึกการมาดูแมวเรียบร้อยแล้ว'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade500,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Container(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 2),
                widget.profileurl.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(widget.profileurl),
                        maxRadius: 20,
                      )
                    : CircleAvatar(
                        child: Icon(Icons.person),
                        backgroundColor: Colors.grey[300],
                        maxRadius: 20,
                      ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.role == 'sitter' ? 'ผู้รับเลี้ยง' : 'ผู้ใช้งาน',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // เพิ่มปุ่มไปที่หน้า Todayscreen
                IconButton(
                  icon: Icon(
                    Icons.access_time,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _navigateToTodayscreen(context);
                  },
                  tooltip: 'บันทึกการมาดูแมว',
                ),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.role == 'sitter'
                      ? Icon(Icons.pets, color: Colors.white, size: 16)
                      : Icon(Icons.person, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
      // ส่วนที่เหลือของ build method ยังคงเหมือนเดิม
      // ส่วนที่เหลือของ build method
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: chatMessage(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "พิมพ์ข้อความ...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: _isSending ? null : () => addMessage(true),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
