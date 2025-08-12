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
  Future<bool> isSlotAvailable(String doctorId, String date, String time) async {
    try {
      final slotQuery = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: date)
          .where('time', isEqualTo: time)
          .where('isAvailable', isEqualTo: true)
          .where('isBooked', isEqualTo: false)
          .limit(1)
          .get();

      return slotQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking slot availability: $e');
      return false;
    }
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

 // Updated method to fetch doctor's available slots for a specific date from time_slots collection
  Future<List<String>> fetchAvailableSlots(String doctorId, String selectedDate) async {
    try {
      print('🔍 Fetching slots for doctor: $doctorId, date: $selectedDate');
      
      // Query the doctor's time_slots subcollection for available slots
      final timeSlotsQuery = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: selectedDate)
          .where('isAvailable', isEqualTo: true)
          .where('isBooked', isEqualTo: false)
          .get();

      print('📋 Found ${timeSlotsQuery.docs.length} available slot documents');

      // Extract time slots from the documents (already in 12-hour format)
      List<String> availableSlots = [];
      for (var doc in timeSlotsQuery.docs) {
        Map<String, dynamic> data = doc.data();
        String timeSlot = data['time'] ?? '';
        if (timeSlot.isNotEmpty) {
          availableSlots.add(timeSlot);
        }
        print('📅 Slot: ${data['time']} - Available: ${data['isAvailable']}, Booked: ${data['isBooked']}');
      }

      // Sort the time slots chronologically
      availableSlots.sort((a, b) => _compareTimeSlots12Hour(a, b));

      print('✅ Returning ${availableSlots.length} available slots: $availableSlots');
      return availableSlots;

    } catch (e) {
      print('❌ Error fetching available slots: $e');
      rethrow;
    }
  }
  // Helper method to compare 12-hour format time slots for sorting
  int _compareTimeSlots12Hour(String timeA, String timeB) {
    try {
      // Convert 12-hour format to 24-hour for comparison
      DateTime dateTimeA = _parseTime12Hour(timeA);
      DateTime dateTimeB = _parseTime12Hour(timeB);
      return dateTimeA.compareTo(dateTimeB);
    } catch (e) {
      print('Error comparing time slots: $e');
      return 0;
    }
  }

  // Helper method to parse 12-hour format time to DateTime for comparison
  DateTime _parseTime12Hour(String time12) {
    try {
      // Handle formats like "9:00 AM", "2:30 PM"
      final parts = time12.trim().split(' ');
      if (parts.length != 2) throw FormatException('Invalid time format: $time12');
      
      final timePart = parts[0];
      final amPm = parts[1].toUpperCase();
      
      final timeSplit = timePart.split(':');
      if (timeSplit.length != 2) throw FormatException('Invalid time format: $time12');
      
      int hour = int.parse(timeSplit[0]);
      int minute = int.parse(timeSplit[1]);
      
      // Convert to 24-hour format
      if (amPm == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return DateTime(2024, 1, 1, hour, minute);
    } catch (e) {
      print('Error parsing time $time12: $e');
      return DateTime(2024, 1, 1, 0, 0); // Default fallback
    }
  }
  Future<String> bookAppointment({
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
      print('🔄 Starting appointment booking process...');
      print('📋 Details: Doctor=$doctorId, Date=$date, Time=$time, User=$userName');

      // First, find the specific time slot document in doctor's subcollection
      final slotQuery = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: date)
          .where('time', isEqualTo: time)
          .where('isAvailable', isEqualTo: true)
          .where('isBooked', isEqualTo: false)
          .limit(1)
          .get();

      if (slotQuery.docs.isEmpty) {
        throw Exception('Selected time slot is no longer available');
      }

      final slotDoc = slotQuery.docs.first;
      final slotId = slotDoc.id;
      
      print('✅ Found available slot document: $slotId');

      // Get doctor information
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();
      
      final doctorName = doctorDoc.data()?['name'] ?? doctorDoc.data()?['fullName'] ?? 'Unknown Doctor';

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
        'slotId': slotId, // Reference to the time slot
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created appointment document: ${appointmentRef.id}');

      // Update the time slot in doctor's subcollection to mark it as booked
      await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .doc(slotId)
          .update({
        'isAvailable': false,
        'isBooked': true,
        'bookedBy': userName,
        'bookingId': appointmentRef.id,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('✅ Updated time slot $slotId as booked in doctor subcollection');

      // Update appointment statistics
      await _updateAppointmentStats(doctorId, date);

      print('🎉 Appointment booking completed successfully!');
      return appointmentRef.id;

    } catch (e) {
      print('❌ Error booking appointment: $e');
      rethrow;
    }
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