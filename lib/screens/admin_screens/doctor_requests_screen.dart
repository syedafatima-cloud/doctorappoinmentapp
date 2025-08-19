// screens/admin_doctor_requests_screen.dart
import 'package:doctorappoinmentapp/services/doctor_register_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AdminDoctorRequestsScreen extends StatefulWidget {
  final String adminId; // Pass admin ID when navigating to this screen
  
  const AdminDoctorRequestsScreen({super.key, required this.adminId});

  @override
  State<AdminDoctorRequestsScreen> createState() => _AdminDoctorRequestsScreenState();
}

class _AdminDoctorRequestsScreenState extends State<AdminDoctorRequestsScreen> with SingleTickerProviderStateMixin {
  final DoctorRegistrationService _doctorService = DoctorRegistrationService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _approvedRequests = [];
  List<Map<String, dynamic>> _rejectedRequests = [];
  Map<String, int> _statistics = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Starting to load data...'); // Debug print
      
      // Test each service call individually
      print('📞 Calling getRegistrationRequestsByStatus for pending...');
      final pendingFuture = _doctorService.getRegistrationRequestsByStatus('pending');
      
      print('📞 Calling getRegistrationRequestsByStatus for approved...');
      final approvedFuture = _doctorService.getRegistrationRequestsByStatus('approved');
      
      print('📞 Calling getRegistrationRequestsByStatus for rejected...');
      final rejectedFuture = _doctorService.getRegistrationRequestsByStatus('rejected');
      
      print('📞 Calling getRegistrationStatistics...');
      final statsFuture = _doctorService.getRegistrationStatistics();
      
      final futures = await Future.wait([
        pendingFuture,
        approvedFuture,
        rejectedFuture,
        statsFuture,
      ]);
      
      print('✅ All futures completed'); // Debug print
      print('📊 Raw futures data:');
      print('  - Pending raw: ${futures[0]}');
      print('  - Approved raw: ${futures[1]}');
      print('  - Rejected raw: ${futures[2]}');
      print('  - Stats raw: ${futures[3]}');
      
      // Safe null checking for lengths
      final pendingList = futures[0] as List<Map<String, dynamic>>? ?? [];
      final approvedList = futures[1] as List<Map<String, dynamic>>? ?? [];
      final rejectedList = futures[2] as List<Map<String, dynamic>>? ?? [];
      final stats = futures[3] as Map<String, int>? ?? {};
      
      print('📈 Processed data:');
      print('  - Pending: ${pendingList.length} items');
      print('  - Approved: ${approvedList.length} items');
      print('  - Rejected: ${rejectedList.length} items');
      print('  - Stats: $stats');
      
      // Print first pending request if available
      if (pendingList.isNotEmpty) {
        print('📋 First pending request sample: ${pendingList[0]}');
      }
      
      setState(() {
        _pendingRequests = pendingList;
        _approvedRequests = approvedList;
        _rejectedRequests = rejectedList;
        _statistics = stats;
        _isLoading = false;
      });
      
      print('🎯 State updated successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _loadData: $e');
      print('📍 Stack trace: $stackTrace');
      setState(() {
        _pendingRequests = [];
        _approvedRequests = [];
        _rejectedRequests = [];
        _statistics = {};
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fixed approval method that creates Firebase account with doctor's original password
  Future<void> _approveRequest(String requestId, Map<String, dynamic> requestData) async {
    try {
      // Get the full request document with password hash
      final fullRequestDoc = await FirebaseFirestore.instance
          .collection('pending_doctor_registrations')
          .doc(requestId)
          .get();
      
      if (!fullRequestDoc.exists) {
        throw Exception('Registration request not found');
      }
      
      final fullRequestData = fullRequestDoc.data() as Map<String, dynamic>;
      
      // Check if we have the original password (for backward compatibility)
      String? originalPassword = fullRequestData['originalPassword']; // If stored temporarily
      final email = requestData['email'];
      
      if (email == null) {
        throw Exception('Doctor email not found in request data');
      }
      
      print('🔐 Creating Firebase Auth account for doctor: $email');
      
      // If we don't have the original password, we need to use a different approach
      if (originalPassword == null || originalPassword.isEmpty) {
        print('⚠️ No original password found, using password reset flow');
        await _approveWithPasswordReset(requestId, requestData, email);
        return;
      }
      
      try {
        // Create Firebase Auth account with the doctor's original password
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: originalPassword,
        );
        
        print('✅ Firebase Auth account created with UID: ${userCredential.user!.uid}');
        
        // Update the user's display name
        await userCredential.user!.updateDisplayName('Dr. ${requestData['fullName']}');
        
        // Now approve the doctor registration in the database
        final success = await _doctorService.approveDoctorRegistration(requestId, widget.adminId);
        
        if (success) {
          // Remove the original password from storage for security
          await FirebaseFirestore.instance
              .collection('pending_doctor_registrations')
              .doc(requestId)
              .update({'originalPassword': FieldValue.delete()});
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Doctor ${requestData['fullName']} approved! They can now login with their credentials.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
            _loadData(); // Refresh data
          }
        } else {
          // If approval failed, delete the created Firebase account
          await userCredential.user!.delete();
          throw Exception('Failed to approve doctor registration');
        }
        
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account already exists, just approve the registration
          final success = await _doctorService.approveDoctorRegistration(requestId, widget.adminId);
          
          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Doctor ${requestData['fullName']} approved! Account already exists.'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
              _loadData(); // Refresh data
            }
          } else {
            throw Exception('Failed to approve doctor registration');
          }
        } else if (e.code == 'weak-password') {
          throw Exception('Doctor\'s password is too weak for Firebase Auth');
        } else if (e.code == 'invalid-email') {
          throw Exception('Invalid email format');
        } else {
          throw Exception('Firebase Auth error: ${e.message}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving doctor: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Helper method for password reset flow when original password is not available
  Future<void> _approveWithPasswordReset(String requestId, Map<String, dynamic> requestData, String email) async {
    try {
      // Generate a secure temporary password
      final tempPassword = _generateSecurePassword();
      
      // Create Firebase Auth account with temporary password
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );
      
      print('✅ Firebase Auth account created with temp password. UID: ${userCredential.user!.uid}');
      
      // Update the user's display name
      await userCredential.user!.updateDisplayName('Dr. ${requestData['fullName']}');
      
      // Approve the doctor registration
      final success = await _doctorService.approveDoctorRegistration(requestId, widget.adminId);
      
      if (success) {
        // Send password reset email so doctor can set their own password
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Doctor ${requestData['fullName']} approved! Password reset email sent - they need to reset their password to login.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // If approval failed, delete the created Firebase account
        await userCredential.user!.delete();
        throw Exception('Failed to approve doctor registration');
      }
    } catch (e) {
      print('Error in password reset flow: $e');
      rethrow;
    }
  }

  String _generateActivationToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (Random().nextInt(999999)).toString();
  }

  Future<void> _storeActivationToken(String token, Map<String, dynamic> doctorData) async {
    try {
      await FirebaseFirestore.instance
          .collection('activation_tokens')
          .doc(token)
          .set({
            'email': doctorData['email'],
            'fullName': doctorData['fullName'],
            'requestId': doctorData['requestId'],
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'used': false,
          });
    } catch (e) {
      print('Error storing activation token: $e');
      throw Exception('Failed to generate activation token');
    }
  }

  Future<void> _sendDoctorActivationEmail(Map<String, dynamic> doctorData, String token) async {
    try {
      final activationLink = 'https://yourapp.com/activate-doctor?token=$token';
      
      // In a real app, you would integrate with an email service like SendGrid, Mailgun, etc.
      // For now, we'll just log the email content
      print('📧 Sending activation email to: ${doctorData['email']}');
      print('📧 Activation link: $activationLink');
      
      // Email content
      final emailContent = '''
      Dear Dr. ${doctorData['fullName']},
      
      Congratulations! Your doctor registration has been approved.
      
      To complete your account setup and start using the platform, please click the link below:
      
      $activationLink
      
      This link will expire in 7 days. Once activated, you can login using your registered email and password.
      
      If you have any questions, please contact our support team.
      
      Welcome to our medical platform!
      
      Best regards,
      Medical App Team
      ''';
      
      // TODO: Replace with actual email service integration
      // await emailService.send(
      //   to: doctorData['email'],
      //   subject: 'Activate Your Doctor Account - Registration Approved',
      //   body: emailContent,
      // );
      
      print('📧 Email content:\n$emailContent');
      
    } catch (e) {
      print('Error sending activation email: $e');
      throw Exception('Failed to send activation email');
    }
  }

  // Option 2: Create Firebase account with system-generated password and send reset email
  Future<void> _approveRequestWithPasswordReset(String requestId, Map<String, dynamic> requestData) async {
    try {
      final email = requestData['email'];
      
      if (email == null) {
        throw Exception('Doctor email not found in request data');
      }
      
      print('🔐 Creating Firebase Auth account for doctor: $email');
      
      // Generate a secure temporary password
      final tempPassword = _generateSecurePassword();
      
      try {
        // Create Firebase Auth account with temporary password
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
        
        print('✅ Firebase Auth account created with UID: ${userCredential.user!.uid}');
        
        // Update the user's display name
        await userCredential.user!.updateDisplayName('Dr. ${requestData['fullName']}');
        
        // Approve the doctor registration
        final success = await _doctorService.approveDoctorRegistration(requestId, widget.adminId);
        
        if (success) {
          // Send password reset email so doctor can set their own password
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          
          // Send welcome email with instructions
          await _sendWelcomeEmailWithPasswordReset(requestData);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Doctor ${requestData['fullName']} approved! Welcome email sent with password setup instructions.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
            _loadData(); // Refresh data
          }
        } else {
          // If approval failed, delete the created Firebase account
          await userCredential.user!.delete();
          throw Exception('Failed to approve doctor registration');
        }
        
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account already exists, just approve and send reset email
          final success = await _doctorService.approveDoctorRegistration(requestId, widget.adminId);
          
          if (success) {
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            await _sendWelcomeEmailWithPasswordReset(requestData);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Doctor ${requestData['fullName']} approved! Password reset email sent.'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
              _loadData(); // Refresh data
            }
          } else {
            throw Exception('Failed to approve doctor registration');
          }
        } else {
          throw Exception('Firebase Auth error: ${e.message}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving doctor: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _generateSecurePassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _sendWelcomeEmailWithPasswordReset(Map<String, dynamic> doctorData) async {
    try {
      final emailContent = '''
      Dear Dr. ${doctorData['fullName']},
      
      Congratulations! Your doctor registration has been approved and your account has been created.
      
      To access your account:
      1. Download our app from the App Store or Google Play
      2. Click "Forgot Password" on the login screen
      3. Enter your email: ${doctorData['email']}
      4. Check your email for password reset instructions
      5. Set your new password and login
      
      Your account details:
      - Email: ${doctorData['email']}
      - Specialization: ${doctorData['specialization']}
      - Hospital: ${doctorData['hospital']}
      
      Welcome to our medical platform! We're excited to have you on board.
      
      If you need any assistance, please contact our support team.
      
      Best regards,
      Medical App Team
      ''';
      
      print('📧 Sending welcome email to: ${doctorData['email']}');
      print('📧 Email content:\n$emailContent');
      
      // TODO: Replace with actual email service integration
      // await emailService.send(
      //   to: doctorData['email'],
      //   subject: 'Welcome! Your Doctor Account is Ready',
      //   body: emailContent,
      // );
      
    } catch (e) {
      print('Error sending welcome email: $e');
    }
  }

  Future<void> _rejectRequest(String requestId, Map<String, dynamic> requestData) async {
    final rejectionReason = await _showRejectionDialog();
    
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      try {
        final success = await _doctorService.rejectDoctorRegistration(requestId, widget.adminId, rejectionReason);
        
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Doctor ${requestData['fullName']} registration rejected'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
            _loadData(); // Refresh data
          }
        } else {
          throw Exception('Failed to reject doctor registration');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting doctor: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<String?> _showRejectionDialog() async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.cancel, color: Theme.of(context).colorScheme.error, size: 20),
              const SizedBox(width: 8),
              const Text('Reject Registration', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting this doctor registration:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Enter rejection reason...',
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Reject', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void _showDoctorDetails(Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          requestData['fullName'] ?? 'Doctor Details',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Image
                        if (requestData['profileImageUrl'] != null && requestData['profileImageUrl'].isNotEmpty)
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(requestData['profileImageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        
                        _buildDetailRow('Full Name', requestData['fullName'] ?? 'N/A'),
                        _buildDetailRow('Email', requestData['email'] ?? 'N/A'),
                        _buildDetailRow('Phone', requestData['phoneNumber'] ?? 'N/A'),
                        _buildDetailRow('Specialization', requestData['specialization'] ?? 'N/A'),
                        _buildDetailRow('License Number', requestData['licenseNumber'] ?? 'N/A'),
                        _buildDetailRow('Hospital/Clinic', requestData['hospital'] ?? 'N/A'),
                        _buildDetailRow('Experience', '${requestData['experienceYears'] ?? 0} years'),
                        _buildDetailRow('Consultation Fee', '\$${requestData['consultationFee'] ?? 0}'),
                        _buildDetailRow('Available Days', (requestData['availableDays'] as List<dynamic>?)?.cast<String>().join(', ') ?? 'N/A'),
                        _buildDetailRow('Working Hours', '${requestData['startTime'] ?? 'N/A'} - ${requestData['endTime'] ?? 'N/A'}'),
                        _buildDetailRow('Address', requestData['address'] ?? 'N/A'),
                        _buildDetailRow('Qualifications', requestData['qualifications'] ?? 'N/A', isMultiLine: true),
                        _buildDetailRow('Submission Date', _formatDate(requestData['submissionDate'])),
                        
                        // Status-specific information
                        if (requestData['status'] == 'approved') ...[
                          const Divider(height: 20),
                          _buildDetailRow('Approved Date', _formatDate(requestData['reviewDate'])),
                          _buildDetailRow('Approved By', requestData['reviewedBy'] ?? 'N/A'),
                          if (requestData['firebaseUid'] != null)
                            _buildDetailRow('Firebase UID', requestData['firebaseUid']),
                        ],
                        if (requestData['status'] == 'rejected') ...[
                          const Divider(height: 20),
                          _buildDetailRow('Rejected Date', _formatDate(requestData['reviewDate'])),
                          _buildDetailRow('Rejected By', requestData['reviewedBy'] ?? 'N/A'),
                          _buildDetailRow('Rejection Reason', requestData['rejectionReason'] ?? 'N/A', isMultiLine: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
            maxLines: isMultiLine ? null : 1,
            overflow: isMultiLine ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registration Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Pending', _statistics['pending'] ?? 0, Colors.orange),
                _buildStatItem('Approved', _statistics['approved'] ?? 0, Colors.green),
                _buildStatItem('Rejected', _statistics['rejected'] ?? 0, Colors.red),
                _buildStatItem('Active', _statistics['totalActiveDoctors'] ?? 0, Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRequestsList(List<Map<String, dynamic>> requests, String status) {
    print('🏗️ Building requests list for $status with ${requests.length} items'); // Debug print
    
    // Additional null safety check
    final safeRequests = requests ?? [];
    
    print('🔍 Safe requests length: ${safeRequests.length}');
    print('🔍 Safe requests content: $safeRequests');
    
    if (safeRequests.isEmpty) {
      print('📭 No requests found for $status - showing empty state');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending' ? Icons.hourglass_empty :
              status == 'approved' ? Icons.check_circle :
              Icons.cancel,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No $status requests found',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                print('🔄 Manual refresh button pressed');
                _loadData();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    print('📋 Building ListView with ${safeRequests.length} items');
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: safeRequests.length,
        itemBuilder: (context, index) {
          print('🏗️ Building card for index $index');
          final request = safeRequests[index];
          print('📄 Request data: $request');
          return _buildRequestCard(request, status);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile Image
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    image: request['profileImageUrl'] != null && request['profileImageUrl'].isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(request['profileImageUrl']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: request['profileImageUrl'] == null || request['profileImageUrl'].isEmpty
                      ? Icon(Icons.person, size: 24, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['fullName'] ?? 'Unknown Doctor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request['specialization'] ?? 'Unknown Specialization',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        request['hospital'] ?? 'Unknown Hospital',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'pending' ? Colors.orange :
                           status == 'approved' ? Colors.green :
                           Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request['email'] ?? 'N/A',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  _formatDate(request['submissionDate']),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDoctorDetails(request),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
                if (status == 'pending') ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(request['requestId'], request),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectRequest(request['requestId'], request),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Requests', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontSize: 11),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_empty, size: 14),
                  const SizedBox(width: 2),
                  Text('Pending (${_statistics['pending'] ?? 0})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14),
                  const SizedBox(width: 2),
                  Text('Approved (${_statistics['approved'] ?? 0})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel, size: 14),
                  const SizedBox(width: 2),
                  Text('Rejected (${_statistics['rejected'] ?? 0})'),
                ],
              ),
            ),
          ],
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Column(
              children: [
                _buildStatisticsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestsList(_pendingRequests, 'pending'),
                      _buildRequestsList(_approvedRequests, 'approved'),
                      _buildRequestsList(_rejectedRequests, 'rejected'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}