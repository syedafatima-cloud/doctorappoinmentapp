// services/admin_notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all admin notifications
  Future<List<Map<String, dynamic>>> getAdminNotifications() async {
    try {
      final querySnapshot = await _firestore
          .collection('admin_notifications')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch admin notifications: $e');
    }
  }

  // Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    try {
      final querySnapshot = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get unread notifications count: $e');
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('admin_notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final batch = _firestore.batch();
      final querySnapshot = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('admin_notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // Create new appointment notification
  Future<void> createAppointmentNotification({
    required String appointmentId,
    required String userName,
    required String doctorName,
    required String date,
    required String time,
    required String appointmentType,
    required String type, // 'new_appointment' or 'appointment_cancelled'
  }) async {
    try {
      String title;
      String message;

      if (type == 'new_appointment') {
        title = 'New Appointment Booked';
        message = '$userName has booked a $appointmentType appointment with $doctorName on $date at $time';
      } else {
        title = 'Appointment Cancelled';
        message = '$userName cancelled their $appointmentType appointment with $doctorName on $date at $time';
      }

      await _firestore.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'appointmentId': appointmentId,
        'userName': userName,
        'doctorName': doctorName,
        'date': date,
        'time': time,
        'appointmentType': appointmentType,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create appointment notification: $e');
    }
  }

  // Create doctor registration notification
  Future<void> createDoctorRegistrationNotification({
    required String doctorName,
    required String specialization,
    required String email,
  }) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': 'doctor_registration',
        'title': 'New Doctor Registration',
        'message': 'Dr. $doctorName ($specialization) has submitted a registration request',
        'doctorName': doctorName,
        'specialization': specialization,
        'email': email,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create doctor registration notification: $e');
    }
  }

  // Create system notification
  Future<void> createSystemNotification({
    required String title,
    required String message,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create base notification data
      final Map<String, dynamic> notificationData = {
        'type': 'system',
        'title': title,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add additional data if provided
      if (additionalData != null) {
        // Iterate through additionalData and add each key-value pair
        additionalData.forEach((key, value) {
          // Only add if the key doesn't already exist to avoid conflicts
          if (!notificationData.containsKey(key)) {
            notificationData[key] = value;
          }
        });
      }

      await _firestore.collection('admin_notifications').add(notificationData);
    } catch (e) {
      throw Exception('Failed to create system notification: $e');
    }
  }

  // Listen to real-time notifications
  Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    return _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Delete old notifications (older than 30 days)
  Future<void> cleanupOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final querySnapshot = await _firestore
          .collection('admin_notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cleanup old notifications: $e');
    }
  }

  // Create user registration notification
  Future<void> createUserRegistrationNotification({
    required String userName,
    required String email,
  }) async {
    try {
      await createSystemNotification(
        title: 'New User Registration',
        message: '$userName has registered with email: $email',
        additionalData: {
          'userName': userName,
          'email': email,
          'registrationType': 'user',
        },
      );
    } catch (e) {
      throw Exception('Failed to create user registration notification: $e');
    }
  }

  // Create payment notification
  Future<void> createPaymentNotification({
    required String appointmentId,
    required String userName,
    required String amount,
    required String status, // 'success' or 'failed'
  }) async {
    try {
      final title = status == 'success' 
          ? 'Payment Received' 
          : 'Payment Failed';
      final message = status == 'success'
          ? '$userName made a payment of \$$amount for appointment #$appointmentId'
          : 'Payment of \$$amount failed for $userName\'s appointment #$appointmentId';

      await createSystemNotification(
        title: title,
        message: message,
        additionalData: {
          'appointmentId': appointmentId,
          'userName': userName,
          'amount': amount,
          'paymentStatus': status,
        },
      );
    } catch (e) {
      throw Exception('Failed to create payment notification: $e');
    }
  }
}