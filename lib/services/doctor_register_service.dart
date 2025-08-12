// services/doctor_registration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_register_model.dart';

class DoctorRegistrationService {
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');
  
  // NEW: Collection for pending doctor registrations (admin approval system)
  final CollectionReference _pendingDoctorRegistrationsCollection = 
      FirebaseFirestore.instance.collection('pending_doctor_registrations');


  // Enhanced validation method to check across both collections
  Future<void> _validateDoctorUniqueness(String email, String licenseNumber) async {
    // Check in pending registrations for email
    final existingPendingEmail = await _pendingDoctorRegistrationsCollection
        .where('email', isEqualTo: email)
        .where('status', whereIn: ['pending', 'approved'])
        .get();
    
    if (existingPendingEmail.docs.isNotEmpty) {
      final status = (existingPendingEmail.docs.first.data() as Map<String, dynamic>)['status'];
      if (status == 'pending') {
        throw Exception('You already have a pending registration request');
      }
    }

    // Check in approved doctors collection for email
    final existingApprovedEmail = await _doctorsCollection
        .where('email', isEqualTo: email)
        .get();
    
    if (existingApprovedEmail.docs.isNotEmpty) {
      throw Exception('Doctor with this email already exists');
    }

    // Check in pending registrations for license
    final existingPendingLicense = await _pendingDoctorRegistrationsCollection
        .where('licenseNumber', isEqualTo: licenseNumber)
        .where('status', whereIn: ['pending', 'approved'])
        .get();
    
    if (existingPendingLicense.docs.isNotEmpty) {
      final status = (existingPendingLicense.docs.first.data() as Map<String, dynamic>)['status'];
      if (status == 'pending') {
        throw Exception('A registration request with this license number is already pending');
      }
    }

    // Check in approved doctors collection for license
    final existingApprovedLicense = await _doctorsCollection
        .where('licenseNumber', isEqualTo: licenseNumber)
        .get();
    
    if (existingApprovedLicense.docs.isNotEmpty) {
      throw Exception('Doctor with this license number already exists');
    }
  }

  // FIXED METHOD: Convert 24-hour time to 12-hour format
  String _convertTo12HourFormat(String time24) {
    try {
      // Parse the 24-hour time (HH:MM format)
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      // Determine AM/PM
      String period = hour >= 12 ? 'PM' : 'AM';
      
      // Convert hour to 12-hour format
      int hour12 = hour;
      if (hour == 0) {
        hour12 = 12; // 12 AM
      } else if (hour > 12) {
        hour12 = hour - 12; // PM hours
      }
      
      // Format with leading zero for minutes
      String minuteStr = minute.toString().padLeft(2, '0');
      
      return '$hour12:$minuteStr $period';
    } catch (e) {
      print('Error converting time to 12-hour format: $e');
      return time24; // Return original if conversion fails
    }
  }

  // FIXED METHOD: Generate time slots in 12-hour format
  List<String> _generateTimeSlots(String startTime, String endTime) {
    try {
      final List<String> slots = [];
      
      // Parse start and end times (expecting format "HH:MM" in 24-hour)
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      int startHour = int.parse(startParts[0]);
      int startMinute = int.parse(startParts[1]);
      int endHour = int.parse(endParts[0]);
      int endMinute = int.parse(endParts[1]);
      
      // Create DateTime objects for easier manipulation
      DateTime start = DateTime(2024, 1, 1, startHour, startMinute);
      DateTime end = DateTime(2024, 1, 1, endHour, endMinute);
      
      // Generate 30-minute slots
      DateTime current = start;
      while (current.isBefore(end)) {
        // Convert to 24-hour format first
        final hour24 = current.hour.toString().padLeft(2, '0');
        final minute = current.minute.toString().padLeft(2, '0');
        final time24 = '$hour24:$minute';
        
        // Convert to 12-hour format for storage
        final time12 = _convertTo12HourFormat(time24);
        slots.add(time12);
        
        current = current.add(const Duration(minutes: 30)); // 30-minute slots
      }
      
      print('Generated ${slots.length} time slots in 12-hour format: $slots');
      return slots;
    } catch (e) {
      print('Error generating time slots: $e');
      return [];
    }
  }

  // UPDATED METHOD: Create time slots as subcollection under each doctor
  Future<bool> _createTimeSlotsForDoctor(String doctorId, Map<String, dynamic> doctorData) async {
    try {
      print('Creating time slots for doctor: $doctorId');
      
      final availableDays = List<String>.from(doctorData['availableDays'] ?? []);
      final startTime = doctorData['startTime'] ?? '09:00';
      final endTime = doctorData['endTime'] ?? '17:00';
      
      // Generate time slots in 12-hour format
      final timeSlots = _generateTimeSlots(startTime, endTime);
      
      if (timeSlots.isEmpty) {
        print('No time slots generated');
        return false;
      }

      // FIXED: Create time slots as subcollection under the specific doctor
      final today = DateTime.now();
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final batch = FirebaseFirestore.instance.batch();
      int slotsCreated = 0;

      for (int dayOffset = 0; dayOffset < 30; dayOffset++) {
        final currentDate = tomorrow.add(Duration(days: dayOffset));
        final dayName = _getDayName(currentDate.weekday);
        
        // Only create slots for available days
        if (availableDays.contains(dayName)) {
          final dateString = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
          
          for (String timeSlot in timeSlots) {
            // Create time slot in doctor's subcollection: doctors/{doctorId}/time_slots/{slotId}
            final slotDoc = _doctorsCollection
                .doc(doctorId)
                .collection('time_slots')
                .doc(); // Auto-generate document ID
            
            batch.set(slotDoc, {
              'doctorId': doctorId,
              'doctorName': doctorData['fullName'] ?? 'Unknown Doctor',
              'doctorEmail': doctorData['email'] ?? '',
              'specialization': doctorData['specialization'] ?? '',
              'hospital': doctorData['hospital'] ?? '',
              'consultationFee': doctorData['consultationFee'] ?? 0,
              'date': dateString,
              'time': timeSlot, // 12-hour format (e.g., "9:00 AM", "2:30 PM")
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

      // Commit the batch
      await batch.commit();
      print('Successfully created $slotsCreated time slots in doctor subcollection for doctor $doctorId');
      return true;
      
    } catch (e) {
      print('Error creating time slots for doctor: $e');
      return false;
    }
  }


  // Helper method to get day name from weekday number
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

  // NEW METHOD: Submit doctor registration for admin approval
  Future<String?> submitDoctorRegistrationRequest(Map<String, dynamic> doctorData) async {
    try {
      // Use enhanced validation method
      await _validateDoctorUniqueness(doctorData['email'], doctorData['licenseNumber']);

      // Add timestamp and initial status
      doctorData['submissionDate'] = DateTime.now().toIso8601String();
      doctorData['status'] = 'pending'; // pending, approved, rejected
      doctorData['reviewDate'] = null;
      doctorData['reviewedBy'] = null;
      doctorData['rejectionReason'] = null;

      // Add to pending registrations collection
      DocumentReference docRef = await _pendingDoctorRegistrationsCollection.add(doctorData);
      
      // Update the document with its own ID
      await docRef.update({'requestId': docRef.id});
      
      return docRef.id;
    } catch (e) {
      print('Error submitting doctor registration request: $e');
      rethrow;
    }
  }

  // NEW METHOD: Get all pending doctor registration requests (for admin)
  Future<List<Map<String, dynamic>>> getPendingRegistrationRequests() async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'pending')
          .get(); // Removed orderBy to avoid composite index requirement
      
      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        return data;
      }).toList();

      // Sort in memory by submission date (newest first)
      results.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['submissionDate'] ?? '');
          final bDate = DateTime.parse(b['submissionDate'] ?? '');
          return bDate.compareTo(aDate); // Descending order
        } catch (e) {
          return 0; // If date parsing fails, maintain current order
        }
      });

      return results;
    } catch (e) {
      print('Error getting pending registration requests: $e');
      return [];
    }
  }

  // NEW METHOD: Get registration request by ID
  Future<Map<String, dynamic>?> getRegistrationRequestById(String requestId) async {
    try {
      DocumentSnapshot doc = await _pendingDoctorRegistrationsCollection.doc(requestId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting registration request: $e');
      return null;
    }
  }

  // UPDATED METHOD: Approve doctor registration (admin function) with automatic time slot creation in 12-hour format
  Future<bool> approveDoctorRegistration(String requestId, String adminId) async {
    try {
      print('Starting approval process for request: $requestId');
      
      // Get the pending registration request
      DocumentSnapshot requestDoc = await _pendingDoctorRegistrationsCollection.doc(requestId).get();
      
      if (!requestDoc.exists) {
        throw Exception('Registration request not found');
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;
      
      if (requestData['status'] != 'pending') {
        throw Exception('Registration request has already been processed');
      }

      // Create DoctorRegistration object from request data
      final doctorRegistration = DoctorRegistration(
        id: '', // Will be set after document creation
        fullName: requestData['fullName'],
        email: requestData['email'],
        phoneNumber: requestData['phoneNumber'],
        specialization: requestData['specialization'],
        licenseNumber: requestData['licenseNumber'],
        hospital: requestData['hospital'],
        address: requestData['address'],
        experienceYears: requestData['experienceYears'],
        qualifications: requestData['qualifications'],
        availableDays: List<String>.from(requestData['availableDays']),
        startTime: requestData['startTime'],
        endTime: requestData['endTime'],
        consultationFee: requestData['consultationFee'].toDouble(),
        profileImageUrl: requestData['profileImageUrl'] ?? '',
        profileImage: requestData['profileImage'],
        isVerified: true, // Automatically verified when approved by admin
        registrationDate: DateTime.now(), // Set current date as registration date
      );

      // Add to doctors collection
      print('Adding doctor to doctors collection...');
      DocumentReference doctorRef = await _doctorsCollection.add(doctorRegistration.toMap());
      
      // Update the document with its own ID
      await doctorRef.update({'id': doctorRef.id});
      print('Doctor added with ID: ${doctorRef.id}');

      // IMPORTANT: Create time slots for the approved doctor in 12-hour format
      print('Creating time slots (12-hour format) for approved doctor...');
      final timeSlotsCreated = await _createTimeSlotsForDoctor(doctorRef.id, requestData);
      
      if (!timeSlotsCreated) {
        print('Warning: Time slots creation failed, but doctor was approved');
        // You can decide whether to fail the approval or continue
        // For now, we'll continue with approval even if time slots fail
      }

      // Update the pending request status
      print('Updating pending request status...');
      await _pendingDoctorRegistrationsCollection.doc(requestId).update({
        'status': 'approved',
        'reviewDate': DateTime.now().toIso8601String(),
        'reviewedBy': adminId,
        'approvedDoctorId': doctorRef.id,
        'timeSlotsCreated': timeSlotsCreated,
      });

      print('Doctor registration approved successfully with time slots (12-hour format): $timeSlotsCreated');
      return true;
    } catch (e) {
      print('Error approving doctor registration: $e');
      return false;
    }
  }

  // NEW METHOD: Reject doctor registration (admin function)
  Future<bool> rejectDoctorRegistration(String requestId, String adminId, String rejectionReason) async {
    try {
      // Get the pending registration request
      DocumentSnapshot requestDoc = await _pendingDoctorRegistrationsCollection.doc(requestId).get();
      
      if (!requestDoc.exists) {
        throw Exception('Registration request not found');
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;
      
      if (requestData['status'] != 'pending') {
        throw Exception('Registration request has already been processed');
      }

      // Update the pending request status
      await _pendingDoctorRegistrationsCollection.doc(requestId).update({
        'status': 'rejected',
        'reviewDate': DateTime.now().toIso8601String(),
        'reviewedBy': adminId,
        'rejectionReason': rejectionReason,
      });

      return true;
    } catch (e) {
      print('Error rejecting doctor registration: $e');
      return false;
    }
  }

  // FIXED METHOD: Get registration requests by status (without composite index requirement)
  Future<List<Map<String, dynamic>>> getRegistrationRequestsByStatus(String status) async {
    try {
      print('Fetching requests with status: $status'); // Debug print
      
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: status)
          .get(); // Removed orderBy to avoid composite index requirement
      
      print('Found ${querySnapshot.docs.length} documents for status: $status'); // Debug print
      
      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        print('Document ID: ${doc.id}, Data keys: ${data.keys.toList()}'); // Debug print
        return data;
      }).toList();
      
      // Sort in memory by submission date (newest first)
      results.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['submissionDate'] ?? '');
          final bDate = DateTime.parse(b['submissionDate'] ?? '');
          return bDate.compareTo(aDate); // Descending order (newest first)
        } catch (e) {
          print('Error parsing dates for sorting: $e');
          return 0; // If date parsing fails, maintain current order
        }
      });
      
      print('Returning ${results.length} results after sorting'); // Debug print
      return results;
    } catch (e) {
      print('Detailed error in getRegistrationRequestsByStatus: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('index')) {
        print('This is a Firestore composite index error. The query has been modified to avoid this issue.');
      }
      return [];
    }
  }

  // NEW METHOD: Get registration request by user email
  Future<Map<String, dynamic>?> getRegistrationRequestByEmail(String email) async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('email', isEqualTo: email)
          .get(); // Removed orderBy to avoid composite index requirement
      
      if (querySnapshot.docs.isNotEmpty) {
        // Sort in memory and get the most recent
        List<QueryDocumentSnapshot> docs = querySnapshot.docs.toList();
        docs.sort((a, b) {
          try {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = DateTime.parse(aData['submissionDate'] ?? '');
            final bDate = DateTime.parse(bData['submissionDate'] ?? '');
            return bDate.compareTo(aDate); // Descending order (newest first)
          } catch (e) {
            return 0;
          }
        });
        
        Map<String, dynamic> data = docs.first.data() as Map<String, dynamic>;
        data['requestId'] = docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting registration request by email: $e');
      return null;
    }
  }

  // UPDATED: Get doctor time slots from subcollection
  Future<List<Map<String, dynamic>>> getDoctorTimeSlots(String doctorId, {String? date}) async {
    try {
      Query query = _doctorsCollection
          .doc(doctorId)
          .collection('time_slots');
      
      if (date != null) {
        query = query.where('date', isEqualTo: date);
      }
      
      QuerySnapshot querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['slotId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting doctor time slots: $e');
      return [];
    }
  }

  // UPDATED: Book a time slot in doctor's subcollection
  Future<bool> bookTimeSlot(String doctorId, String slotId, String patientId, String bookingId) async {
    try {
      await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .doc(slotId)
          .update({
        'isAvailable': false,
        'isBooked': true,
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

  // UPDATED: Cancel a time slot booking in doctor's subcollection
  Future<bool> cancelTimeSlotBooking(String doctorId, String slotId) async {
    try {
      await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .doc(slotId)
          .update({
        'isAvailable': true,
        'isBooked': false,
        'bookedBy': null,
        'bookingId': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error canceling time slot booking: $e');
      return false;
    }
  }
  // NEW: Get available time slots for a specific doctor and date
  Future<List<String>> getAvailableTimeSlots(String doctorId, String date) async {
    try {
      final querySnapshot = await _doctorsCollection
          .doc(doctorId)
          .collection('time_slots')
          .where('date', isEqualTo: date)
          .where('isAvailable', isEqualTo: true)
          .where('isBooked', isEqualTo: false)
          .get();

      List<String> availableSlots = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        String timeSlot = data['time'] ?? '';
        if (timeSlot.isNotEmpty) {
          availableSlots.add(timeSlot);
        }
      }

      // Sort the time slots chronologically
      availableSlots.sort((a, b) => _compareTimeSlots12Hour(a, b));
      
      return availableSlots;
    } catch (e) {
      print('Error getting available time slots: $e');
      return [];
    }
  }

  // Helper method to compare 12-hour format time slots for sorting
  int _compareTimeSlots12Hour(String timeA, String timeB) {
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
  // Register a new doctor (DEPRECATED - Use submitDoctorRegistrationRequest instead)
  @Deprecated('Use submitDoctorRegistrationRequest for admin approval workflow')
  Future<String?> registerDoctor(DoctorRegistration doctor) async {
    try {
      // Check if doctor with same email already exists
      final existingDoctor = await _doctorsCollection
          .where('email', isEqualTo: doctor.email)
          .get();
      
      if (existingDoctor.docs.isNotEmpty) {
        throw Exception('Doctor with this email already exists');
      }

      // Check if license number already exists
      final existingLicense = await _doctorsCollection
          .where('licenseNumber', isEqualTo: doctor.licenseNumber)
          .get();
      
      if (existingLicense.docs.isNotEmpty) {
        throw Exception('Doctor with this license number already exists');
      }

      // Add doctor to Firestore
      DocumentReference docRef = await _doctorsCollection.add(doctor.toMap());
      
      // Update the document with its own ID
      await docRef.update({'id': docRef.id});
      
      return docRef.id;
    } catch (e) {
      print('Error registering doctor: $e');
      rethrow;
    }
  }

  // Get doctor by ID (only approved doctors)
  Future<DoctorRegistration?> getDoctorById(String doctorId) async {
    try {
      DocumentSnapshot doc = await _doctorsCollection.doc(doctorId).get();
      if (doc.exists) {
        return DoctorRegistration.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting doctor: $e');
      return null;
    }
  }

  // Get doctor by email (only approved doctors)
  Future<DoctorRegistration?> getDoctorByEmail(String email) async {
    try {
      QuerySnapshot querySnapshot = await _doctorsCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return DoctorRegistration.fromMap(
          querySnapshot.docs.first.data() as Map<String, dynamic>
        );
      }
      return null;
    } catch (e) {
      print('Error getting doctor by email: $e');
      return null;
    }
  }

  // Get all approved doctors
  Future<List<DoctorRegistration>> getAllDoctors() async {
    try {
      QuerySnapshot querySnapshot = await _doctorsCollection.get();
      return querySnapshot.docs.map((doc) => 
        DoctorRegistration.fromMap(doc.data() as Map<String, dynamic>)
      ).toList();
    } catch (e) {
      print('Error getting all doctors: $e');
      return [];
    }
  }

  // Get doctors by specialization (only approved doctors)
  Future<List<DoctorRegistration>> getDoctorsBySpecialization(String specialization) async {
    try {
      QuerySnapshot querySnapshot = await _doctorsCollection
          .where('specialization', isEqualTo: specialization)
          .get();
      return querySnapshot.docs.map((doc) => 
        DoctorRegistration.fromMap(doc.data() as Map<String, dynamic>)
      ).toList();
    } catch (e) {
      print('Error getting doctors by specialization: $e');
      return [];
    }
  }

  // Get verified doctors only (already approved, but double-check verification)
  Future<List<DoctorRegistration>> getVerifiedDoctors() async {
    try {
      QuerySnapshot querySnapshot = await _doctorsCollection
          .where('isVerified', isEqualTo: true)
          .get();
      return querySnapshot.docs.map((doc) => 
        DoctorRegistration.fromMap(doc.data() as Map<String, dynamic>)
      ).toList();
    } catch (e) {
      print('Error getting verified doctors: $e');
      return [];
    }
  }

  // Update doctor information
  Future<bool> updateDoctor(String doctorId, Map<String, dynamic> updates) async {
    try {
      await _doctorsCollection.doc(doctorId).update(updates);
      return true;
    } catch (e) {
      print('Error updating doctor: $e');
      return false;
    }
  }

  // Verify doctor (admin function) - for additional verification beyond approval
  Future<bool> verifyDoctor(String doctorId) async {
    try {
      await _doctorsCollection.doc(doctorId).update({'isVerified': true});
      return true;
    } catch (e) {
      print('Error verifying doctor: $e');
      return false;
    }
  }

  // Delete doctor
  Future<bool> deleteDoctor(String doctorId) async {
    try {
      await _doctorsCollection.doc(doctorId).delete();
      return true;
    } catch (e) {
      print('Error deleting doctor: $e');
      return false;
    }
  }

  // Get pending doctors (UPDATED - now refers to pending registration requests)
  Future<List<Map<String, dynamic>>> getPendingDoctors() async {
    return getPendingRegistrationRequests();
  }

  // Search doctors by name or specialization (only approved doctors)
  Future<List<DoctorRegistration>> searchDoctors(String searchTerm) async {
    try {
      // Convert search term to lowercase for case-insensitive search
      String lowerSearchTerm = searchTerm.toLowerCase();
      
      // Get all doctors and filter in memory (since Firestore has limited query capabilities)
      QuerySnapshot querySnapshot = await _doctorsCollection.get();
      
      List<DoctorRegistration> allDoctors = querySnapshot.docs.map((doc) => 
        DoctorRegistration.fromMap(doc.data() as Map<String, dynamic>)
      ).toList();

      // Filter doctors based on name or specialization
      List<DoctorRegistration> filteredDoctors = allDoctors.where((doctor) {
        return doctor.fullName.toLowerCase().contains(lowerSearchTerm) ||
               doctor.specialization.toLowerCase().contains(lowerSearchTerm);
      }).toList();

      return filteredDoctors;
    } catch (e) {
      print('Error searching doctors: $e');
      return [];
    }
  }

  // NEW METHOD: Delete registration request (admin function)
  Future<bool> deleteRegistrationRequest(String requestId) async {
    try {
      await _pendingDoctorRegistrationsCollection.doc(requestId).delete();
      return true;
    } catch (e) {
      print('Error deleting registration request: $e');
      return false;
    }
  }

  // FIXED METHOD: Get registration statistics (for admin dashboard)
  Future<Map<String, int>> getRegistrationStatistics() async {
    try {
      print('Fetching registration statistics...'); // Debug print

      final pendingSnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'pending')
          .get();
      print('Pending count: ${pendingSnapshot.docs.length}'); // Debug print
      
      final approvedSnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'approved')
          .get();
      print('Approved count: ${approvedSnapshot.docs.length}'); // Debug print
      
      final rejectedSnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'rejected')
          .get();
      print('Rejected count: ${rejectedSnapshot.docs.length}'); // Debug print

      final totalDoctorsSnapshot = await _doctorsCollection.get();
      print('Total active doctors: ${totalDoctorsSnapshot.docs.length}'); // Debug print

      final stats = {
        'pending': pendingSnapshot.docs.length,
        'approved': approvedSnapshot.docs.length,
        'rejected': rejectedSnapshot.docs.length,
        'totalActiveDoctors': totalDoctorsSnapshot.docs.length,
      };

      print('Final statistics: $stats'); // Debug print
      return stats;
    } catch (e) {
      print('Error getting registration statistics: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'totalActiveDoctors': 0,
      };
    }
  }
}