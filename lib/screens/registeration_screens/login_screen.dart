import 'package:doctorappoinmentapp/screens/doctor_dashboard_screens/doctor_dashboard_screen.dart';
import 'package:doctorappoinmentapp/screens/registeration_screens/signup_screen.dart';
import 'package:doctorappoinmentapp/screens/homescreen.dart';
import 'package:doctorappoinmentapp/services/doctor_register_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define the admin credentials
const String adminEmail = "admin@example.com";
const String adminPassword = "admin123";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  // Updated gradients to match the new theme colors
  final List<List<Color>> _gradients = [
    [const Color(0xFFFAF8F5), const Color(0xFFC5CAE9)], // Soft Cream to Lavender Mist
    [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)], // Light Lavender to Dusty Lilac
    [const Color(0xFFC5CAE9), const Color(0xFF7E57C2)], // Lavender Mist to Muted Plum
  ];

  int _currentGradient = 0;
  int _nextGradient = 1;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DoctorRegistrationService _doctorService = DoctorRegistrationService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _currentGradient = _nextGradient;
            _nextGradient = (_nextGradient + 1) % _gradients.length;
          });
          _animationController.reset();
          _animationController.forward();
        }
      });
      
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isDoctorLoggedIn');
    await prefs.remove('isAdmin');
    await prefs.remove('isLoggedIn');
    await prefs.remove('doctorId');
    
    // Sign out from Firebase if needed
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  }
  Future<void> _debugUserData(String email) async {
  try {
    print('\n🔍 DEBUG: Analyzing user data for $email');
    
    // Check in Firebase Auth users collection
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    
    print('📊 Users collection results: ${userQuery.docs.length}');
    for (var doc in userQuery.docs) {
      final data = doc.data();
      print('  - User role: ${data['role']} | Email: ${data['email']}');
    }
    
    // Check in doctors collection
    final doctorsQuery = await FirebaseFirestore.instance
        .collection('doctors')
        .where('email', isEqualTo: email)
        .get();
    
    print('📊 Doctors collection results: ${doctorsQuery.docs.length}');
    for (var doc in doctorsQuery.docs) {
      final data = doc.data();
      print('  - Doctor: ${data['fullName']} | Email: ${data['email']} | Verified: ${data['isVerified']}');
    }
    
    // Check in pending registrations
    final pendingQuery = await FirebaseFirestore.instance
        .collection('pending_doctor_registrations')
        .where('email', isEqualTo: email)
        .get();
    
    print('📊 Pending registrations results: ${pendingQuery.docs.length}');
    for (var doc in pendingQuery.docs) {
      final data = doc.data();
      print('  - Status: ${data['status']} | Name: ${data['fullName']} | Email: ${data['email']}');
    }
    
    // Test the service method
    final serviceResult = await _doctorService.getApprovedDoctorByEmail(email);
    print('📊 Service method result: ${serviceResult != null ? 'FOUND' : 'NOT FOUND'}');
    
    print('🔍 DEBUG: Analysis complete\n');
    
  } catch (e) {
    print('❌ DEBUG: Error analyzing user data: $e');
  }
}
  Widget _buildInputField(String label,
      {bool isPassword = false, 
      TextEditingController? controller, 
      String? Function(String?)? validator,
      TextInputType keyboardType = TextInputType.text,
      Widget? prefixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w600,
            color: Color(0xFF424242), // Theme text color
          )
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? !_isPasswordVisible : false,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF424242), // Theme text color
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: prefixIcon != null 
                ? IconTheme(
                    data: const IconThemeData(color: Color(0xFF7E57C2)), // Theme accent color
                    child: prefixIcon,
                  )
                : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFF7E57C2), // Theme accent color
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 1.5), // Theme accent color
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _checkApprovedDoctor(String email) async {
  try {
    print('🔍 STEP 1: Checking for approved doctor with email: $email');
    
    // STEP 1: Check in the main doctors collection (active doctors only)
    final doctorsQuery = await FirebaseFirestore.instance
        .collection('doctors')
        .where('email', isEqualTo: email)
        .where('isVerified', isEqualTo: true) // Only verified doctors
        .get();
    
    print('📊 Active doctors found: ${doctorsQuery.docs.length}');
    
    if (doctorsQuery.docs.isNotEmpty) {
      final doc = doctorsQuery.docs.first;
      final doctorData = doc.data();
      
      // Validate that this doctor is actually active and not deleted
      if (doctorData['isActive'] != false && 
          doctorData['fullName'] != null && 
          doctorData['fullName'].toString().isNotEmpty) {
        
        doctorData['requestId'] = doc.id;
        print('✅ FOUND: Active verified doctor - ${doctorData['fullName']}');
        return doctorData;
      } else {
        print('⚠️ Doctor found but inactive or invalid: ${doctorData['fullName']}');
      }
    }
    
    // STEP 2: Check in pending registrations with approved status (fallback)
    print('🔍 STEP 2: Checking pending registrations...');
    final pendingQuery = await FirebaseFirestore.instance
        .collection('pending_doctor_registrations')
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: 'approved')
        .get();
    
    print('📊 Approved pending registrations: ${pendingQuery.docs.length}');
    
    if (pendingQuery.docs.isNotEmpty) {
      final doc = pendingQuery.docs.first;
      final doctorData = doc.data();
      
      // Check if this approved registration has a corresponding active doctor
      final correspondingDoctor = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorData['approvedDoctorId'])
          .get();
      
      if (correspondingDoctor.exists) {
        final activeData = correspondingDoctor.data()!;
        activeData['requestId'] = correspondingDoctor.id;
        print('✅ FOUND: Approved doctor via pending registration - ${activeData['fullName']}');
        return activeData;
      } else {
        print('⚠️ Approved registration found but no corresponding active doctor');
      }
    }
    
    print('❌ No valid approved doctor found for email: $email');
    return null;
    
  } catch (e) {
    print('❌ Error checking approved doctor: $e');
    return null;
  }
}

// Also add this method to debug what's in your collections:
Future<void> _debugAllDoctorData(String email) async {
  try {
    print('\n🔍 === DEBUGGING ALL DOCTOR DATA FOR $email ===');
    
    // Check doctors collection
    final doctors = await FirebaseFirestore.instance
        .collection('doctors')
        .get();
    
    print('📊 Total doctors in collection: ${doctors.docs.length}');
    for (var doc in doctors.docs) {
      final data = doc.data();
      if (data['email'] == email) {
        print('  🎯 MATCH - Doctor ID: ${doc.id}');
        print('     Name: ${data['fullName']}');
        print('     Email: ${data['email']}');
        print('     IsVerified: ${data['isVerified']}');
        print('     IsActive: ${data['isActive']}');
      }
    }
    
    // Check pending registrations
    final pending = await FirebaseFirestore.instance
        .collection('pending_doctor_registrations')
        .get();
    
    print('📊 Total pending registrations: ${pending.docs.length}');
    for (var doc in pending.docs) {
      final data = doc.data();
      if (data['email'] == email) {
        print('  🎯 MATCH - Request ID: ${doc.id}');
        print('     Name: ${data['fullName']}');
        print('     Email: ${data['email']}');
        print('     Status: ${data['status']}');
        print('     ApprovedDoctorId: ${data['approvedDoctorId']}');
      }
    }
    
    print('=== END DEBUGGING ===\n');
    
  } catch (e) {
    print('❌ Debug error: $e');
  }
}

  // Helper method to get all doctor registration requests for status checking
  Future<List<Map<String, dynamic>>> _getAllDoctorRequests() async {
    try {
      final pending = await _doctorService.getRegistrationRequestsByStatus('pending');
      final approved = await _doctorService.getRegistrationRequestsByStatus('approved');
      final rejected = await _doctorService.getRegistrationRequestsByStatus('rejected');
      
      return [...pending, ...approved, ...rejected];
    } catch (e) {
      print('Error getting all doctor requests: $e');
      return [];
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      await _debugUserData(email);
      await _debugAllDoctorData(email);
      final messenger = ScaffoldMessenger.of(context);

      try {
        // Check if it's admin login first
        if (email == adminEmail && password == adminPassword) {
          // Authenticate admin with Firebase Auth
          try {
            // Try to sign in with admin credentials
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword
            );
          } catch (e) {
            // If admin user doesn't exist yet, create it
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: adminEmail,
                password: adminPassword
              );
              
              // Set admin role in Firestore
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .set({
                    'role': 'admin',
                    'email': adminEmail,
                    'createdAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
            } catch (createError) {
              print('Error creating admin user: $createError');
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: adminEmail,
                password: adminPassword
              );
            }
          }
          
          // Store admin status in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAdmin', true);
          await prefs.setBool('isLoggedIn', true);
          
          // Make sure the role is set correctly in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .set({
                'role': 'admin',
              }, SetOptions(merge: true));
          
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text("Admin login successful!"),
                backgroundColor: Color(0xFF7E57C2),
              )
            );
            Navigator.pushReplacementNamed(context, '/admin');
          }
          return;
        }
        
        // Try Firebase Auth login first for all non-admin users
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, 
          password: password
        );
        
        // After successful Firebase Auth, check user role and type
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();

        final isAdmin = userDoc.exists && userDoc.data()?['role'] == 'admin';
        
        // Check if this user is an approved doctor
        final approvedDoctor = await _checkApprovedDoctor(email);
        final isApprovedDoctor = approvedDoctor != null;
        
        // DEBUG: Print what we found
        print('🔍 LOGIN DEBUG:');
        print('  Email: $email');
        print('  Is Admin: $isAdmin');
        print('  Is Approved Doctor: $isApprovedDoctor');
        print('  Doctor Data: $approvedDoctor');
        
        // Store login status in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        
        // CLEAR ALL PREVIOUS LOGIN DATA FIRST
        await prefs.remove('isDoctorLoggedIn');
        await prefs.remove('isAdmin');
        await prefs.remove('doctorId');
        
        // NOW SET THE CORRECT VALUES
        await prefs.setBool('isAdmin', isAdmin);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('isDoctorLoggedIn', isApprovedDoctor);
        
        if (isApprovedDoctor) {
          await prefs.setString('doctorId', approvedDoctor['requestId'] ?? '');
          print('  Stored Doctor ID: ${approvedDoctor['requestId']}');
        } else {
          await prefs.remove('doctorId');
          print('  Removed Doctor ID (patient user)');
        }

        print('🚀 NAVIGATION DECISION:');
        if (isAdmin) {
          print('  → Going to ADMIN dashboard');
        } else if (isApprovedDoctor) {
          print('  → Going to DOCTOR dashboard');
        } else {
          print('  → Going to PATIENT homepage');
        }

        if (mounted) {
          String welcomeMessage;
          if (isAdmin) {
            welcomeMessage = "Admin login successful!";
          } else if (isApprovedDoctor) {
            welcomeMessage = "Welcome back, Dr. ${approvedDoctor['fullName']}!";
          } else {
            welcomeMessage = "Login successful!";
          }
          
          messenger.showSnackBar(
            SnackBar(
              content: Text(welcomeMessage),
              backgroundColor: const Color(0xFF7E57C2),
            )
          );
          
          // Navigate to appropriate page based on user role
          if (isAdmin) {
            print('  → Navigating to ADMIN dashboard');
            Navigator.pushReplacementNamed(context, '/admin');
          } else if (isApprovedDoctor) {
            print('  → Navigating to DOCTOR dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DoctorDashboard(doctorId: approvedDoctor['requestId'] ?? ''),
              ),
            );
          } else {
            print('  → Navigating to PATIENT homepage');
            
            // Navigate directly to HomeScreen for regular patients
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
              (route) => false, // Remove all previous routes
            );
            
            // Show a confirmation snackbar
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Successfully logged in as PATIENT"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          }
        }

      } on FirebaseAuthException catch (e) {
        String errorMessage = "An error occurred. Please try again.";
        
        if (e.code == 'user-not-found') {
          // Check if this email belongs to a pending or rejected doctor
          final doctorRequests = await _getAllDoctorRequests();
          bool isDoctorEmail = false;
          String doctorStatus = '';
          
          for (var request in doctorRequests) {
            if (request['email'] == email) {
              isDoctorEmail = true;
              doctorStatus = request['status'] ?? 'unknown';
              break;
            }
          }
          
          if (isDoctorEmail) {
            if (doctorStatus == 'pending') {
              errorMessage = "Your doctor registration is pending admin approval. Please wait for approval.";
            } else if (doctorStatus == 'rejected') {
              errorMessage = "Your doctor registration was rejected. Please contact admin for more information.";
            } else if (doctorStatus == 'approved') {
              errorMessage = "Your doctor account is approved but not yet activated. Please contact admin.";
            } else {
              errorMessage = "Doctor account not activated. Please contact admin.";
            }
          } else {
            errorMessage = "No account found with this email. Please register first.";
          }
        } else if (e.code == 'wrong-password') {
          errorMessage = "Incorrect password";
        } else if (e.code == 'email-already-in-use') {
          errorMessage = "Email already in use";
        } else if (e.code == 'invalid-email') {
          errorMessage = "Invalid email address";
        } else if (e.code == 'too-many-requests') {
          errorMessage = "Too many attempts. Please try again later.";
        } else if (e.code == 'network-request-failed') {
          errorMessage = "Network error. Check your connection.";
        } else if (e.message != null) {
          errorMessage = e.message!;
        }
        
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            )
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red,
            )
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset link sent to your email"),
            backgroundColor: Color(0xFF7E57C2),
          )
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Failed to send reset email";
      
      if (e.code == 'user-not-found') {
        errorMessage = "No user found with this email";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address";
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  // Helper method to show demo credentials (updated to show dynamic info)
  void _showDemoCredentials() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF8F5),
        title: const Text(
          "Login Information",
          style: TextStyle(color: Color(0xFF424242)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Login with your registered credentials:",
              style: TextStyle(color: Color(0xFF424242)),
            ),
            const SizedBox(height: 16),
            _buildCredentialTile("👨‍💼 Admin Login", adminEmail, adminPassword),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "👨‍⚕️ Doctor Login",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Use your registered email and password.\nYour account must be approved by admin first.",
                    style: TextStyle(
                      color: Color(0xFF424242),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "👤 Patient Login",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Use your registered email and password.\nPatient accounts are activated immediately.",
                    style: TextStyle(
                      color: Color(0xFF424242),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: Color(0xFF7E57C2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialTile(String title, String email, String password) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Email: $email",
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 12,
            ),
          ),
          Text(
            "Password: $password",
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400 || size.height < 600;
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(_gradients[_currentGradient][0], _gradients[_nextGradient][0], _animation.value)!,
                  Color.lerp(_gradients[_currentGradient][1], _gradients[_nextGradient][1], _animation.value)!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Demo Credentials Button
                    Align(
                      alignment: Alignment.topRight,
                      child: TextButton.icon(
                        onPressed: _showDemoCredentials,
                        icon: const Icon(
                          Icons.info_outline,
                          color: Color(0xFF7E57C2),
                          size: 18,
                        ),
                        label: const Text(
                          "Login Info",
                          style: TextStyle(
                            color: Color(0xFF7E57C2),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Login Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                            color: const Color(0xFF7E57C2).withOpacity(0.15),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Login Title
                            const Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.normal,
                                color: Color(0xFF424242),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Sign in to continue",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Email Address
                            _buildInputField(
                              "Email Address",
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.email_outlined, size: 20),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Email is required";
                                }
                                if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                                  return "Enter a valid email";
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 14),
                            
                            // Password
                            _buildInputField(
                              "Password",
                              isPassword: true,
                              controller: _passwordController,
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Password is required";
                                }
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFFFAF8F5),
                                      title: const Text(
                                        "Reset Password",
                                        style: TextStyle(color: Color(0xFF424242)),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Enter your email to receive a password reset link",
                                            style: TextStyle(color: Colors.grey.shade600),
                                          ),
                                          const SizedBox(height: 16),
                                          TextFormField(
                                            initialValue: _emailController.text,
                                            keyboardType: TextInputType.emailAddress,
                                            decoration: InputDecoration(
                                              labelText: "Email",
                                              labelStyle: const TextStyle(color: Color(0xFF7E57C2)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFF7E57C2)),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              _emailController.text = value;
                                            },
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(
                                            "Cancel",
                                            style: TextStyle(color: Colors.grey.shade600),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            if (_emailController.text.isNotEmpty) {
                                              _resetPassword(_emailController.text.trim());
                                              Navigator.pop(context);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("Please enter your email"),
                                                  backgroundColor: Colors.red,
                                                )
                                              );
                                            }
                                          },
                                          child: const Text(
                                            "Send",
                                            style: TextStyle(color: Color(0xFF7E57C2)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 24),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: Color(0xFF7E57C2),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD1C4E9),
                                  foregroundColor: const Color(0xFF424242),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  elevation: 2,
                                ),
                                onPressed: _isLoading ? null : _handleLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF424242),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            
                            // Register Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const Signup()),
                                    );
                                  },
                                  child: const Text(
                                    "Register",
                                    style: TextStyle(
                                      color: Color(0xFF7E57C2),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}