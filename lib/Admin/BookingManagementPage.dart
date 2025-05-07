import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:myproject/Admin/BookingDetailPage.dart';

class BookingManagementPage extends StatefulWidget {
  const BookingManagementPage({Key? key}) : super(key: key);

  @override
  _BookingManagementPageState createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends State<BookingManagementPage> {
  bool _isLoading = false;
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // กำหนดค่าเริ่มต้นให้วันที่
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(Duration(days: 30));
  }

  String _formatDates(List<dynamic> dates) {
    if (dates.isEmpty) return 'ไม่ระบุวันที่';

    final formatter = DateFormat('dd/MM/yyyy');
    final List<DateTime> dateTimes = dates
        .map((date) => date is Timestamp ? date.toDate() : DateTime.now())
        .toList();

    dateTimes.sort();

    if (dateTimes.length > 1) {
      return '${formatter.format(dateTimes.first)} - ${formatter.format(dateTimes.last)}';
    }
    return formatter.format(dateTimes.first);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ทั้งหมด';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepOrange,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการการจอง'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'เลือกช่วงเวลา',
          ),
        ],
      ),
      body: Column(
        children: [
          // แสดงช่วงเวลาที่เลือก
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepOrange.shade50,
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  'ช่วงเวลา: ${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
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
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ช่องค้นหา
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อหรือรหัสการจอง',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepOrange, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // แท็บสถานะ
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStatusTab('all', 'ทั้งหมด', Icons.all_inclusive),
                _buildStatusTab('pending', 'รอยืนยัน', Icons.hourglass_empty),
                _buildStatusTab('confirmed', 'ยืนยันแล้ว', Icons.check_circle),
                _buildStatusTab('in_progress', 'กำลังดูแล', Icons.pets),
                _buildStatusTab('completed', 'เสร็จสิ้น', Icons.done_all),
                _buildStatusTab('cancelled', 'ยกเลิก', Icons.cancel),
              ],
            ),
          ),

          // รายการการจอง
          Expanded(
            child: _buildBookingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String status, String label, IconData icon) {
    bool isSelected = _selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepOrange : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildBookingsQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'ไม่พบข้อมูลการจอง',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // กรองข้อมูลตามคำค้นหา
        var filteredDocs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final bookingId = doc.id.toLowerCase();

            // ค้นหาจากรหัสการจอง
            if (bookingId.contains(_searchQuery.toLowerCase())) {
              return true;
            }

            // ค้นหาจากชื่อผู้ใช้หรือพี่เลี้ยง (ถ้ามีข้อมูล)
            if (data.containsKey('userName') &&
                data['userName'] != null &&
                data['userName']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) {
              return true;
            }

            if (data.containsKey('sitterName') &&
                data['sitterName'] != null &&
                data['sitterName']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase())) {
              return true;
            }

            return false;
          }).toList();
        }

        return filteredDocs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'ไม่พบข้อมูลที่ตรงกับการค้นหา',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: filteredDocs.length,
                padding: EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final bookingData = doc.data() as Map<String, dynamic>;
                  final status = bookingData['status'] ?? 'pending';

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingDetailPage(
                              bookingId: doc.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status)
                                        .withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getStatusIcon(status),
                                    color: _getStatusColor(status),
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'รหัส: ${doc.id.substring(0, 8)}...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status)
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(status),
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          if (bookingData['totalPrice'] != null)
                                            Text(
                                              '฿${bookingData['totalPrice']}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (bookingData['createdAt'] != null)
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(
                                            (bookingData['createdAt']
                                                    as Timestamp)
                                                .toDate()),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    SizedBox(height: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Divider(height: 24),
                            _buildBookingDetailRow(
                              'วันที่ฝากเลี้ยง:',
                              bookingData['dates'] != null
                                  ? _formatDates(bookingData['dates'])
                                  : 'ไม่ระบุ',
                              Icons.calendar_month,
                            ),
                            SizedBox(height: 8),
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(bookingData['userId'])
                                  .get(),
                              builder: (context, userSnapshot) {
                                String userName = 'กำลังโหลด...';
                                if (userSnapshot.hasData &&
                                    userSnapshot.data!.exists) {
                                  final userData = userSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  userName = userData['name'] ?? 'ไม่ระบุชื่อ';
                                }
                                return _buildBookingDetailRow(
                                  'ผู้จอง:',
                                  userName,
                                  Icons.person,
                                );
                              },
                            ),
                            SizedBox(height: 8),
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(bookingData['sitterId'])
                                  .get(),
                              builder: (context, sitterSnapshot) {
                                String sitterName = 'กำลังโหลด...';
                                if (sitterSnapshot.hasData &&
                                    sitterSnapshot.data!.exists) {
                                  final sitterData = sitterSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  sitterName =
                                      sitterData['name'] ?? 'ไม่ระบุชื่อ';
                                }
                                return _buildBookingDetailRow(
                                  'พี่เลี้ยง:',
                                  sitterName,
                                  Icons.pets,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
      },
    );
  }

  Stream<QuerySnapshot> _buildBookingsQuery() {
    Query query = FirebaseFirestore.instance.collection('bookings');

    // กรองตามสถานะ
    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    // กรองตามช่วงเวลา
    if (_startDate != null && _endDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
        isLessThanOrEqualTo:
            Timestamp.fromDate(_endDate!.add(Duration(days: 1))),
      );
    }

    // เรียงลำดับตามวันที่สร้าง (ล่าสุดก่อน)
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildBookingDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.deepOrange),
        SizedBox(width: 4),
        Text(
          '$label ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
