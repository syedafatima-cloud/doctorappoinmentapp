import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final List<List<Color>> _gradients = [
    [const Color(0xFFFAF8F5), const Color(0xFFC5CAE9)], // Soft Cream to Lavender Mist
    [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)], // Light Lavender to Dusty Lilac
    [const Color(0xFFC5CAE9), const Color(0xFF7E57C2)], // Lavender Mist to Muted Plum
  ];

  int _index = 0;
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  bool _isPasswordVisible = false;
  
  // User type selection variables
  String _selectedUserType = 'patient'; // Default to patient

  @override
  void initState() {
    super.initState();
    _animateBackground();
  }

  void _animateBackground() {
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _index = (_index + 1) % _gradients.length;
      });
      _animateBackground();
    });
  }

  // Input Field with Validation
  Widget _buildInputField(String label,
      {bool isPassword = false, TextEditingController? controller, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF424242))),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? !_isPasswordVisible : false,
          validator: validator, // Validation function
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, 
                              color: const Color(0xFF7E57C2)),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // User Type Selection Widget
  Widget _buildUserTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Register as",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF424242)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedUserType = 'patient';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _selectedUserType == 'patient' 
                        ? const Color(0xFF7E57C2) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedUserType == 'patient' 
                          ? const Color(0xFF7E57C2) 
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        color: _selectedUserType == 'patient' 
                            ? Colors.white 
                            : const Color(0xFF7E57C2),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Patient',
                        style: TextStyle(
                          color: _selectedUserType == 'patient' 
                              ? Colors.white 
                              : const Color(0xFF7E57C2),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedUserType = 'doctor';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _selectedUserType == 'doctor' 
                        ? const Color(0xFF7E57C2) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedUserType == 'doctor' 
                          ? const Color(0xFF7E57C2) 
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: _selectedUserType == 'doctor' 
                            ? Colors.white 
                            : const Color(0xFF7E57C2),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Doctor',
                        style: TextStyle(
                          color: _selectedUserType == 'doctor' 
                              ? Colors.white 
                              : const Color(0xFF7E57C2),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      // If doctor is selected, navigate to doctor registration screen
      if (_selectedUserType == 'doctor') {
        Navigator.pushNamed(context, '/doctor-register', arguments: {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        });
        return;
      }

      // Proceed with patient registration
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      final messenger = ScaffoldMessenger.of(context);

      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        messenger.showSnackBar(
          SnackBar(
            content: const Text("Patient registered successfully!"),
            backgroundColor: const Color(0xFF7E57C2),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        String message = "An error occurred";

        if (e.code == 'email-already-in-use') {
          message = "This email is already registered.";
        } else if (e.code == 'weak-password') {
          message = "Password should be at least 6 characters.";
        } else if (e.code == 'invalid-email') {
          message = "Please enter a valid email.";
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          AnimatedContainer(
            duration: const Duration(seconds: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gradients[_index],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Scrollable UI Content
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo at the top
                 

                  // Register Form
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 50),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 400, // Maximum width for the card
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          width: MediaQuery.of(context).size.width * 0.85, // Use percentage of screen width
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6).withOpacity(0.9), // Light Lavender with opacity
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                spreadRadius: 1,
                                color: const Color(0xFF7E57C2).withOpacity(0.2),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey, // Attach form key
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Register Title
                                const Text(
                                  "Register",
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Color(0xFF424242),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // User Type Selection
                                _buildUserTypeSelection(),
                                const SizedBox(height: 15),

                                // First Name
                                _buildInputField("First Name", controller: _firstNameController, validator: (value) {
                                  if (value == null || value.isEmpty) return "First Name is required";
                                  return null;
                                }),
                                const SizedBox(height: 10),

                                // Last Name
                                _buildInputField("Last Name", controller: _lastNameController, validator: (value) {
                                  if (value == null || value.isEmpty) return "Last Name is required";
                                  return null;
                                }),
                                const SizedBox(height: 10),

                                // Email Address
                                _buildInputField("Email Address", controller: _emailController, validator: (value) {
                                  if (value == null || value.isEmpty) return "Email is required";
                                  if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                                    return "Enter a valid email";
                                  }
                                  return null;
                                }),
                                const SizedBox(height: 10),

                                // Password
                                _buildInputField("Enter Password", isPassword: true, controller: _passwordController, validator: (value) {
                                  if (value == null || value.isEmpty) return "Password is required";
                                  if (value.length < 6) return "Password must be at least 6 characters";
                                  if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).{6,}$').hasMatch(value)) {
                                    return "Password must contain an uppercase letter and a number";
                                  }
                                  return null;
                                }),
                                const SizedBox(height: 20),

                                // Register Button
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7E57C2), // Muted Plum
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    minimumSize: const Size(double.infinity, 50),
                                    shadowColor: const Color(0xFF7E57C2).withOpacity(0.3),
                                    elevation: 6,
                                  ),
                                  onPressed: _handleRegistration,
                                  child: Text(
                                    _selectedUserType == 'doctor' 
                                        ? 'Continue as Doctor' 
                                        : 'Register as Patient',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}