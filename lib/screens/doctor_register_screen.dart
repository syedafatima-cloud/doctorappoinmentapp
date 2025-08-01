// screens/doctor_registration_screen.dart - WITH ADMIN APPROVAL SYSTEM
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/doctor_register_model.dart';
import '../services/doctor_register_service.dart';
import '../services/doctor_firestore_service.dart';

class DoctorRegistrationScreen extends StatefulWidget {
  final Map<String, String>? userData;
  
  const DoctorRegistrationScreen({super.key, this.userData});

  @override
  State<DoctorRegistrationScreen> createState() => _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorService = DoctorRegistrationService();
  final ImagePicker _picker = ImagePicker();
  
  // Controllers for form fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _addressController = TextEditingController();
  final _experienceController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _feeController = TextEditingController();

  String? _selectedSpecialization;
  final List<String> _selectedDays = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = false;
  File? _selectedImage;

  final List<String> _specializations = [
    'General Practice',
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'Neurology',
    'Oncology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Radiology',
    'Surgery',
    'Urology',
    'Gynecology',
    'Ophthalmology',
    'ENT',
    'Anesthesiology',
    'Emergency Medicine',
    'Internal Medicine',
    'Family Medicine'
  ];

  final List<String> _weekDays = [
    'Monday',
    'Tuesday', 
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill form fields if user data is provided
    if (widget.userData != null) {
      _fullNameController.text = '${widget.userData!['firstName'] ?? ''} ${widget.userData!['lastName'] ?? ''}'.trim();
      _emailController.text = widget.userData!['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _hospitalController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    _qualificationsController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Profile Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.photo_camera, color: Colors.teal),
                    ),
                    title: const Text('Take Photo'),
                    subtitle: const Text('Use camera to take a new photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _getImage(ImageSource.camera);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.photo_library, color: Colors.teal),
                    ),
                    title: const Text('Choose from Gallery'),
                    subtitle: const Text('Select from your photo library'),
                    onTap: () {
                      Navigator.pop(context);
                      _getImage(ImageSource.gallery);
                    },
                  ),
                  if (_selectedImage != null) ...[
                    const Divider(),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      title: const Text('Remove Photo'),
                      subtitle: const Text('Delete current profile photo'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing image picker: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        if (await imageFile.exists()) {
          setState(() {
            _selectedImage = imageFile;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image selected successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Selected image file does not exist');
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: Please try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSpecialization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a specialization')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one available day')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? profileImageUrl;
      
      // Upload image if selected
      if (_selectedImage != null) {
        print('Starting image upload...');
        profileImageUrl = await DoctorFirestoreService.uploadImage(_selectedImage!);
        print('Image upload result: $profileImageUrl');
        
        if (profileImageUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload image. Please try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      } else {
        print('No image selected for upload');
      }

      final doctorData = {
  'fullName': _fullNameController.text.trim(),
  'email': _emailController.text.trim(),
  'phoneNumber': _phoneController.text.trim(),
  'specialization': _selectedSpecialization!,
  'licenseNumber': _licenseController.text.trim(),
  'hospital': _hospitalController.text.trim(),
  'address': _addressController.text.trim(),
  'experienceYears': int.parse(_experienceController.text),
  'qualifications': _qualificationsController.text.trim(),
  'availableDays': _selectedDays,
  'startTime': _formatTime(_startTime),
  'endTime': _formatTime(_endTime),
  'consultationFee': double.parse(_feeController.text),
  'profileImageUrl': profileImageUrl ?? '',
};

// Submit for admin approval instead of direct registration
final requestId = await _doctorService.submitDoctorRegistrationRequest(doctorData);

      if (requestId != null) {
          if (mounted) {
            _showRegistrationSubmittedDialog(); // This method already exists in your code
          }
        }
       else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration failed: Could not save to database.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // NEW METHOD: Show registration submitted dialog
  void _showRegistrationSubmittedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registration Submitted',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your doctor registration has been submitted successfully!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'What happens next?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Admin will review your credentials\n'
                      '• You\'ll receive a notification once approved\n'
                      '• Your profile will be visible to patients after approval',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We\'ll notify you via email and in-app notification once your registration is reviewed.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushReplacementNamed(context, '/home'); // Navigate to home
              },
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Continue to Home'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Register as a Doctor',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your registration will be reviewed by our admin team',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Profile Image Section
                      _buildProfileImageSection(context),
                      const SizedBox(height: 28),

                      // Personal Information Section
                      _buildSectionTitle('Personal Information'),
                      _buildTextField(_fullNameController, 'Full Name', Icons.person),
                      _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                      _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),

                      const SizedBox(height: 24),

                      // Professional Information Section
                      _buildSectionTitle('Professional Information'),
                      _buildSpecializationDropdown(),
                      _buildTextField(_licenseController, 'Medical License Number', Icons.card_membership),
                      _buildTextField(_hospitalController, 'Hospital/Clinic Name', Icons.local_hospital),
                      _buildTextField(_experienceController, 'Years of Experience', Icons.work, keyboardType: TextInputType.number),
                      _buildTextField(_qualificationsController, 'Qualifications', Icons.school, maxLines: 3),
                      _buildTextField(_addressController, 'Address', Icons.location_on, maxLines: 2),

                      const SizedBox(height: 24),

                      // Schedule Information Section
                      _buildSectionTitle('Schedule & Fees'),
                      _buildAvailableDaysSelector(),
                      const SizedBox(height: 16),
                      _buildTimeSelector(),
                      const SizedBox(height: 16),
                      _buildTextField(_feeController, 'Consultation Fee (USD)', Icons.attach_money, keyboardType: TextInputType.number),

                      const SizedBox(height: 36),

                      ElevatedButton(
                        onPressed: _registerDoctor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- Enhanced Profile Image Section ---
  Widget _buildProfileImageSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'Profile Photo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary,
                width: 3,
              ),
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _selectedImage != null
                ? ClipOval(
                    child: Image.file(
                      _selectedImage!,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedImage != null)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedImage = null;
              });
            },
            icon: Icon(Icons.delete, size: 16, color: Colors.red.shade400),
            label: const Text('Remove Photo'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
            ),
          )
        else
          Text(
            'Tap to add your profile photo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  // --- Modern Section Title ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 8),
      child: Row(
        children: [
          Icon(Icons.circle, color: Theme.of(context).primaryColor, size: 12),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Modern Text Field ---
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24), // Fully circular
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }
          if (label == 'Email' && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          if (label == 'Phone Number' && value.length < 10) {
            return 'Please enter a valid phone number';
          }
          return null;
        },
      ),
    );
  }

  // --- Modern Dropdown ---
  Widget _buildSpecializationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedSpecialization,
        decoration: InputDecoration(
          labelText: 'Specialization',
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          prefixIcon: Icon(Icons.medical_services, color: Theme.of(context).colorScheme.secondary),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
        ),
        items: _specializations.map((String specialization) {
          return DropdownMenuItem<String>(
            value: specialization,
            child: Text(
              specialization,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedSpecialization = newValue;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a specialization';
          }
          return null;
        },
      ),
    );
  }

  // --- Modern Available Days Selector ---
  Widget _buildAvailableDaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Days',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _weekDays.map((day) {
            final isSelected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.5),
              checkmarkColor: Theme.of(context).colorScheme.secondary,
              backgroundColor: Theme.of(context).cardColor,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Modern Time Selector ---
  Widget _buildTimeSelector() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: Text('Start Time', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            subtitle: Text(_formatTime(_startTime), style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            leading: Icon(Icons.access_time, color: Theme.of(context).colorScheme.secondary),
            onTap: () => _selectTime(context, true),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ListTile(
            title: Text('End Time', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            subtitle: Text(_formatTime(_endTime), style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            leading: Icon(Icons.access_time_filled, color: Theme.of(context).colorScheme.secondary),
            onTap: () => _selectTime(context, false),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }
}