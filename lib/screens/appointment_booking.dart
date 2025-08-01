import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentBookingPage extends StatefulWidget {
  final Doctor doctor;

  const AppointmentBookingPage({
    super.key,
    required this.doctor,
  });

  @override
  State<AppointmentBookingPage> createState() => _AppointmentBookingPageState();
}

class _AppointmentBookingPageState extends State<AppointmentBookingPage> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _symptomsController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedTime;
  String _selectedAppointmentType = 'chat';
  bool _isBooking = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<String> _appointmentTypes = ['chat', 'video_call', 'in_person'];
  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '12:00 PM', '12:30 PM', '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM',
    '04:00 PM', '04:30 PM', '05:00 PM', '05:30 PM', '06:00 PM', '06:30 PM'
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }
  // Add this method to your existing AppointmentBookingPage class

Future<void> _bookAppointment() async {
  if (!_formKey.currentState!.validate() || 
      _selectedDate == null || 
      _selectedTime == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please fill all required fields'),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
    return;
  }

  setState(() {
    _isBooking = true;
  });

  try {
    final appointmentData = {
      'doctorId': widget.doctor.id,
      'doctorName': widget.doctor.name,
      'userName': _nameController.text.trim(),
      'userPhone': _phoneController.text.trim(),
      'userEmail': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'time': _selectedTime,
      'appointmentType': _selectedAppointmentType,
      'symptoms': _symptomsController.text.trim().isEmpty ? null : _symptomsController.text.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await FirebaseFirestore.instance
        .collection('appointments')
        .add(appointmentData);

    // If appointment type is chat, create initial consultation record
    if (_selectedAppointmentType == 'chat') {
      await _createChatConsultation(docRef.id);
    }

    if (mounted) {
      _showSuccessDialog(docRef.id);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to book appointment: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isBooking = false;
      });
    }
  }
}

Future<void> _createChatConsultation(String appointmentId) async {
  try {
    await FirebaseFirestore.instance
        .collection('consultations')
        .doc(appointmentId)
        .set({
      'appointmentId': appointmentId,
      'doctorId': widget.doctor.id,
      'doctorName': widget.doctor.name,
      'patientId': 'patient_${DateTime.now().millisecondsSinceEpoch}', // Generate unique patient ID
      'patientName': _nameController.text.trim(),
      'patientPhone': _phoneController.text.trim(),
      'patientEmail': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageFrom': '',
      'status': 'pending',
      'unreadCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'symptoms': _symptomsController.text.trim().isEmpty ? null : _symptomsController.text.trim(),
      'scheduledDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'scheduledTime': _selectedTime,
    });

    // Notify doctor about new chat consultation
    await FirebaseFirestore.instance.collection('doctor_notifications').add({
      'doctorId': widget.doctor.id,
      'appointmentId': appointmentId,
      'patientName': _nameController.text.trim(),
      'patientId': 'patient_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'new_consultation',
      'title': 'New Chat Consultation',
      'body': '${_nameController.text.trim()} has booked a chat consultation',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': {
        'appointmentId': appointmentId,
        'consultationType': 'chat',
      }
    });
  } catch (e) {
    print('Error creating chat consultation: $e');
  }
}

void _showSuccessDialog(String appointmentId) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFAF8F5),
              const Color(0xFFEDE7F6),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade600,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Appointment Booked!',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 18,
                color: const Color(0xFF424242),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment has been successfully scheduled with Dr. ${widget.doctor.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF424242).withOpacity(0.8),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD1C4E9).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ID: ${appointmentId.substring(0, 8)}...',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7E57C2),
                ),
              ),
            )
          ],
          ),
      ),
    ),
  );

}
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF7E57C2),
              onPrimary: Colors.white,
              surface: const Color(0xFFFAF8F5),
              onSurface: const Color(0xFF424242),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
    }
  }





  String _getAppointmentTypeDisplayName(String type) {
    switch (type) {
      case 'chat':
        return 'Chat Consultation';
      case 'video_call':
        return 'Video Call';
      case 'in_person':
        return 'In-Person Visit';
      default:
        return type;
    }
  }

  IconData _getAppointmentTypeIcon(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'video_call':
        return Icons.videocam_outlined;
      case 'in_person':
        return Icons.local_hospital_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E57C2).withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar - Increased height to prevent overlap
          SliverAppBar(
            expandedHeight: 230, // Increased from 170 to 200
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            leading: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).primaryColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 30), // Increased bottom padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16), // Increased spacing
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: widget.doctor.profileImageUrl != null &&
                                       widget.doctor.profileImageUrl!.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          widget.doctor.profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 20,
                                              color: const Color(0xFF7E57C2),
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 20,
                                        color: const Color(0xFF7E57C2),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.doctor.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.doctor.specialization,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: Colors.amber.shade300,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          widget.doctor.rating.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (widget.doctor.consultationFee != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'PKR ${widget.doctor.consultationFee}',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Personal Information
                      _buildSectionCard(
                        title: 'Personal Information',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                hintText: 'Enter your full name',
                                hintStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: const Color(0xFF7E57C2), width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                hintText: 'Enter your phone number',
                                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                prefixIcon: Icon(Icons.phone_outlined, size: 18, color: Colors.grey.shade600),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: const Color(0xFF7E57C2), width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Email (Optional)',
                                labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                hintText: 'Enter your email address',
                                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                prefixIcon: Icon(Icons.email_outlined, size: 18, color: Colors.grey.shade600),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: const Color(0xFF7E57C2), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Consultation Type
                      _buildSectionCard(
                        title: 'Consultation Type',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _appointmentTypes.map((type) {
                            final isSelected = _selectedAppointmentType == type;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAppointmentType = type;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [Color(0xFF7E57C2), Color(0xFFC5CAE9)],
                                        )
                                      : null,
                                  color: isSelected ? null : const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF7E57C2)
                                        : const Color(0xFFEDE7F6),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getAppointmentTypeIcon(type),
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getAppointmentTypeDisplayName(type),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Date & Time Selection
                      _buildSectionCard(
                        title: 'Select Date & Time',
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _selectDate,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedDate != null
                                        ? const Color(0xFF7E57C2)
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 18,
                                      color: _selectedDate != null
                                          ? Theme.of(context).colorScheme.secondary
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _selectedDate == null
                                          ? 'Choose Date'
                                          : DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate!),
                                      style: TextStyle(
                                                                              color: _selectedDate != null
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: _selectedDate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_selectedDate != null) ...[
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Available Times',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 3.0,
                                ),
                                itemCount: _timeSlots.length,
                                itemBuilder: (context, index) {
                                  final time = _timeSlots[index];
                                  final isSelected = _selectedTime == time;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedTime = time;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? const LinearGradient(
                                                colors: [Color(0xFF7E57C2), Color(0xFFC5CAE9)],
                                              )
                                            : null,
                                        color: isSelected ? null : const Color(0xFFEDE7F6),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF7E57C2)
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          time,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF424242),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
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

                      // Symptoms
                      _buildSectionCard(
                        title: 'Additional Information',
                        child: TextFormField(
                          controller: _symptomsController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Describe your symptoms or the reason for consultation...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: Icon(Icons.description_outlined, size: 18, color: Colors.grey.shade600),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: const Color(0xFF7E57C2), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                     
                      // Book Button
                      Container(
                        width: double.infinity,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7E57C2), Color(0xFFC5CAE9)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7E57C2).withOpacity(0.3),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isBooking ? null : _bookAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isBooking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Book Appointment',
                                  style: TextStyle(
                                    fontSize: 14,
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
            ),
          ),
        ],
      ),
    );
  }
}