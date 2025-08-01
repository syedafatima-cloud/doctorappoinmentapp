// appointment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Initialize notifications
  Future<void> initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings);
  }

  // Generate 15-minute time slots between start and end time
  List<String> generateTimeSlots(String startTime, String endTime) {
    final format = DateFormat("HH:mm");
    final start = format.parse(startTime);
    final end = format.parse(endTime);
    
    List<String> slots = [];
    DateTime current = start;
    
    while (current.isBefore(end)) {
      slots.add(format.format(current));
      current = current.add(const Duration(minutes: 15));
    }
    
    return slots;
  }

  // Fetch doctor's available slots for a specific date
  Future<List<String>> fetchAvailableSlots(String doctorId, String selectedDate) async {
    try {
      // Get doctor's document
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();

      if (!doctorDoc.exists) {
        throw Exception('Doctor not found');
      }

      // Get all available slots for the date
      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final availableSlots = doctorData['availableSlots'] as Map<String, dynamic>?;
      
      if (availableSlots == null || availableSlots[selectedDate] == null) {
        return []; // No slots available for this date
      }

      final allSlots = List<String>.from(availableSlots[selectedDate]);

      // Get already booked appointments for this doctor and date
      final bookedAppointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: selectedDate)
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      // Extract booked time slots
      final bookedSlots = bookedAppointments.docs
          .map((doc) => doc.data()['time'] as String)
          .toList();

      // Return available slots (excluding booked ones)
      final availableTimeSlots = allSlots
          .where((slot) => !bookedSlots.contains(slot))
          .toList();

      // Sort slots chronologically
      availableTimeSlots.sort((a, b) {
        final timeA = DateFormat("HH:mm").parse(a);
        final timeB = DateFormat("HH:mm").parse(b);
        return timeA.compareTo(timeB);
      });

      return availableTimeSlots;
    } catch (e) {
      print('Error fetching available slots: $e');
      rethrow;
    }
  }

  // Check if a specific slot is available
  Future<bool> isSlotAvailable(String doctorId, String date, String time) async {
    try {
      final availableSlots = await fetchAvailableSlots(doctorId, date);
      return availableSlots.contains(time);
    } catch (e) {
      print('Error checking slot availability: $e');
      return false;
    }
  }

  // Book an appointment
  Future<String> bookAppointment({
    required String doctorId,
    required String userName,
    required String userPhone,
    required String date,
    required String time,
    String? userEmail,
    String? symptoms,
    String appointmentType = 'chat', // 'chat' or 'call'
  }) async {
    try {
      // Double-check slot availability
      final isAvailable = await isSlotAvailable(doctorId, date, time);
      if (!isAvailable) {
        throw Exception('Selected time slot is no longer available');
      }

      // Get doctor information
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();
      
      final doctorName = doctorDoc.data()?['name'] ?? 'Unknown Doctor';

      // Create appointment document
      final appointmentRef = await _firestore
          .collection('appointments')
          .add({
        'doctorId': doctorId,
        'doctorName': doctorName,
        'userName': userName,
        'userPhone': userPhone,
        'userEmail': userEmail,
        'date': date,
        'time': time,
        'appointmentType': appointmentType,
        'symptoms': symptoms,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to admin
      await _sendAdminNotification(
        appointmentId: appointmentRef.id,
        doctorName: doctorName,
        userName: userName,
        date: date,
        time: time,
        appointmentType: appointmentType,
      );

      // Update appointment statistics
      await _updateAppointmentStats(doctorId, date);

      return appointmentRef.id;
    } catch (e) {
      print('Error booking appointment: $e');
      rethrow;
    }
  }

  // Send notification to admin
  Future<void> _sendAdminNotification({
    required String appointmentId,
    required String doctorName,
    required String userName,
    required String date,
    required String time,
    required String appointmentType,
  }) async {
    try {
      // Save notification to Firestore for admin dashboard
      await _firestore.collection('admin_notifications').add({
        'type': 'new_appointment',
        'title': 'New Appointment Booked',
        'message': '$userName has booked a $appointmentType appointment with $doctorName on $date at $time',
        'appointmentId': appointmentId,
        'doctorName': doctorName,
        'userName': userName,
        'date': date,
        'time': time,
        'appointmentType': appointmentType,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send local notification (if admin app is running)
      await _sendLocalNotification(
        title: 'New Appointment Booked',
        body: '$userName - $doctorName ($date at $time)',
      );

    } catch (e) {
      print('Error sending admin notification: $e');
    }
  }

  // Send local notification
  Future<void> _sendLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'appointment_channel',
      'Appointment Notifications',
      channelDescription: 'Notifications for new appointments',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  // Update appointment statistics
  Future<void> _updateAppointmentStats(String doctorId, String date) async {
    try {
      final statsRef = _firestore
          .collection('appointment_stats')
          .doc('${doctorId}_$date');

      await _firestore.runTransaction((transaction) async {
        final statsDoc = await transaction.get(statsRef);
        
        if (statsDoc.exists) {
          final currentCount = statsDoc.data()?['appointmentCount'] ?? 0;
          transaction.update(statsRef, {
            'appointmentCount': currentCount + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(statsRef, {
            'doctorId': doctorId,
            'date': date,
            'appointmentCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating appointment stats: $e');
    }
  }

  // Get all doctors with their basic info
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection('doctors')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'specialization': data['specialization'],
          'experience': data['experience'],
          'rating': data['rating'] ?? 0.0,
          'consultationFee': data['consultationFee'] ?? 0,
          'profileImage': data['profileImage'],
          'profileImageUrl': data['profileImageUrl'],
          'availableSlots': data['availableSlots'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching doctors: $e');
      return [];
    }
  }

  // Update doctor's available slots
  Future<void> updateDoctorSlots(String doctorId, Map<String, List<String>> slots) async {
    try {
      await _firestore
          .collection('doctors')
          .doc(doctorId)
          .update({
        'availableSlots': slots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated slots for doctor $doctorId');
    } catch (e) {
      print('❌ Error updating doctor slots: $e');
      rethrow;
    }
  }

  // Get appointments for admin dashboard
  Future<List<Map<String, dynamic>>> getAppointmentsForAdmin({
    String? date,
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('appointments')
          .orderBy('createdAt', descending: true);

      if (date != null) {
        query = query.where('date', isEqualTo: date);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.limit(limit).get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching appointments for admin: $e');
      return [];
    }
  }

  // Cancel appointment
  Future<void> cancelAppointment(String appointmentId, String reason) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification about cancellation
      await _firestore.collection('admin_notifications').add({
        'type': 'appointment_cancelled',
        'title': 'Appointment Cancelled',
        'message': 'Appointment $appointmentId has been cancelled. Reason: $reason',
        'appointmentId': appointmentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error cancelling appointment: $e');
      rethrow;
    }
  }

  // Reschedule appointment
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,
    required String newTime,
  }) async {
    try {
      // Get current appointment data
      final appointmentDoc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }

      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      final doctorId = appointmentData['doctorId'];

      // Check if new slot is available
      final isAvailable = await isSlotAvailable(doctorId, newDate, newTime);
      if (!isAvailable) {
        throw Exception('Selected time slot is not available');
      }

      // Update appointment
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'date': newDate,
        'time': newTime,
        'status': 'confirmed',
        'rescheduledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification about rescheduling
      await _firestore.collection('admin_notifications').add({
        'type': 'appointment_rescheduled',
        'title': 'Appointment Rescheduled',
        'message': 'Appointment for ${appointmentData['userName']} has been rescheduled to $newDate at $newTime',
        'appointmentId': appointmentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error rescheduling appointment: $e');
      rethrow;
    }
  }

  // Get doctor's schedule for a specific date
  Future<Map<String, dynamic>> getDoctorSchedule(String doctorId, String date) async {
    try {
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();

      final appointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', isEqualTo: 'confirmed')
          .orderBy('time')
          .get();

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final availableSlots = doctorData['availableSlots'][date] ?? [];

      return {
        'doctorName': doctorData['name'],
        'totalSlots': availableSlots.length,
        'bookedSlots': appointments.docs.length,
        'availableSlots': availableSlots.length - appointments.docs.length,
        'appointments': appointments.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
      };
    } catch (e) {
      print('Error getting doctor schedule: $e');
      return {};
    }
  }

  // Validate appointment data
  bool validateAppointmentData({
    required String doctorId,
    required String userName,
    required String userPhone,
    required String date,
    required String time,
  }) {
    // Check if required fields are not empty
    if (doctorId.isEmpty || userName.isEmpty || userPhone.isEmpty || 
        date.isEmpty || time.isEmpty) {
      return false;
    }

    // Validate date format (YYYY-MM-DD)
    try {
      DateTime.parse(date);
    } catch (e) {
      return false;
    }

    // Validate time format (HH:MM)
    try {
      DateFormat("HH:mm").parse(time);
    } catch (e) {
      return false;
    }

    // Check if appointment date is not in the past
    final appointmentDate = DateTime.parse(date);
    final today = DateTime.now();
    if (appointmentDate.isBefore(DateTime(today.year, today.month, today.day))) {
      return false;
    }

    return true;
  }
}

// Usage example and helper class
class AppointmentHelper {
  static final AppointmentService _service = AppointmentService();

  // Easy-to-use method for chatbot integration
  static Future<Map<String, dynamic>> createAppointment({
    required String doctorId,
    required String userName,
    required String userPhone,
    required String date,
    required String time,
    String? userEmail,
    String? symptoms,
    String appointmentType = 'chat',
  }) async {
    try {
      // Validate input data
      if (!_service.validateAppointmentData(
        doctorId: doctorId,
        userName: userName,
        userPhone: userPhone,
        date: date,
        time: time,
      )) {
        return {
          'success': false,
          'error': 'Invalid appointment data provided',
        };
      }

      // Book appointment
      final appointmentId = await _service.bookAppointment(
        doctorId: doctorId,
        userName: userName,
        userPhone: userPhone,
        date: date,
        time: time,
        userEmail: userEmail,
        symptoms: symptoms,
        appointmentType: appointmentType,
      );

      return {
        'success': true,
        'appointmentId': appointmentId,
        'message': 'Appointment booked successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get available slots for chatbot
  static Future<List<String>> getAvailableSlots(String doctorId, String date) async {
    return await _service.fetchAvailableSlots(doctorId, date);
  }

  // Get doctors list for chatbot
  static Future<List<Map<String, dynamic>>> getDoctorsList() async {
    return await _service.getAllDoctors();
  }
}