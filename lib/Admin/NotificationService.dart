import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ส่งการแจ้งเตือนเมื่อสถานะการจองเปลี่ยนแปลง
  Future<void> sendBookingStatusNotification({
    required String userId,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    try {
      // สร้างข้อมูลการแจ้งเตือน
      Map<String, dynamic> notificationData = {
        'userId': userId,
        'bookingId': bookingId,
        'status': status,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // บันทึกลงใน Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);

      print(
          'Notification sent successfully to user $userId about booking $bookingId');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
