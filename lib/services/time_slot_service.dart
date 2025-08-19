// lib/services/time_slot_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlotService {
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');

  Future<bool> createTimeSlotsForDoctor(String doctorId, Map<String, dynamic> doctorData) async {
    try {
      print('Creating time slots for doctor: $doctorId');
      
      final availableDays = List<String>.from(doctorData['availableDays'] ?? []);
      final startTime = doctorData['startTime'] ?? '09:00';
      final endTime = doctorData['endTime'] ?? '17:00';
      
      final timeSlots = _generateTimeSlots(startTime, endTime);
      
      if (timeSlots.isEmpty) {
        print('No time slots generated');
        return false;
      }

      final today = DateTime.now();
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final batch = FirebaseFirestore.instance.batch();
      int slotsCreated = 0;

      // Create slots for next 30 days
      for (int dayOffset = 0; dayOffset < 30; dayOffset++) {
        final currentDate = tomorrow.add(Duration(days: dayOffset));
        final dayName = _getDayName(currentDate.weekday);
        
        if (availableDays.contains(dayName)) {
          final dateString = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
          
          for (String timeSlot in timeSlots) {
            final slotDoc = _doctorsCollection
                .doc(doctorId)
                .collection('time_slots')
                .doc();
            
            batch.set(slotDoc, {
              'doctorId': doctorId,
              'doctorName': doctorData['fullName'] ?? 'Unknown Doctor',
              'doctorEmail': doctorData['email'] ?? '',
              'specialization': doctorData['specialization'] ?? '',
              'hospital': doctorData['hospital'] ?? '',
              'consultationFee': doctorData['consultationFee'] ?? 0,
              'date': dateString,
              'time': timeSlot,
              'dayOfWeek': dayName,
              'isAvailable': true,
              'isBooked': false,
              'bookedBy': null,
              'bookingId': null,
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
            slotsCreated++;
          }
        }
      }

      await batch.commit();
      print('Successfully created $slotsCreated time slots for doctor $doctorId');
      return true;
      
    } catch (e) {
      print('Error creating time slots for doctor: $e');
      return false;
    }
  }

  // Convert 24-hour time to 12-hour format
  String _convertTo12HourFormat(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      String period = hour >= 12 ? 'PM' : 'AM';
      
      int hour12 = hour;
      if (hour == 0) {
        hour12 = 12;
      } else if (hour > 12) {
        hour12 = hour - 12;
      }
      
      String minuteStr = minute.toString().padLeft(2, '0');
      return '$hour12:$minuteStr $period';
    } catch (e) {
      print('Error converting time to 12-hour format: $e');
      return time24;
    }
  }

  // Generate time slots in 12-hour format
  List<String> _generateTimeSlots(String startTime, String endTime) {
    try {
      final List<String> slots = [];
      
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      int startHour = int.parse(startParts[0]);
      int startMinute = int.parse(startParts[1]);
      int endHour = int.parse(endParts[0]);
      int endMinute = int.parse(endParts[1]);
      
      DateTime start = DateTime(2024, 1, 1, startHour, startMinute);
      DateTime end = DateTime(2024, 1, 1, endHour, endMinute);
      
      DateTime current = start;
      while (current.isBefore(end)) {
        final hour24 = current.hour.toString().padLeft(2, '0');
        final minute = current.minute.toString().padLeft(2, '0');
        final time24 = '$hour24:$minute';
        
        final time12 = _convertTo12HourFormat(time24);
        slots.add(time12);
        
        current = current.add(const Duration(minutes: 30)); // 30-minute slots
      }
      
      print('Generated ${slots.length} time slots: $slots');
      return slots;
    } catch (e) {
      print('Error generating time slots: $e');
      return [];
    }
  }

  // Get day name from weekday number
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }

  // Get available time slots for a doctor on a specific date
  Future<List<Map<String, dynamic>>> getAvailableTimeSlots(String doctorId, String date) async {
    try {
      final querySnapshot = await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: date)
          .where('isAvailable', isEqualTo: true)
          .where('isBooked', isEqualTo: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['slotId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting available time slots: $e');
      return [];
    }
  }

  // Book a time slot
  Future<bool> bookTimeSlot(String doctorId, String slotId, String patientId, String bookingId) async {
    try {
      await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .doc(slotId)
          .update({
        'isBooked': true,
        'isAvailable': false,
        'bookedBy': patientId,
        'bookingId': bookingId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error booking time slot: $e');
      return false;
    }
  }

  // Cancel a booking
  Future<bool> cancelTimeSlot(String doctorId, String slotId) async {
    try {
      await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .doc(slotId)
          .update({
        'isBooked': false,
        'isAvailable': true,
        'bookedBy': null,
        'bookingId': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error canceling time slot: $e');
      return false;
    }
  }

  // Get booked appointments for a doctor
  Future<List<Map<String, dynamic>>> getBookedAppointments(String doctorId) async {
    try {
      final querySnapshot = await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .where('isBooked', isEqualTo: true)
          .orderBy('date')
          .orderBy('time')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['slotId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting booked appointments: $e');
      return [];
    }
  }

  // Helper method to compare 12-hour format time slots for sorting
  int compareTimeSlots12Hour(String timeA, String timeB) {
    try {
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
      final parts = time12.trim().split(' ');
      if (parts.length != 2) throw FormatException('Invalid time format: $time12');
      
      final timePart = parts[0];
      final amPm = parts[1].toUpperCase();
      
      final timeSplit = timePart.split(':');
      if (timeSplit.length != 2) throw FormatException('Invalid time format: $time12');
      
      int hour = int.parse(timeSplit[0]);
      int minute = int.parse(timeSplit[1]);
      
      if (amPm == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return DateTime(2024, 1, 1, hour, minute);
    } catch (e) {
      print('Error parsing time $time12: $e');
      return DateTime(2024, 1, 1, 0, 0);
    }
  }

  // Create sample time slots for testing
  Future<bool> createSampleTimeSlotsForDoctor(String doctorId, String doctorName) async {
    try {
      print('Creating sample time slots for doctor: $doctorId');

      final batch = FirebaseFirestore.instance.batch();
      final times = [
        '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM',
        '2:00 PM', '2:30 PM', '3:00 PM', '3:30 PM', '4:00 PM'
      ];

      // Create slots for next 7 days
      for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
        final date = DateTime.now().add(Duration(days: dayOffset));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        for (String time in times) {
          final slotRef = _doctorsCollection
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
      print('Sample time slots created successfully');
      return true;

    } catch (e) {
      print('Error creating sample time slots: $e');
      return false;
    }
  }

  // Delete all time slots for a doctor (useful for cleanup)
  Future<bool> deleteAllTimeSlotsForDoctor(String doctorId) async {
    try {
      final slotsSnapshot = await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in slotsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('All time slots deleted for doctor: $doctorId');
      return true;
    } catch (e) {
      print('Error deleting time slots: $e');
      return false;
    }
  }
}