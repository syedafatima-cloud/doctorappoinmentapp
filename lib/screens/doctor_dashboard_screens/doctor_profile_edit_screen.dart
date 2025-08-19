// screens/doctor_screens/doctor_profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DoctorProfileEditScreen extends StatefulWidget {
  final String doctorId;
  
  const DoctorProfileEditScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorProfileEditScreen> createState() => _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Controllers for form fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _addressController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _bioController = TextEditingController();
  
  String? _profileImageUrl;
  File? _selectedImage;
  List<String> _availableDays = [];
  String _startTime = '09:00';
  String _endTime = '17:00';
  
  final List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _addressController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _consultationFeeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    try {
      // Try to find doctor in doctors collection first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();
      
      Map<String, dynamic>? data;
      
      if (doc.exists) {
        data = doc.data() as Map<String, dynamic>;
      } else {
        // Check pending_doctor_registrations
        final pendingQuery = await FirebaseFirestore.instance
            .collection('pending_doctor_registrations')
            .where('approvedDoctorId', isEqualTo: widget.doctorId)
            .where('status', isEqualTo: 'approved')
            .get();
        
        if (pendingQuery.docs.isNotEmpty) {
          data = pendingQuery.docs.first.data();
        }
      }
      
      if (data != null) {
        setState(() {
          _nameController.text = data!['fullName'] ?? data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? data['phone'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _hospitalController.text = data['hospital'] ?? '';
          _addressController.text = data['address'] ?? '';
          _qualificationsController.text = data['qualifications'] ?? '';
          _experienceController.text = (data['experienceYears'] ?? data['experience'] ?? 0).toString();
          _consultationFeeController.text = (data['consultationFee'] ?? 0).toString();
          _bioController.text = data['bio'] ?? '';
          _profileImageUrl = data['profileImageUrl'];
          _availableDays = List<String>.from(data['availableDays'] ?? []);
          _startTime = data['startTime'] ?? '09:00';
          _endTime = data['endTime'] ?? '17:00';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('Doctor profile not found');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading profile: ${e.toString()}');
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Error picking image: ${e.toString()}');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final updateData = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'hospital': _hospitalController.text.trim(),
        'address': _addressController.text.trim(),
        'qualifications': _qualificationsController.text.trim(),
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'consultationFee': double.tryParse(_consultationFeeController.text) ?? 0.0,
        'bio': _bioController.text.trim(),
        'availableDays': _availableDays,
        'startTime': _startTime,
        'endTime': _endTime,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // TODO: Handle image upload if _selectedImage is not null
      if (_selectedImage != null) {
        // uploadedUrl = await _uploadImage(_selectedImage!);
        // updateData['profileImageUrl'] = uploadedUrl;
        _showSuccess('Image upload feature coming soon!');
      }
      
      // Update in doctors collection
      try {
        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(widget.doctorId)
            .update(updateData);
      } catch (e) {
        // If not found in doctors, update in pending_doctor_registrations
        final pendingQuery = await FirebaseFirestore.instance
            .collection('pending_doctor_registrations')
            .where('approvedDoctorId', isEqualTo: widget.doctorId)
            .where('status', isEqualTo: 'approved')
            .get();
        
        if (pendingQuery.docs.isNotEmpty) {
          await pendingQuery.docs.first.reference.update(updateData);
        } else {
          throw Exception('Doctor profile not found for update');
        }
      }
      
      _showSuccess('Profile updated successfully!');
      Navigator.pop(context, true);
      
    } catch (e) {
      _showError('Error saving profile: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image Section
              _buildProfileImageSection(),
              const SizedBox(height: 32),
              
              // Personal Information
              _buildSection(
                'Personal Information',
                Icons.person,
                [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Email is required';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter your phone number',
                    keyboardType: TextInputType.phone,
                    validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Professional Information
              _buildSection(
                'Professional Information',
                Icons.work,
                [
                  _buildTextField(
                    controller: _specializationController,
                    label: 'Specialization',
                    hint: 'e.g., Cardiologist, Pediatrician',
                    validator: (value) => value?.isEmpty == true ? 'Specialization is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _hospitalController,
                    label: 'Hospital/Clinic',
                    hint: 'Enter your workplace',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _qualificationsController,
                    label: 'Qualifications',
                    hint: 'e.g., MBBS, MD',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _experienceController,
                          label: 'Experience (Years)',
                          hint: '5',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _consultationFeeController,
                          label: 'Consultation Fee (\$)',
                          hint: '50',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Contact & Location
              _buildSection(
                'Location',
                Icons.location_on,
                [
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Enter your clinic/hospital address',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // About/Bio
              _buildSection(
                'About You',
                Icons.info_outline,
                [
                  _buildTextField(
                    controller: _bioController,
                    label: 'Bio/Description',
                    hint: 'Tell patients about yourself, your approach, etc.',
                    maxLines: 4,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Availability
              _buildSection(
                'Availability',
                Icons.schedule,
                [
                  _buildAvailabilitySection(),
                ],
              ),
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).primaryColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? Image.network(
                            _profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                          )
                        : _buildDefaultAvatar(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Change Photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[200],
      child: Icon(
        Icons.person,
        size: 60,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Days:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weekDays.map((day) {
            final isSelected = _availableDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _availableDays.add(day);
                  } else {
                    _availableDays.remove(day);
                  }
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Working Hours:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Time'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _startTime,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _generateTimeOptions(),
                    onChanged: (value) => setState(() => _startTime = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Time'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _endTime,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _generateTimeOptions(),
                    onChanged: (value) => setState(() => _endTime = value!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _generateTimeOptions() {
    final times = <String>[];
    for (int hour = 6; hour <= 23; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final timeString = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        times.add(timeString);
      }
    }
    
    return times.map((time) => DropdownMenuItem(
      value: time,
      child: Text(_formatTime(time)),
    )).toList();
  }

  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } catch (e) {
      return time24;
    }
  }
}