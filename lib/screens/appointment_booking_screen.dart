import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doctorappoinmentapp/services/appointment_service.dart';
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:doctorappoinmentapp/models/disease_model.dart';
import 'package:doctorappoinmentapp/screens/doctor_profile_screen.dart';

class AppointmentBookingScreen extends StatefulWidget {
  final Doctor? preSelectedDoctor;
  final List<Disease>? selectedDiseases;
  final String? referenceSource;
  
  const AppointmentBookingScreen({
    super.key,
    this.preSelectedDoctor,
    this.selectedDiseases,
    this.referenceSource,
  });

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appointmentService = AppointmentService();
  
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _symptomsController = TextEditingController();
  
  // State
  Doctor? selectedDoctor;
  DateTime? selectedDate;
  String? selectedTime;
  String selectedAppointmentType = 'chat';
  List<String> availableSlots = [];
  bool isLoadingSlots = false;
  bool isBooking = false;

  List<Map<String, dynamic>> get _appointmentTypes => [
    {
      'type': 'chat',
      'name': 'Chat',
      'icon': Icons.chat_bubble_outline,
      'description': 'Text consultation',
    },
    {
      'type': 'video_call',
      'name': 'Video Call',
      'icon': Icons.videocam_outlined,
      'description': 'Video consultation',
    },
    {
      'type': 'in_person',
      'name': 'In-Person',
      'icon': Icons.local_hospital_outlined,
      'description': 'Clinic visit',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    selectedDoctor = widget.preSelectedDoctor;
    if (widget.selectedDiseases?.isNotEmpty == true) {
      final diseaseNames = widget.selectedDiseases!.map((d) => d.name).join(', ');
      _symptomsController.text = 'Health concerns: $diseaseNames';
    }
  }

  String _convertTo24HourFormat(String time12) {
    try {
      // Handle formats like "9:00 AM", "2:30 PM"
      final parts = time12.trim().split(' ');
      if (parts.length != 2) return time12; // Return original if format is unexpected
      
      final timePart = parts[0];
      final amPm = parts[1].toUpperCase();
      
      final timeSplit = timePart.split(':');
      if (timeSplit.length != 2) return time12; // Return original if format is unexpected
      
      int hour = int.parse(timeSplit[0]);
      int minute = int.parse(timeSplit[1]);
      
      // Convert to 24-hour format
      if (amPm == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error converting time format: $e');
      return time12; // Return original if conversion fails
    }
  }

  String _formatTimeDisplay(String time24) {
    try {
      // Convert 24-hour format to 12-hour format for display
      final timeParts = time24.split(':');
      if (timeParts.length != 2) return time24;
      
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      String amPm = hour >= 12 ? 'PM' : 'AM';
      
      // Convert to 12-hour format
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      
      return '${hour}:${minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      print('Error formatting time for display: $e');
      return time24;
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (selectedDoctor == null || selectedDate == null) return;

    setState(() {
      isLoadingSlots = true;
      availableSlots = [];
      selectedTime = null;
    });

    try {
      final dateString = DateFormat('yyyy-MM-dd').format(selectedDate!);
      print('🔍 Loading slots for doctor: ${selectedDoctor!.id}, date: $dateString');
      
      // Fetch slots from appointment service (these come in 12-hour format)
      List<String> slotsFrom12Hour = await _appointmentService.fetchAvailableSlots(selectedDoctor!.id, dateString);
      print('🔄 AppointmentService returned ${slotsFrom12Hour.length} slots: $slotsFrom12Hour');
      
      // Convert 12-hour format slots to 24-hour format for internal processing
      List<String> slots24Hour = slotsFrom12Hour.map((slot) => _convertTo24HourFormat(slot)).toList();
      
      // Check if no slots are available
      if (slots24Hour.isEmpty) {
        print('❌ No available slots found for $dateString');
        setState(() {
          availableSlots = [];
          isLoadingSlots = false;
        });
        return;
      }
      
      // Sort the slots chronologically
      slots24Hour.sort((a, b) {
        try {
          final timeA = DateFormat('HH:mm').parse(a);
          final timeB = DateFormat('HH:mm').parse(b);
          return timeA.compareTo(timeB);
        } catch (e) {
          return 0;
        }
      });
      
      setState(() {
        availableSlots = slots24Hour; // Store in 24-hour format for consistency
        isLoadingSlots = false;
      });
      
      print('🎉 Successfully loaded ${availableSlots.length} slots for UI');
      
    } catch (e) {
      print('❌ Error loading slots: $e');
      print('📍 Error stack trace: ${StackTrace.current}');
      
      setState(() {
        availableSlots = [];
        isLoadingSlots = false;
      });
      
      if (mounted) {
        _showError('Failed to load available time slots. Please try again or select a different date.');
      }
    }
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate() || 
        selectedDoctor == null || 
        selectedDate == null || 
        selectedTime == null) {
      _showError('Please fill all required fields');
      return;
    }

    // Allow booking for tomorrow and future dates only
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final selectedDateOnly = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    
    if (selectedDateOnly.isBefore(tomorrow)) {
      _showError('Cannot book appointments for today or past dates. Please select tomorrow or a future date.');
      return;
    }

    setState(() => isBooking = true);

    try {
      String enhancedSymptoms = _symptomsController.text.trim();
      if (widget.selectedDiseases?.isNotEmpty == true) {
        final diseaseNames = widget.selectedDiseases!.map((d) => d.name).join(', ');
        if (enhancedSymptoms.isEmpty) {
          enhancedSymptoms = 'Selected health concerns: $diseaseNames';
        } else if (!enhancedSymptoms.contains(diseaseNames)) {
          enhancedSymptoms += '\nSelected health concerns: $diseaseNames';
        }
      }
      
      // Convert 24-hour format back to 12-hour format for booking
      // because the appointment service expects the same format as stored in database
      String timeForBooking = _formatTimeDisplay(selectedTime!); // This converts to 12-hour format
      
      await _appointmentService.bookAppointment(
        doctorId: selectedDoctor!.id,
        userName: _nameController.text.trim(),
        userPhone: _phoneController.text.trim(),
        date: DateFormat('yyyy-MM-dd').format(selectedDate!),
        time: timeForBooking, // Use 12-hour format for booking
        userEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        symptoms: enhancedSymptoms.isEmpty ? null : enhancedSymptoms,
        appointmentType: selectedAppointmentType,
      );

      if (mounted) _showSuccessDialog();
    } catch (e) {
      print('Booking error: $e');
      _showError('Booking failed: ${e.toString()}');
    } finally {
      setState(() => isBooking = false);
    }
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: tomorrow, // Start from tomorrow
      firstDate: tomorrow,   // Start from tomorrow, not today
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.secondary,
              surface: Theme.of(context).cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      // Ensure we only allow tomorrow and future dates
      final selectedDateOnly = DateTime(picked.year, picked.month, picked.day);
      final tomorrowOnly = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      
      if (selectedDateOnly.isBefore(tomorrowOnly)) {
        _showError('Cannot book appointments for today or past dates. Please select tomorrow or a future date.');
        return;
      }
      
      setState(() {
        selectedDate = picked;
        selectedTime = null;
      });
      _loadAvailableSlots();
    }
  }

  void _viewDoctorProfile() {
    if (selectedDoctor != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorProfileScreen(doctorId: selectedDoctor!.id),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Appointment Booked!', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully scheduled with Dr. ${selectedDoctor!.name}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 ${DateFormat('EEEE, MMM dd, yyyy').format(selectedDate!)}', style: const TextStyle(fontSize: 12)),
                  Text('🕒 ${_formatTimeDisplay(selectedTime!)}', style: const TextStyle(fontSize: 12)),
                  Text('💬 ${selectedAppointmentType.replaceAll('_', ' ').toUpperCase()}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (widget.selectedDiseases?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('Health Concerns:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: widget.selectedDiseases!.map((disease) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(disease.name, style: const TextStyle(fontSize: 9)),
                  )
                ).toList(),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(60, 36),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard(String title, IconData icon, Widget child, {Color? accentColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (accentColor ?? Theme.of(context).colorScheme.secondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor ?? Theme.of(context).colorScheme.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 18),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
        ),
        validator: validator ?? (value) => 
          value?.trim().isEmpty == true ? 'This field is required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Book Appointment', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 56,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Doctor Info Header (if preselected)
              if (selectedDoctor != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Doctor Avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: selectedDoctor!.profileImageUrl != null && 
                                 selectedDoctor!.profileImageUrl!.isNotEmpty
                              ? Image.network(
                                  selectedDoctor!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.white,
                                        child: Icon(
                                          Icons.person,
                                          size: 30,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.white,
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dr. ${selectedDoctor!.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedDoctor!.specialization,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _viewDoctorProfile,
                        icon: const Icon(Icons.visibility, color: Colors.white, size: 14),
                        label: const Text(
                          'View Profile',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Health Concerns (if any)
              if (widget.selectedDiseases?.isNotEmpty == true)
                _buildCompactCard(
                  'Health Concerns',
                  Icons.favorite_outline,
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.selectedDiseases!.map((disease) => 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          disease.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      )
                    ).toList(),
                  ),
                  accentColor: Colors.pink,
                ),

              // Personal Information
              _buildCompactCard(
                'Personal Information',
                Icons.person_outline,
                Column(
                  children: [
                    _buildCompactTextField(
                      'Full Name',
                      _nameController,
                      Icons.person,
                      hintText: 'Enter your full name',
                    ),
                    _buildCompactTextField(
                      'Phone Number',
                      _phoneController,
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                      hintText: 'Enter your phone number',
                    ),
                    _buildCompactTextField(
                      'Email (Optional)',
                      _emailController,
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'Enter your email address',
                      validator: (value) => null,
                    ),
                  ],
                ),
              ),

              // Consultation Type
              _buildCompactCard(
                'Consultation Type',
                Icons.medical_services_outlined,
                Column(
                  children: _appointmentTypes.map((typeData) {
                    final isSelected = selectedAppointmentType == typeData['type'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => selectedAppointmentType = typeData['type']),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                                  : Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).primaryColor.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.secondary
                                        : Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    typeData['icon'],
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.secondary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        typeData['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.secondary
                                              : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        typeData['description'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.secondary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Date & Time
              _buildCompactCard(
                'Schedule',
                Icons.calendar_today_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selection
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Theme.of(context).colorScheme.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Date',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      selectedDate == null 
                                          ? 'Choose appointment date' 
                                          : DateFormat('EEEE, MMM dd, yyyy').format(selectedDate!),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Time Selection
                    if (selectedDate != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Available Times',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),const SizedBox(height: 8),
                      if (isLoadingSlots)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (availableSlots.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.schedule, color: Colors.orange, size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                'No available slots for this date',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please try selecting another date. Doctor may not have slots available for ${DateFormat('MMM dd, yyyy').format(selectedDate!)}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: availableSlots.length,
                          itemBuilder: (context, index) {
                            final time = availableSlots[index];
                            final isSelected = selectedTime == time;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() => selectedTime = time),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.secondary
                                        : Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.secondary
                                          : Theme.of(context).primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _formatTimeDisplay(time),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),

              // Additional Information
              _buildCompactCard(
                'Additional Information',
                Icons.description_outlined,
                _buildCompactTextField(
                  'Symptoms & Notes',
                  _symptomsController,
                  Icons.description,
                  maxLines: 3,
                  hintText: 'Describe your symptoms or concerns...',
                  validator: (value) => null,
                ),
              ),

              const SizedBox(height: 16),

              // Book Button
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).primaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isBooking ? null : _bookAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: isBooking 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }
}