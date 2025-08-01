import 'package:doctorappoinmentapp/screens/registeration_screens/signup_screen.dart';
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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      final messenger = ScaffoldMessenger.of(context);

      try {
        // Check if it's admin login
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
              // If we can't create the user (might already exist but with wrong password)
              print('Error creating admin user: $createError');
              // Try to sign in anyway - this will fail if the password is wrong
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
                backgroundColor: Color(0xFF7E57C2), // Theme accent color
              )
            );
            // Navigate to admin page
            Navigator.pushReplacementNamed(context, '/admin');
          }
          return;
        }
        
        // Regular user login
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, 
          password: password
        );
        
        // Check if user has admin role in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();

        final isAdmin = userDoc.exists && userDoc.data()?['role'] == 'admin';

        // Store login status and admin status in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAdmin', isAdmin);
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(isAdmin ? "Admin login successful!" : "Login successful!"),
              backgroundColor: const Color(0xFF7E57C2), // Theme accent color
            )
          );
          // Navigate to appropriate page based on user role
          if (isAdmin) {
            Navigator.pushReplacementNamed(context, '/admin');
          } else {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }

      } on FirebaseAuthException catch (e) {
        String errorMessage = "An error occurred. Please try again.";
        
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          errorMessage = "Incorrect email or password";
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
            backgroundColor: Color(0xFF7E57C2), // Theme accent color
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
                    // App Logo
                    // Login Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6).withOpacity(0.95), // Light Lavender with opacity
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                            color: const Color(0xFF7E57C2).withOpacity(0.15), // Theme accent color shadow
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Login Title - using theme colors
                            const Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.normal,
                                color: Color(0xFF424242), // Theme text color
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
                                  // Show dialog to get email
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFFFAF8F5), // Theme background
                                      title: const Text(
                                        "Reset Password",
                                        style: TextStyle(color: Color(0xFF424242)), // Theme text color
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
                                            style: TextStyle(color: Color(0xFF7E57C2)), // Theme accent color
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
                                    color: Color(0xFF7E57C2), // Theme accent color
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
                                  backgroundColor: const Color(0xFFD1C4E9), // Theme button color
                                  foregroundColor: const Color(0xFF424242), // Theme text color
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16), // Theme border radius
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
                                          color: Color(0xFF424242), // Theme text color
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600, // Theme font weight
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
                                      color: Color(0xFF7E57C2), // Theme accent color
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