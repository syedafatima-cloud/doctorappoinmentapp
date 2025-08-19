// appointment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Update doctor's available slots
Future<void> updateDoctorSlots(String doctorId, Map<String, List<String>> slots) async {
  try {
    print('🔄 Updating slots for doctor: $doctorId');
    print('📅 New slots data: $slots');
    
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

// Alternative version that creates time_slots subcollection documents
Future<void> updateDoctorTimeSlotsCollection(
  String doctorId, 
  String doctorName,
  Map<String, List<String>> newSlots
) async {
  try {
    print('🔄 Updating time_slots collection for doctor: $doctorId');
    
    final batch = _firestore.batch();
    
    // First, delete existing time slots for future dates
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final futureDate = tomorrow.add(const Duration(days: 30));
    
    // Delete existing future slots
    final existingSlotsQuery = await _firestore
        .collection('doctors')
        .doc(doctorId)
        .collection('time_slots')
        .where('date', isGreaterThanOrEqualTo: _formatDate(tomorrow))
        .where('date', isLessThanOrEqualTo: _formatDate(futureDate))
        .where('isBooked', isEqualTo: false) // Only delete unbooked slots
        .get();
    
    print('🗑️ Deleting ${existingSlotsQuery.docs.length} existing unbooked slots');
    
    for (var doc in existingSlotsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    // Create new time slots
    int slotsCreated = 0;
    
    newSlots.forEach((dateString, timeSlots) {
      for (String timeSlot in timeSlots) {
        final slotRef = _firestore
            .collection('doctors')
            .doc(doctorId)
            .collection('time_slots')
            .doc();
        
        batch.set(slotRef, {
          'doctorId': doctorId,
          'doctorName': doctorName,
          'date': dateString,
          'time': timeSlot,
          'isAvailable': true,
          'isBooked': false,
          'bookedBy': null,
          'bookingId': null,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        slotsCreated++;
      }
    });
    
    await batch.commit();
    print('✅ Updated time_slots collection: created $slotsCreated new slots');
    
  } catch (e) {
    print('❌ Error updating doctor time slots collection: $e');
    rethrow;
  }
}

// Helper method to format date consistently
String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// Bulk update multiple doctors' slots
Future<void> bulkUpdateDoctorSlots(Map<String, Map<String, List<String>>> doctorSlots) async {
  try {
    print('🔄 Bulk updating slots for ${doctorSlots.length} doctors');
    
    final batch = _firestore.batch();
    
    doctorSlots.forEach((doctorId, slots) {
      final doctorRef = _firestore.collection('doctors').doc(doctorId);
      batch.update(doctorRef, {
        'availableSlots': slots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    
    await batch.commit();
    print('✅ Bulk update completed for ${doctorSlots.length} doctors');
    
  } catch (e) {
    print('❌ Error in bulk update: $e');
    rethrow;
  }
}

// Add available slots for a specific date
Future<void> addSlotsForDate(
  String doctorId, 
  String doctorName,
  String date, 
  List<String> timeSlots
) async {
  try {
    print('➕ Adding ${timeSlots.length} slots for doctor $doctorId on $date');
    
    final batch = _firestore.batch();
    
    for (String timeSlot in timeSlots) {
      // Check if slot already exists
      final existingSlot = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: date)
          .where('time', isEqualTo: timeSlot)
          .limit(1)
          .get();
      
      if (existingSlot.docs.isEmpty) {
        // Create new slot if it doesn't exist
        final slotRef = _firestore
            .collection('doctors')
            .doc(doctorId)
            .collection('time_slots')
            .doc();
        
        batch.set(slotRef, {
          'doctorId': doctorId,
          'doctorName': doctorName,
          'date': date,
          'time': timeSlot,
          'isAvailable': true,
          'isBooked': false,
          'bookedBy': null,
          'bookingId': null,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    }
    
    await batch.commit();
    print('✅ Added slots for $date');
    
  } catch (e) {
    print('❌ Error adding slots for date: $e');
    rethrow;
  }
}

// Remove available slots for a specific date
Future<void> removeSlotsForDate(String doctorId, String date) async {
  try {
    print('🗑️ Removing slots for doctor $doctorId on $date');
    
    final slotsQuery = await _firestore
        .collection('doctors')
        .doc(doctorId)
        .collection('time_slots')
        .where('date', isEqualTo: date)
        .where('isBooked', isEqualTo: false) // Only remove unbooked slots
        .get();
    
    final batch = _firestore.batch();
    
    for (var doc in slotsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    print('✅ Removed ${slotsQuery.docs.length} unbooked slots for $date');
    
  } catch (e) {
    print('❌ Error removing slots for date: $e');
    rethrow;
  }
}
  // Check if a specific slot is available
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

  // Fetch available slots for a specific doctor and date
  Future<List<String>> fetchAvailableSlots(String doctorId, String selectedDate) async {
    try {
      print('🔍 Fetching slots for doctor: $doctorId, date: $selectedDate');
      
      // Get all slots for the specific date
      final query = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: selectedDate)
          .get();

      print('📋 Found ${query.docs.length} total slots for date: $selectedDate');

      List<String> availableSlots = [];

      for (var doc in query.docs) {
        final data = doc.data();
        final time = data['time']?.toString() ?? '';
        final isAvailable = data['isAvailable'] == true;
        final isBooked = data['isBooked'] == true;

        print('📄 Slot: time="$time", available=$isAvailable, booked=$isBooked');

        // Add to available list if slot is available and not booked
        if (time.isNotEmpty && isAvailable && !isBooked) {
          availableSlots.add(time);
        }
      }

      // Sort slots chronologically
      availableSlots.sort((a, b) => _compareTimeSlots(a, b));

      print('✅ Returning ${availableSlots.length} available slots: $availableSlots');
      return availableSlots;

    } catch (e) {
      print('❌ Error fetching available slots: $e');
      return [];
    }
  }

  // Compare time slots for sorting (handles 12-hour format)
  int _compareTimeSlots(String timeA, String timeB) {
    try {
      final parsedA = _parseTime12Hour(timeA);
      final parsedB = _parseTime12Hour(timeB);
      return parsedA.compareTo(parsedB);
    } catch (e) {
      return 0;
    }
  }

  // Parse 12-hour time format to DateTime for comparison
  DateTime _parseTime12Hour(String time12) {
    try {
      final parts = time12.trim().split(' ');
      if (parts.length != 2) throw FormatException('Invalid time format');
      
      final timePart = parts[0];
      final amPm = parts[1].toUpperCase();
      
      final timeSplit = timePart.split(':');
      if (timeSplit.length != 2) throw FormatException('Invalid time format');
      
      int hour = int.parse(timeSplit[0]);
      int minute = int.parse(timeSplit[1]);
      
      if (amPm == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return DateTime(2024, 1, 1, hour, minute);
    } catch (e) {
      return DateTime(2024, 1, 1, 0, 0);
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
    String appointmentType = 'chat',
  }) async {
    try {
      print('🔄 Booking appointment...');
      print('Doctor: $doctorId, Date: $date, Time: $time, User: $userName');

      // Find the specific time slot
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

      // Get doctor information
      final doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();
      final doctorData = doctorDoc.data() ?? {};
      final doctorName = doctorData['name'] ?? doctorData['fullName'] ?? 'Unknown Doctor';

      // Create appointment
      final appointmentRef = await _firestore.collection('appointments').add({
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
        'slotId': slotId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark the slot as booked
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

      print('✅ Appointment booked successfully: ${appointmentRef.id}');
      return appointmentRef.id;

    } catch (e) {
      print('❌ Error booking appointment: $e');
      rethrow;
    }
  }

  // Get all doctors
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    try {
      final querySnapshot = await _firestore.collection('doctors').get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? data['fullName'] ?? 'Unknown',
          'specialization': data['specialization'] ?? '',
          'experience': data['experience'] ?? data['experienceYears'] ?? 0,
          'rating': data['rating'] ?? 0.0,
          'consultationFee': data['consultationFee'] ?? 0,
          'profileImage': data['profileImage'],
          'profileImageUrl': data['profileImageUrl'],
          'hospital': data['hospital'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching doctors: $e');
      return [];
    }
  }

  // Cancel appointment
  Future<void> cancelAppointment(String appointmentId, String reason) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error cancelling appointment: $e');
      rethrow;
    }
  }

  // Get appointments for admin
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

  // Create sample time slots for testing
  Future<void> createSampleTimeSlots(String doctorId, String doctorName) async {
    try {
      print('🔧 Creating sample time slots for doctor: $doctorId');

      final batch = _firestore.batch();
      final times = [
        '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM',
        '2:00 PM', '2:30 PM', '3:00 PM', '3:30 PM', '4:00 PM'
      ];

      // Create slots for next 7 days
      for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
        final date = DateTime.now().add(Duration(days: dayOffset));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        for (String time in times) {
          final slotRef = _firestore
              .collection('doctors')
              .doc(doctorId)
              .collection('time_slots')
              .doc();

          batch.set(slotRef, {
            'doctorId': doctorId,
            'doctorName': doctorName,
            'date': dateString,
            'time': time,
            'isAvailable': true,
            'isBooked': false,
            'bookedBy': null,
            'bookingId': null,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      await batch.commit();
      print('✅ Sample time slots created successfully');

    } catch (e) {
      print('❌ Error creating sample time slots: $e');
      rethrow;
    }
  }

  // Debug method to check time slots
  Future<void> debugTimeSlots(String doctorId) async {
    try {
      print('🔍 === DEBUG TIME SLOTS START ===');
      print('Doctor ID: $doctorId');

      final allSlots = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('time_slots')
          .limit(20)
          .get();

      print('Total slots found: ${allSlots.docs.length}');

      if (allSlots.docs.isEmpty) {
        print('❌ No time slots found for this doctor');
        return;
      }

      Map<String, int> slotsByDate = {};
      for (var doc in allSlots.docs) {
        final data = doc.data();
        final date = data['date']?.toString() ?? 'unknown';
        slotsByDate[date] = (slotsByDate[date] ?? 0) + 1;

        if (slotsByDate.length <= 3) { // Show first few for debugging
          print('Slot: date="$date", time="${data['time']}", available=${data['isAvailable']}, booked=${data['isBooked']}');
        }
      }

      print('Slots by date: $slotsByDate');
      print('🔍 === DEBUG TIME SLOTS END ===');

    } catch (e) {
      print('❌ Debug error: $e');
    }
  }
}

// Helper class for easy appointment creation
class AppointmentHelper {
  static final AppointmentService _service = AppointmentService();

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

  static Future<List<String>> getAvailableSlots(String doctorId, String date) async {
    return await _service.fetchAvailableSlots(doctorId, date);
  }

  static Future<List<Map<String, dynamic>>> getDoctorsList() async {
    return await _service.getAllDoctors();
  }
}