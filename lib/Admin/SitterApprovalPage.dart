import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SitterApprovalPage extends StatefulWidget {
  const SitterApprovalPage({Key? key}) : super(key: key);

  @override
  State<SitterApprovalPage> createState() => _SitterApprovalPageState();
}

class _SitterApprovalPageState extends State<SitterApprovalPage> {
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'sitter')
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> pendingSitters = [];
      for (var doc in snapshot.docs) {
        pendingSitters.add({
          'id': doc.id,
          ...doc.data(),
        });
      }

      setState(() {
        _pendingSitters = pendingSitters;
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
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // อัพเดตรายการในหน้าจอ
      setState(() {
        _pendingSitters.removeWhere((sitter) => sitter['id'] == sitterId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อนุมัติผู้รับเลี้ยงแมวเรียบร้อยแล้ว')),
      );
    } catch (e) {
      print('Error approving sitter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการอนุมัติ: $e')),
      );
    }
  }

  Future<void> _rejectSitter(String sitterId) async {
    try {
      // แสดงไดอะล็อกให้ระบุเหตุผลในการปฏิเสธ
      String? rejectionReason = await showDialog<String>(
        context: context,
        builder: (context) => _buildRejectionDialog(context),
      );

      if (rejectionReason == null) {
        return; // ผู้ใช้ยกเลิกการปฏิเสธ
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(sitterId)
          .update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // อัพเดตรายการในหน้าจอ
      setState(() {
        _pendingSitters.removeWhere((sitter) => sitter['id'] == sitterId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ปฏิเสธผู้รับเลี้ยงแมวเรียบร้อยแล้ว')),
      );
    } catch (e) {
      print('Error rejecting sitter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการปฏิเสธ: $e')),
      );
    }
  }

  Widget _buildRejectionDialog(BuildContext context) {
    TextEditingController reasonController = TextEditingController();

    return AlertDialog(
      title: Text('ระบุเหตุผลในการปฏิเสธ'),
      content: TextField(
        controller: reasonController,
        decoration: InputDecoration(
          hintText: 'เหตุผลในการปฏิเสธ',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            if (reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('กรุณาระบุเหตุผลในการปฏิเสธ')),
              );
              return;
            }
            Navigator.pop(context, reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('ยืนยัน'),
        ),
      ],
    );
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
                      elevation: 3,
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: sitter['photo'] != null &&
                                          sitter['photo'] != 'images/User.png'
                                      ? NetworkImage(sitter['photo'])
                                      : null,
                                  child: sitter['photo'] == 'images/User.png'
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
                                        sitter['name'] ?? 'ไม่ระบุชื่อ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        sitter['email'] ?? 'ไม่ระบุอีเมล',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (sitter['phone'] != null)
                                        Text(
                                          'โทร: ${sitter['phone']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Divider(),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _rejectSitter(sitter['id']),
                                  icon: Icon(Icons.cancel, color: Colors.red),
                                  label: Text('ปฏิเสธ'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                                SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _approveSitter(sitter['id']),
                                  icon: Icon(Icons.check_circle),
                                  label: Text('อนุมัติ'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
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
