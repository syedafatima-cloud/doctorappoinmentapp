// doctor_registration_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/doctor_register_model.dart';
import '../services/auth_service.dart';
import '../services/audit_log_service.dart';
import '../services/email_service.dart';
import '../services/time_slot_service.dart';
import '../config/app_config.dart';

class DoctorRegistrationService {
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('doctors');
  
  final CollectionReference _pendingDoctorRegistrationsCollection = 
      FirebaseFirestore.instance.collection('pending_doctor_registrations');

  // Security: Hash password function
  String _hashPassword(String password) {
    var bytes = utf8.encode('${password}medical_app_salt');
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Security: Validate password strength
  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  // Security: Sanitize input data
  Map<String, dynamic> _sanitizeInput(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      if (entry.value is String) {
        sanitized[entry.key] = (entry.value as String)
            .replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false), '')
            .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
            .trim();
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }

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

  // Submit doctor registration for admin approval
  Future<String?> submitDoctorRegistrationRequest(Map<String, dynamic> doctorData) async {
    try {
      doctorData = _sanitizeInput(doctorData);
      
      String? password = doctorData['password'];
      
      if (password == null || password.isEmpty) {
        throw Exception('Password is required for doctor registration');
      }
      
      await _validateDoctorUniqueness(doctorData['email'], doctorData['licenseNumber']);

      doctorData['passwordHash'] = _hashPassword(password);
      doctorData['originalPassword'] = password; // Temporarily store for Firebase Auth
      doctorData.remove('password');

      doctorData['submissionDate'] = DateTime.now().toIso8601String();
      doctorData['status'] = 'pending';
      doctorData['reviewDate'] = null;
      doctorData['reviewedBy'] = null;
      doctorData['rejectionReason'] = null;
      doctorData['securityVersion'] = '1.0';

      DocumentReference docRef = await _pendingDoctorRegistrationsCollection.add(doctorData);
      await docRef.update({'requestId': docRef.id});
      
      await AuditLogService.logAdminAction(
        adminId: 'system',
        action: 'doctor_registration_submitted',
        targetType: 'doctor_request',
        targetId: docRef.id,
        details: {
          'email': doctorData['email'],
          'fullName': doctorData['fullName'],
        },
      );
      
      return docRef.id;
    } catch (e) {
      print('Error submitting doctor registration request: $e');
      rethrow;
    }
  }

  // Security: Verify stored password hash
  bool verifyPassword(String password, String storedHash) {
    return _hashPassword(password) == storedHash;
  }

  // Get all pending registration requests
  Future<List<Map<String, dynamic>>> getPendingRegistrationRequests() async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: 'pending')
          .get();
      
      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        data.remove('passwordHash');
        data.remove('originalPassword');
        return data;
      }).toList();

      results.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['submissionDate'] ?? '');
          final bDate = DateTime.parse(b['submissionDate'] ?? '');
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });

      return results;
    } catch (e) {
      print('Error getting pending registration requests: $e');
      return [];
    }
  }

  // Get registration request by ID
  Future<Map<String, dynamic>?> getRegistrationRequestById(String requestId) async {
    try {
      DocumentSnapshot doc = await _pendingDoctorRegistrationsCollection.doc(requestId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        data.remove('passwordHash');
        data.remove('originalPassword');
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting registration request: $e');
      return null;
    }
  }

  // Get registration statistics
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

  // Approve doctor registration
  Future<bool> approveDoctorRegistration(String requestId, String adminId) async {
    try {
      DocumentSnapshot requestDoc = await _pendingDoctorRegistrationsCollection.doc(requestId).get();
      
      if (!requestDoc.exists) {
        throw Exception('Registration request not found');
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;
      
      if (requestData['status'] != 'pending') {
        throw Exception('Registration request has already been processed');
      }

      final doctorRegistration = DoctorRegistration(
        id: '',
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
        isVerified: true,
        registrationDate: DateTime.now(),
      );

      DocumentReference doctorRef = await _doctorsCollection.add(doctorRegistration.toMap());
      await doctorRef.update({'id': doctorRef.id});

      // Create time slots using TimeSlotService
      final timeSlotService = TimeSlotService();
      final timeSlotsCreated = await timeSlotService.createTimeSlotsForDoctor(
        doctorRef.id, 
        requestData
      );

      await _pendingDoctorRegistrationsCollection.doc(requestId).update({
        'status': 'approved',
        'reviewDate': DateTime.now().toIso8601String(),
        'reviewedBy': adminId,
        'approvedDoctorId': doctorRef.id,
        'timeSlotsCreated': timeSlotsCreated,
      });

      await AuditLogService.logAdminAction(
        adminId: adminId,
        action: 'doctor_approved',
        targetType: 'doctor_request',
        targetId: requestId,
        details: {
          'doctorId': doctorRef.id,
          'email': requestData['email'],
          'fullName': requestData['fullName'],
        },
      );

      await EmailService.sendApprovalNotification(
        requestData['email'],
        requestData['fullName'],
      );

      return true;
    } catch (e) {
      print('Error approving doctor registration: $e');
      
      await AuditLogService.logAdminAction(
        adminId: adminId,
        action: 'doctor_approval_failed',
        targetType: 'doctor_request',
        targetId: requestId,
        details: {'error': e.toString()},
      );
      
      return false;
    }
  }

  // Reject doctor registration
  Future<bool> rejectDoctorRegistration(String requestId, String adminId, String rejectionReason) async {
    try {
      DocumentSnapshot requestDoc = await _pendingDoctorRegistrationsCollection.doc(requestId).get();
      
      if (!requestDoc.exists) {
        throw Exception('Registration request not found');
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;
      
      if (requestData['status'] != 'pending') {
        throw Exception('Registration request has already been processed');
      }

      await _pendingDoctorRegistrationsCollection.doc(requestId).update({
        'status': 'rejected',
        'reviewDate': DateTime.now().toIso8601String(),
        'reviewedBy': adminId,
        'rejectionReason': rejectionReason,
      });

      await AuditLogService.logAdminAction(
        adminId: adminId,
        action: 'doctor_rejected',
        targetType: 'doctor_request',
        targetId: requestId,
        details: {
          'email': requestData['email'],
          'fullName': requestData['fullName'],
          'rejectionReason': rejectionReason,
        },
      );

      await EmailService.sendRejectionNotification(
        requestData['email'],
        requestData['fullName'],
        rejectionReason,
      );

      return true;
    } catch (e) {
      print('Error rejecting doctor registration: $e');
      
      await AuditLogService.logAdminAction(
        adminId: adminId,
        action: 'doctor_rejection_failed',
        targetType: 'doctor_request',
        targetId: requestId,
        details: {'error': e.toString()},
      );
      
      return false;
    }
  }

  // Get registration requests by status
  Future<List<Map<String, dynamic>>> getRegistrationRequestsByStatus(String status) async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('status', isEqualTo: status)
          .get();
      
      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['requestId'] = doc.id;
        data.remove('passwordHash');
        data.remove('originalPassword');
        return data;
      }).toList();
      
      results.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['submissionDate'] ?? '');
          final bDate = DateTime.parse(b['submissionDate'] ?? '');
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });
      
      return results;
    } catch (e) {
      print('Error in getRegistrationRequestsByStatus: $e');
      return [];
    }
  }

  // Get registration request by user email
  Future<Map<String, dynamic>?> getRegistrationRequestByEmail(String email) async {
    try {
      QuerySnapshot querySnapshot = await _pendingDoctorRegistrationsCollection
          .where('email', isEqualTo: email)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        List<QueryDocumentSnapshot> docs = querySnapshot.docs.toList();
        docs.sort((a, b) {
          try {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = DateTime.parse(aData['submissionDate'] ?? '');
            final bDate = DateTime.parse(bData['submissionDate'] ?? '');
            return bDate.compareTo(aDate);
          } catch (e) {
            return 0;
          }
        });
        
        Map<String, dynamic> data = docs.first.data() as Map<String, dynamic>;
        data['requestId'] = docs.first.id;
        data.remove('passwordHash');
        data.remove('originalPassword');
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting registration request by email: $e');
      return null;
    }
  }

  // Find doctor by email across all statuses
  Future<Map<String, dynamic>?> findDoctorByEmail(String email) async {
    try {
      // First check approved doctors
      final approvedDoctors = await getRegistrationRequestsByStatus('approved');
      for (var doctor in approvedDoctors) {
        if (doctor['email'] == email) {
          return doctor;
        }
      }

      // Then check pending/rejected
      final pendingDoctors = await getRegistrationRequestsByStatus('pending');
      for (var doctor in pendingDoctors) {
        if (doctor['email'] == email) {
          return doctor;
        }
      }

      final rejectedDoctors = await getRegistrationRequestsByStatus('rejected');
      for (var doctor in rejectedDoctors) {
        if (doctor['email'] == email) {
          return doctor;
        }
      }

      return null;
    } catch (e) {
      print('Error finding doctor by email: $e');
      return null;
    }
  }

  // Get approved doctor by email specifically
  Future<Map<String, dynamic>?> getApprovedDoctorByEmail(String email) async {
    try {
      final approvedDoctors = await getRegistrationRequestsByStatus('approved');
      for (var doctor in approvedDoctors) {
        if (doctor['email'] == email) {
          return doctor;
        }
      }
      return null;
    } catch (e) {
      print('Error getting approved doctor by email: $e');
      return null;
    }
  }

  // Get doctor status by email
  Future<String?> getDoctorStatusByEmail(String email) async {
    try {
      final doctor = await findDoctorByEmail(email);
      return doctor?['status'];
    } catch (e) {
      print('Error getting doctor status by email: $e');
      return null;
    }
  }

  // Get all approved doctors
  Future<List<DoctorRegistration>> getAllApprovedDoctors() async {
    try {
      QuerySnapshot querySnapshot = await _doctorsCollection.get();
      return querySnapshot.docs.map((doc) => 
        DoctorRegistration.fromMap(doc.data() as Map<String, dynamic>)
      ).toList();
    } catch (e) {
      print('Error getting all approved doctors: $e');
      return [];
    }
  }

  // Get doctor by ID
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
}