// screens/doctor_screens/doctor_update_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DoctorUpdateScreen extends StatefulWidget {
  final String doctorId;
  
  const DoctorUpdateScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorUpdateScreen> createState() => _DoctorUpdateScreenState();
}

class _DoctorUpdateScreenState extends State<DoctorUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isUpdating = false;
  
  // Controllers - matching doctor model fields exactly
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _addressController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  
  // Selected values
  String _selectedSpecialization = '';
  List<String> _availableDays = [];
  double _rating = 4.5;
  bool _isVerified = false;
  
  // Image
  File? _selectedImage;
  String? _currentImageUrl;
  
  // Data lists
  final List<String> _specializations = [
    'General Medicine',
    'Cardiology',
    'Dermatology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Gynecology',
    'Ophthalmology',
    'ENT',
    'Dentistry',
    'Surgery',
    'Radiology',
    'Pathology',
    'Anesthesiology',
    'Emergency Medicine',
    'Family Medicine',
    'Internal Medicine',
  ];
  
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday', 
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
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
    _qualificationsController.dispose();
    _experienceController.dispose();
    _hospitalController.dispose();
    _addressController.dispose();
    _consultationFeeController.dispose();
    _licenseNumberController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    setState(() => _isLoading = true);
    
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        
        setState(() {
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _qualificationsController.text = data['qualifications'] ?? '';
          _experienceController.text = (data['experienceYears'] ?? data['experience'] ?? 0).toString();
          _hospitalController.text = data['hospital'] ?? '';
          _addressController.text = data['address'] ?? '';
          _consultationFeeController.text = data['consultationFee']?.toString() ?? '';
          _licenseNumberController.text = data['licenseNumber'] ?? '';
          _startTimeController.text = data['startTime'] ?? '';
          _endTimeController.text = data['endTime'] ?? '';
          
          _selectedSpecialization = data['specialization'] ?? '';
          _availableDays = List<String>.from(data['availableDays'] ?? []);
          _rating = (data['rating'] ?? 4.5).toDouble();
          _isVerified = data['isVerified'] ?? false;
          _currentImageUrl = data['profileImageUrl'];
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading doctor data: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load doctor information');
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      final formattedTime = picked.format(context);
      setState(() {
        controller.text = formattedTime;
      });
    }
  }

  Future<void> _updateDoctorProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isUpdating = true);
    
    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialization': _selectedSpecialization,
        'qualifications': _qualificationsController.text.trim(),
        'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
        'experience': int.tryParse(_experienceController.text.trim()) ?? 0, // For compatibility
        'hospital': _hospitalController.text.trim(),
        'address': _addressController.text.trim(),
        'consultationFee': double.tryParse(_consultationFeeController.text.trim()),
        'licenseNumber': _licenseNumberController.text.trim(),
        'availableDays': _availableDays,
        'startTime': _startTimeController.text.trim(),
        'endTime': _endTimeController.text.trim(),
        'rating': _rating,
        'isVerified': _isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // TODO: If image is selected, upload to storage and add URL to updateData
      // For now, we'll keep the existing image URL
      if (_currentImageUrl != null) {
        updateData['profileImageUrl'] = _currentImageUrl;
      }
      
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .update(updateData);
      
      _showSuccess('Profile updated successfully!');
      Navigator.pop(context, true); // Return true to indicate successful update
      
    } catch (e) {
      print('❌ Error updating profile: $e');
      _showError('Failed to update profile: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        onTap: onTap,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
          ),
        ),
        validator: validator ?? (value) {
          if (value?.trim().isEmpty == true) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value.toString().isEmpty ? null : value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
          ),
        ),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString()),
        )).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null) {
            return 'Please select an option';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required List<String> options,
    required List<String> selectedValues,
    required void Function(String) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onToggle(option),
              selectedColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              checkmarkColor: Theme.of(context).colorScheme.secondary,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Update Profile'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : _updateDoctorProfile,
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'SAVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Picture Section
              _buildSection(
                'Profile Picture',
                [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_currentImageUrl != null
                                  ? NetworkImage(_currentImageUrl!)
                                  : null) as ImageProvider?,
                          child: (_selectedImage == null && _currentImageUrl == null)
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[600],
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Basic Information
              _buildSection(
                'Basic Information',
                [
                  _buildTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    icon: Icons.person,
                    hintText: 'Enter your full name',
                  ),
                  _buildTextField(
                    label: 'Email',
                    controller: _emailController,
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'Enter your email address',
                  ),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    hintText: 'Enter your phone number',
                  ),
                ],
              ),

              // Professional Information
              _buildSection(
                'Professional Information',
                [
                  _buildDropdown(
                    label: 'Specialization',
                    value: _selectedSpecialization,
                    items: _specializations,
                    onChanged: (value) => setState(() => _selectedSpecialization = value ?? ''),
                    icon: Icons.medical_services,
                  ),
                  _buildTextField(
                    label: 'Qualifications',
                    controller: _qualificationsController,
                    icon: Icons.school,
                    hintText: 'e.g., MBBS, MD, etc.',
                  ),
                  _buildTextField(
                    label: 'Years of Experience',
                    controller: _experienceController,
                    icon: Icons.work,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hintText: 'Enter years of experience',
                  ),
                  _buildTextField(
                    label: 'Medical License Number',
                    controller: _licenseNumberController,
                    icon: Icons.badge,
                    hintText: 'Enter your medical license number',
                  ),
                ],
              ),

              // Hospital/Clinic Information
              _buildSection(
                'Hospital/Clinic Information',
                [
                  _buildTextField(
                    label: 'Hospital/Clinic Name',
                    controller: _hospitalController,
                    icon: Icons.local_hospital,
                    hintText: 'Enter hospital or clinic name',
                  ),
                  _buildTextField(
                    label: 'Address',
                    controller: _addressController,
                    icon: Icons.location_on,
                    maxLines: 3,
                    hintText: 'Enter complete address',
                  ),
                  _buildTextField(
                    label: 'Consultation Fee (PKR)',
                    controller: _consultationFeeController,
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    hintText: 'Enter consultation fee',
                  ),
                ],
              ),

              // Schedule Information
              _buildSection(
                'Schedule & Availability',
                [
                  _buildMultiSelectChips(
                    label: 'Available Days',
                    options: _daysOfWeek,
                    selectedValues: _availableDays,
                    onToggle: (day) {
                      setState(() {
                        if (_availableDays.contains(day)) {
                          _availableDays.remove(day);
                        } else {
                          _availableDays.add(day);
                        }
                      });
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Start Time',
                          controller: _startTimeController,
                          icon: Icons.access_time,
                          readOnly: true,
                          onTap: () => _selectTime(_startTimeController),
                          hintText: 'Select start time',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          label: 'End Time',
                          controller: _endTimeController,
                          icon: Icons.access_time_filled,
                          readOnly: true,
                          onTap: () => _selectTime(_endTimeController),
                          hintText: 'Select end time',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updateDoctorProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 2,
                  ),
                  child: _isUpdating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Updating...'),
                          ],
                        )
                      : const Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}