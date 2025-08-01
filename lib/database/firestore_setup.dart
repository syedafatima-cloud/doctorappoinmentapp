import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper function to generate sample time slots for the next 7 days
  static Map<String, List<String>> _generateSampleSlots(String startTime, String endTime) {
    final slots = <String, List<String>>{};
    final format = DateFormat("HH:mm");
    final start = format.parse(startTime);
    final end = format.parse(endTime);
    
    // Generate slots for next 7 days
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      
      List<String> daySlots = [];
      DateTime current = start;
      
      while (current.isBefore(end)) {
        daySlots.add(format.format(current));
        current = current.add(const Duration(minutes: 15));
      }
      
      slots[dateString] = daySlots;
    }
    
    return slots;
  }

  // Initialize sample data (run this once)
  static Future<void> initializeSampleData() async {
    try {
      // Add sample doctors
      await _addSampleDoctors();
      print('Sample data initialized successfully');
    } catch (e) {
      print('Error initializing sample data: $e');
    }
  }

  static Future<void> _addSampleDoctors() async {
    final doctors = [
      {
        // Basic Information
        'id': 'doctor_001',
        'name': 'Dr. Ayesha Khan',
        'fullName': 'Dr. Ayesha Khan',
        'email': 'ayesha.khan@hospital.com',
        'phone': '+92-300-1234567',
        'phoneNumber': '+92-300-1234567',
        
        // Professional Information
        'specialization': 'General Practice',
        'experience': 8,
        'experienceYears': 8,
        'licenseNumber': 'PMC-GP-2016-001',
        'hospital': 'City General Hospital',
        'address': '123 Medical Center, Lahore, Punjab',
        'qualifications': 'MBBS, FCPS (Family Medicine)',
        
        // Profile and Status
        'profileImage': 'https://example.com/images/dr_ayesha.jpg',
        'profileImageUrl': 'https://example.com/images/dr_ayesha.jpg',
        'rating': 4.5,
        'consultationFee': 1500.0,
        'isActive': true,
        'isVerified': true,
        
        // Schedule Information
        'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        'startTime': '09:00',
        'endTime': '17:00',
        'registrationDate': DateTime.now().toIso8601String(),
        
        // Available Slots - Generate for next 7 days
        'availableSlots': _generateSampleSlots('09:00', '17:00'),
      },
      {
        // Basic Information
        'id': 'doctor_002',
        'name': 'Dr. Muhammad Ali',
        'fullName': 'Dr. Muhammad Ali',
        'email': 'muhammad.ali@cardio.com',
        'phone': '+92-321-9876543',
        'phoneNumber': '+92-321-9876543',
        
        // Professional Information
        'specialization': 'Cardiology',
        'experience': 12,
        'experienceYears': 12,
        'licenseNumber': 'PMC-CARD-2013-002',
        'hospital': 'Heart Care Institute',
        'address': '456 Cardiac Plaza, Karachi, Sindh',
        'qualifications': 'MBBS, FCPS (Cardiology), MRCP',
        
        // Profile and Status
        'profileImage': 'https://example.com/images/dr_ali.jpg',
        'profileImageUrl': 'https://example.com/images/dr_ali.jpg',
        'rating': 4.8,
        'consultationFee': 2500.0,
        'isActive': true,
        'isVerified': true,
        
        // Schedule Information
        'availableDays': ['Monday', 'Wednesday', 'Friday', 'Saturday'],
        'startTime': '10:00',
        'endTime': '18:00',
        'registrationDate': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        
        // Available Slots - Generate for next 7 days
        'availableSlots': _generateSampleSlots('10:00', '18:00'),
      },
      {
        // Basic Information
        'id': 'doctor_003',
        'name': 'Dr. Fatima Sheikh',
        'fullName': 'Dr. Fatima Sheikh',
        'email': 'fatima.sheikh@derma.com',
        'phone': '+92-333-5555555',
        'phoneNumber': '+92-333-5555555',
        
        // Professional Information
        'specialization': 'Dermatology',
        'experience': 6,
        'experienceYears': 6,
        'licenseNumber': 'PMC-DERM-2019-003',
        'hospital': 'Skin Care Clinic',
        'address': '789 Beauty Avenue, Islamabad, ICT',
        'qualifications': 'MBBS, FCPS (Dermatology)',
        
        // Profile and Status
        'profileImage': 'https://example.com/images/dr_fatima.jpg',
        'profileImageUrl': 'https://example.com/images/dr_fatima.jpg',
        'rating': 4.3,
        'consultationFee': 2000.0,
        'isActive': true,
        'isVerified': true,
        
        // Schedule Information
        'availableDays': ['Tuesday', 'Thursday', 'Saturday', 'Sunday'],
        'startTime': '09:00',
        'endTime': '16:00',
        'registrationDate': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        
        // Available Slots - Generate for next 7 days
        'availableSlots': _generateSampleSlots('09:00', '16:00'),
      },
      {
        // Basic Information
        'id': 'doctor_004',
        'name': 'Dr. Ahmed Hassan',
        'fullName': 'Dr. Ahmed Hassan',
        'email': 'ahmed.hassan@pediatrics.com',
        'phone': '+92-345-7777777',
        'phoneNumber': '+92-345-7777777',
        
        // Professional Information
        'specialization': 'Pediatrics',
        'experience': 10,
        'experienceYears': 10,
        'licenseNumber': 'PMC-PED-2015-004',
        'hospital': 'Children\'s Medical Center',
        'address': '321 Kids Care Street, Faisalabad, Punjab',
        'qualifications': 'MBBS, FCPS (Pediatrics), DCH',
        
        // Profile and Status
        'profileImage': 'https://example.com/images/dr_ahmed.jpg',
        'profileImageUrl': 'https://example.com/images/dr_ahmed.jpg',
        'rating': 4.6,
        'consultationFee': 1800.0,
        'isActive': true,
        'isVerified': true,
        
        // Schedule Information
        'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
        'startTime': '08:00',
        'endTime': '18:00',
        'registrationDate': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
        
        // Available Slots
        'availableSlots': {
          '2025-07-26': ['08:00', '08:15', '08:30', '08:45', '09:00', '09:15', '09:30', '09:45', '17:00', '17:15', '17:30', '17:45'],
          '2025-07-27': ['08:00', '08:15', '08:30', '08:45', '09:00', '09:15', '09:30', '09:45', '17:00', '17:15', '17:30', '17:45'],
          '2025-07-28': ['08:00', '08:15', '08:30', '08:45', '09:00', '09:15', '09:30', '09:45'],
        }
      },
      {
        // Recently registered doctor (pending verification)
        'id': 'doctor_005',
        'name': 'Dr. Sarah Khan',
        'fullName': 'Dr. Sarah Khan',
        'email': 'sarah.khan@neuro.com',
        'phone': '+92-300-9999999',
        'phoneNumber': '+92-300-9999999',
        
        // Professional Information
        'specialization': 'Neurology',
        'experience': 4,
        'experienceYears': 4,
        'licenseNumber': 'PMC-NEU-2021-005',
        'hospital': 'Brain & Spine Center',
        'address': '555 Neural Network Road, Lahore, Punjab',
        'qualifications': 'MBBS, FCPS (Neurology)',
        
        // Profile and Status
        'profileImage': '', // No image uploaded yet
        'profileImageUrl': '',
        'rating': 0.0, // New doctor, no ratings yet
        'consultationFee': 2200.0,
        'isActive': false, // Inactive until verified
        'isVerified': false, // Pending verification
        
        // Schedule Information
        'availableDays': ['Monday', 'Wednesday', 'Friday'],
        'startTime': '14:00',
        'endTime': '20:00',
        'registrationDate': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        
        // Available Slots (empty until activated)
        'availableSlots': {}
      },
    ];

    for (var doctorData in doctors) {
      await _firestore.collection('doctors').add(doctorData);
    }
  }

  // Create indexes (these should be created in Firebase Console)
  static void createIndexes() {
    print('''
    Create these indexes in Firebase Console:

    Collection: doctors
    Fields: isActive (Ascending), isVerified (Ascending), specialization (Ascending)
    
    Collection: doctors
    Fields: specialization (Ascending), rating (Descending)
    
    Collection: doctors
    Fields: isVerified (Ascending), registrationDate (Descending)

    Collection: appointments
    Fields: doctorId (Ascending), date (Ascending), status (Ascending)
    
    Collection: appointments  
    Fields: date (Ascending), createdAt (Descending)
    
    Collection: appointments
    Fields: status (Ascending), createdAt (Descending)
    
    Collection: admin_notifications
    Fields: isRead (Ascending), createdAt (Descending)
    
    Collection: doctor_registrations
    Fields: isVerified (Ascending), registrationDate (Descending)
    ''');
  }

  // Generate time slots helper for updating doctor schedules
  static List<String> generateDailySlots({
    required String startTime,
    required String endTime,
    int intervalMinutes = 15,
    List<String> breakTimes = const [], // e.g., ['12:00', '12:15', '12:30', '12:45', '13:00']
  }) {
    final format = DateFormat("HH:mm");
    final start = format.parse(startTime);
    final end = format.parse(endTime);
    
    List<String> slots = [];
    DateTime current = start;
    
    while (current.isBefore(end)) {
      final timeStr = format.format(current);
      if (!breakTimes.contains(timeStr)) {
        slots.add(timeStr);
      }
      current = current.add(Duration(minutes: intervalMinutes));
    }
    
    return slots;
  }

  // Add more available dates for doctors
  static Future<void> addDoctorSchedule({
    required String doctorId,
    required String date,
    required String startTime,
    required String endTime,
    List<String> breakTimes = const [],
  }) async {
    try {
      final slots = generateDailySlots(
        startTime: startTime,
        endTime: endTime,
        breakTimes: breakTimes,
      );

      await _firestore.collection('doctors').doc(doctorId).update({
        'availableSlots.$date': slots,
      });

      print('Schedule added for doctor $doctorId on $date');
    } catch (e) {
      print('Error adding doctor schedule: $e');
    }
  }

  // Generate schedule for multiple days
  static Future<void> addDoctorScheduleRange({
    required String doctorId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> availableDays,
    required String startTime,
    required String endTime,
    List<String> breakTimes = const [],
  }) async {
    try {
      final Map<String, List<String>> scheduleMap = {};
      final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
      final DateFormat dayFormat = DateFormat('EEEE');

      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        final dayName = dayFormat.format(currentDate);
        
        if (availableDays.contains(dayName)) {
          final dateStr = dateFormat.format(currentDate);
          final slots = generateDailySlots(
            startTime: startTime,
            endTime: endTime,
            breakTimes: breakTimes,
          );
          scheduleMap['availableSlots.$dateStr'] = slots;
        }
        
        currentDate = currentDate.add(const Duration(days: 1));
      }

      if (scheduleMap.isNotEmpty) {
        await _firestore.collection('doctors').doc(doctorId).update(scheduleMap);
        print('Schedule range added for doctor $doctorId');
      }
    } catch (e) {
      print('Error adding doctor schedule range: $e');
    }
  }

  // Update doctor verification status
  static Future<void> verifyDoctor(String doctorId, bool isVerified) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({
        'isVerified': isVerified,
        'isActive': isVerified, // Activate when verified
        'verificationDate': isVerified ? FieldValue.serverTimestamp() : null,
      });

      print('Doctor $doctorId verification status updated to: $isVerified');
    } catch (e) {
      print('Error updating doctor verification: $e');
    }
  }

  // Update doctor profile image
  static Future<void> updateDoctorProfileImage(String doctorId, String imageUrl) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({
        'profileImage': imageUrl,
        'profileImageUrl': imageUrl,
        'imageUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('Profile image updated for doctor $doctorId');
    } catch (e) {
      print('Error updating doctor profile image: $e');
    }
  }

  // Get pending doctor registrations for admin
  static Future<List<Map<String, dynamic>>> getPendingDoctorRegistrations() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('doctors')
          .where('isVerified', isEqualTo: false)
          .orderBy('registrationDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      print('Error getting pending registrations: $e');
      return [];
    }
  }

  // Get verified and active doctors
  static Future<List<Map<String, dynamic>>> getActiveDoctors({String? specialization}) async {
    try {
      Query query = _firestore
          .collection('doctors')
          .where('isActive', isEqualTo: true)
          .where('isVerified', isEqualTo: true);

      if (specialization != null && specialization.isNotEmpty) {
        query = query.where('specialization', isEqualTo: specialization);
      }

      final QuerySnapshot snapshot = await query
          .orderBy('rating', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      print('Error getting active doctors: $e');
      return [];
    }
  }

  // Backup and restore functions
  static Future<void> backupAppointments(String date) async {
    try {
      final appointments = await _firestore
          .collection('appointments')
          .where('date', isEqualTo: date)
          .get();

      final backupData = {
        'date': date,
        'appointmentCount': appointments.docs.length,
        'appointments': appointments.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'backedUpAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('appointment_backups')
          .doc('backup_$date')
          .set(backupData);

      print('Appointments backed up for $date');
    } catch (e) {
      print('Error backing up appointments: $e');
    }
  }

  // Backup doctor registrations
  static Future<void> backupDoctorRegistrations() async {
    try {
      final doctors = await _firestore.collection('doctors').get();

      final backupData = {
        'totalDoctors': doctors.docs.length,
        'doctors': doctors.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'backedUpAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('doctor_backups')
          .doc('backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}')
          .set(backupData);

      print('Doctor registrations backed up');
    } catch (e) {
      print('Error backing up doctor registrations: $e');
    }
  }

  // Clean up old data
  static Future<void> cleanupOldData() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      
      // Clean up old appointment backups
      final oldBackups = await _firestore
          .collection('appointment_backups')
          .where('backedUpAt', isLessThan: cutoffDate)
          .get();

      for (var doc in oldBackups.docs) {
        await doc.reference.delete();
      }

      // Clean up old available slots
      final doctors = await _firestore.collection('doctors').get();
      for (var doc in doctors.docs) {
        final data = doc.data();
        if (data['availableSlots'] != null) {
          final Map<String, dynamic> availableSlots = data['availableSlots'];
          final Map<String, dynamic> updatedSlots = {};
          
          for (var entry in availableSlots.entries) {
            try {
              final slotDate = DateTime.parse(entry.key);
              if (slotDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
                updatedSlots[entry.key] = entry.value;
              }
            } catch (e) {
              // Keep non-date keys
              updatedSlots[entry.key] = entry.value;
            }
          }
          
          if (updatedSlots.length != availableSlots.length) {
            await doc.reference.update({'availableSlots': updatedSlots});
          }
        }
      }

      print('Old data cleaned up successfully');
    } catch (e) {
      print('Error cleaning up old data: $e');
    }
  }
}