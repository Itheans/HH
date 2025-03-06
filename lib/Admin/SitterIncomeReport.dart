import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SitterIncomeReport extends StatefulWidget {
  const SitterIncomeReport({Key? key}) : super(key: key);

  @override
  _SitterIncomeReportState createState() => _SitterIncomeReportState();
}

class _SitterIncomeReportState extends State<SitterIncomeReport> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sitterIncomeList = [];
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSitterIncomeData();
  }

  Future<void> _loadSitterIncomeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. ดึงข้อมูลการจองในช่วงเวลาที่กำหนด
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status',
              whereIn: ['confirmed', 'in_progress', 'completed']).get();

      // 2. จัดกลุ่มข้อมูลตามพี่เลี้ยง
      Map<String, Map<String, dynamic>> sitterIncomeMap = {};

      for (var doc in bookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;

        // ข้ามรายการที่ไม่ได้อยู่ในช่วงเวลาที่กำหนด
        if (bookingData['createdAt'] != null) {
          DateTime bookingDate =
              (bookingData['createdAt'] as Timestamp).toDate();
          if (bookingDate.isBefore(_startDate) ||
              bookingDate.isAfter(_endDate)) {
            continue;
          }
        }

        String sitterId = bookingData['sitterId'];
        double totalPrice = (bookingData['totalPrice'] is int)
            ? (bookingData['totalPrice'] as int).toDouble()
            : (bookingData['totalPrice'] ?? 0);

        if (!sitterIncomeMap.containsKey(sitterId)) {
          sitterIncomeMap[sitterId] = {
            'sitterId': sitterId,
            'totalIncome': 0.0,
            'bookingCount': 0,
            'sitterName': 'รอโหลด...',
            'photo': null,
          };
        }

        sitterIncomeMap[sitterId]!['totalIncome'] += totalPrice;
        sitterIncomeMap[sitterId]!['bookingCount'] += 1;
      }

      // 3. ดึงข้อมูลชื่อพี่เลี้ยง
      for (String sitterId in sitterIncomeMap.keys) {
        DocumentSnapshot sitterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sitterId)
            .get();

        if (sitterDoc.exists) {
          Map<String, dynamic> sitterData =
              sitterDoc.data() as Map<String, dynamic>;
          sitterIncomeMap[sitterId]!['sitterName'] =
              sitterData['name'] ?? 'ไม่ระบุชื่อ';
          sitterIncomeMap[sitterId]!['photo'] = sitterData['photo'];
        }
      }

      // 4. แปลงเป็น List และเรียงลำดับตามรายได้
      _sitterIncomeList = sitterIncomeMap.values.toList();
      _sitterIncomeList.sort((a, b) =>
          (b['totalIncome'] as double).compareTo(a['totalIncome'] as double));

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading sitter income data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSitterIncomeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานรายได้พี่เลี้ยง'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'เลือกช่วงเวลา',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sitterIncomeList.isEmpty
              ? const Center(child: Text('ไม่พบข้อมูลรายได้'))
              : Column(
                  children: [
                    // แสดงช่วงเวลาที่เลือก
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.orange.shade50,
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          ElevatedButton.icon(
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('เปลี่ยน'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // สรุปรายได้รวม
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'รายได้รวมทั้งหมด',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '฿${_calculateTotalIncome().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'จำนวนการจอง',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_calculateTotalBookings()} รายการ',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // รายการรายได้ของพี่เลี้ยงแต่ละคน
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sitterIncomeList.length,
                        itemBuilder: (context, index) {
                          final sitterData = _sitterIncomeList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: sitterData['photo'] != null
                                    ? NetworkImage(sitterData['photo'])
                                    : null,
                                child: sitterData['photo'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                sitterData['sitterName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${sitterData['bookingCount']} รายการ',
                              ),
                              trailing: Text(
                                '฿${(sitterData['totalIncome'] as double).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  double _calculateTotalIncome() {
    return _sitterIncomeList.fold(
        0, (sum, item) => sum + (item['totalIncome'] as double));
  }

  int _calculateTotalBookings() {
    return _sitterIncomeList.fold(
        0, (sum, item) => sum + (item['bookingCount'] as int));
  }
}
