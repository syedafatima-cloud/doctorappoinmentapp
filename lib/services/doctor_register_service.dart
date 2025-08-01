// services/doctor_registration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_register_model.dart';

class DoctorRegistrationService {
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');
  
  // NEW: Collection for pending doctor registrations (admin approval system)
  final CollectionReference _pendingDoctorRegistrationsCollection = 
      FirebaseFirestore.instance.collection('pending_doctor_registrations');
// Get registration requests by status
// (Duplicate method removed to resolve naming conflict)
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
          .orderBy('submissionDate', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        return data;
      }).toList();
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

  // NEW METHOD: Approve doctor registration (admin function)
  Future<bool> approveDoctorRegistration(String requestId, String adminId) async {
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
      DocumentReference doctorRef = await _doctorsCollection.add(doctorRegistration.toMap());
      
      // Update the document with its own ID
      await doctorRef.update({'id': doctorRef.id});

      // Update the pending request status
      await _pendingDoctorRegistrationsCollection.doc(requestId).update({
        'status': 'approved',
        'reviewDate': DateTime.now().toIso8601String(),
        'reviewedBy': adminId,
        'approvedDoctorId': doctorRef.id,
      });

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

  // NEW METHOD: Get registration requests by status
  Future<List<Map<String, dynamic>>> getRegistrationRequestsByStatus(String status) async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: status)
          .orderBy('submissionDate', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting registration requests by status: $e');
      return [];
    }
  }

  // NEW METHOD: Get registration request by user email
  Future<Map<String, dynamic>?> getRegistrationRequestByEmail(String email) async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('email', isEqualTo: email)
          .orderBy('submissionDate', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        Map<String, dynamic> data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        data['requestId'] = querySnapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting registration request by email: $e');
      return null;
    }
  }

  // EXISTING METHODS (Updated to work with approved doctors only)

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

  // NEW METHOD: Get registration statistics (for admin dashboard)
  Future<Map<String, int>> getRegistrationStatistics() async {
    try {
      final pendingSnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'pending')
          .get();
      
      final approvedSnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'approved')
          .get();
      
      final rejectedSnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'rejected')
          .get();

      final totalDoctorsSnapshot = await _doctorsCollection.get();

      return {
        'pending': pendingSnapshot.docs.length,
        'approved': approvedSnapshot.docs.length,
        'rejected': rejectedSnapshot.docs.length,
        'totalActiveDoctors': totalDoctorsSnapshot.docs.length,
      };
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