import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({Key? key}) : super(key: key);

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingSitters = [];

  @override
  void initState() {
    super.initState();
    _loadPendingSitters();
  }

  Future<void> _loadPendingSitters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงรายการผู้รับเลี้ยงแมวที่รอการอนุมัติ
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('approved', isEqualTo: false)
          .orderBy('registrationDate', descending: true)
          .get();

      final sitters = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'ไม่ระบุชื่อ',
          'email': data['email'] ?? 'ไม่ระบุอีเมล',
          'photo': data['photo'] ?? '',
          'registrationDate': data['registrationDate'] != null
              ? (data['registrationDate'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();

      setState(() {
        _pendingSitters = sitters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending sitters: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveSitter(String sitterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(sitterId)
          .update({'approved': true});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อนุมัติผู้รับเลี้ยงแมวเรียบร้อยแล้ว')),
      );

      // รีโหลดรายการ
      _loadPendingSitters();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _rejectSitter(String sitterId) async {
    // แสดงไดอะล็อกยืนยันการปฏิเสธ
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการปฏิเสธ'),
        content:
            Text('คุณต้องการปฏิเสธการสมัครของผู้รับเลี้ยงแมวรายนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ปฏิเสธ'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ให้คำนึงถึงว่าคุณอาจต้องการลบข้อมูลหรือเพียงทำเครื่องหมายว่าถูกปฏิเสธ
        // ในที่นี้เราจะเพียงแค่ลบข้อมูลผู้ใช้
        await FirebaseFirestore.instance
            .collection('users')
            .doc(sitterId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธผู้รับเลี้ยงแมวเรียบร้อยแล้ว')),
        );

        // รีโหลดรายการ
        _loadPendingSitters();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('อนุมัติผู้รับเลี้ยงแมว'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPendingSitters,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingSitters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'ไม่มีผู้รับเลี้ยงแมวที่รอการอนุมัติ',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingSitters.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final sitter = _pendingSitters[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: sitter['photo'].isNotEmpty
                                      ? NetworkImage(sitter['photo'])
                                      : null,
                                  child: sitter['photo'].isEmpty
                                      ? Icon(Icons.person)
                                      : null,
                                  radius: 30,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sitter['name'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        sitter['email'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'สมัครเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(sitter['registrationDate'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _rejectSitter(sitter['id']),
                                  child: Text('ปฏิเสธ'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _approveSitter(sitter['id']),
                                  child: Text('อนุมัติ'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
