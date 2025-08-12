import 'package:doctorappoinmentapp/models/chat_model.dart' as chat_model;
import 'package:doctorappoinmentapp/models/doctor_model.dart';
import 'package:doctorappoinmentapp/services/admin_services.dart';
import 'package:doctorappoinmentapp/services/appointment_service.dart';
import 'package:doctorappoinmentapp/services/notification_service.dart';
import 'package:doctorappoinmentapp/services/groq_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:doctorappoinmentapp/screens/registeration_screens/doctor_register_screen.dart';

class GroqMedicalBot extends StatefulWidget {
  const GroqMedicalBot({super.key});

  @override
  State<GroqMedicalBot> createState() => _GroqMedicalBotState();
}

class _GroqMedicalBotState extends State<GroqMedicalBot> {
  final AppointmentService _appointmentService = AppointmentService();
  final AdminService _adminService = AdminService();
  final NotificationService _notificationService = NotificationService();
  final GroqService _groqService = GroqService();
  
  final List<chat_model.ChatMessage> _chatMessages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Appointment booking state
  List<Doctor> _doctors = [];
  Doctor? _selectedDoctor;
  DateTime? _selectedDate;
  List<String> _availableSlots = [];
  String? _selectedSlot;
  String _userName = '';
  String _userPhone = '';
  
  // Chat state
  bool _isTyping = false;
  bool _isBookingMode = false;
  int _bookingStep = 0;
  List<Map<String, String>> _conversationHistory = [];
  bool _isConnected = true;

  // Theme colors - will be replaced with dynamic theme colors
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get accentColor => Theme.of(context).colorScheme.secondary;
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get textColor => Theme.of(context).colorScheme.onSurface;
  Color get buttonColor => Theme.of(context).colorScheme.secondary;
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
    _fetchDoctors();
    _checkGroqConnection();
    
    // Debug: Print current date for reference
    print('📅 Current date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    
    // Initialize sample data with current dates if needed
    _initializeSampleDataIfNeeded();
  }

  // Helper method to format doctor name properly
  String _formatDoctorName(String name) {
    // Check if name already starts with "Dr." (case insensitive)
    if (name.toLowerCase().startsWith('dr.') || name.toLowerCase().startsWith('doctor ')) {
      return name;
    }
    return 'Dr. $name';
  }

  // Helper method to generate time slots for the next 7 days
  Map<String, List<String>> _generateTimeSlots(String startTime, String endTime) {
    final slots = <String, List<String>>{};
    final format = DateFormat("HH:mm");
    final start = format.parse(startTime);
    final end = format.parse(endTime);
    
    // Generate slots for next 7 days
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().add(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      
      List<String> daySlots = [];
      DateTime current = start;
      
      while (current.isBefore(end)) {
        daySlots.add(format.format(current));
        current = current.add(const Duration(minutes: 15));
      }
      
      slots[dateString] = daySlots;
    }
    
    return slots;
  }

  // Initialize sample data with current dates
  Future<void> _initializeSampleDataIfNeeded() async {
    try {
      print('🔄 Starting sample data update...');
      
      // Check if we need to update the sample data
      final doctors = await _appointmentService.getAllDoctors();
      print('📋 Found ${doctors.length} doctors');
      
      for (final doctorData in doctors) {
        final doctor = Doctor.fromMap(doctorData);
        print('👨‍⚕️ Updating doctor: ${doctor.name}');
        
        // Force update all doctors with current dates
        Map<String, List<String>> newSlots;
        if (doctor.specialization.toLowerCase().contains('cardiology')) {
          newSlots = _generateTimeSlots('10:00', '18:00');
        } else if (doctor.specialization.toLowerCase().contains('dermatology')) {
          newSlots = _generateTimeSlots('09:00', '16:00');
        } else {
          newSlots = _generateTimeSlots('09:00', '17:00');
        }
        
        print('📅 Generated slots for ${doctor.name}: ${newSlots.keys.toList()}');
        
        // Update the doctor's available slots in Firebase
        await _appointmentService.updateDoctorSlots(doctor.id, newSlots);
        print('✅ Updated slots for ${doctor.name}');
      }
      
      // Refresh doctors list after updating
      _fetchDoctors();
      
      // Show success message
      _addBotMessage("✅ Sample data updated successfully! You can now try booking an appointment.");
    } catch (e) {
      print('❌ Error initializing sample data: $e');
      _addBotMessage("❌ Error updating sample data: $e");
    }
  }

  void _initializeChat() {
    final welcomeMessage = "👋 Hello! I'm your AI Medical Assistant powered by Groq. I can help you with:\n\n"
        "🩺 Medical questions and health advice\n"
        "📅 Book appointments with doctors\n"
        "💊 Medication information\n"
        "🚨 Emergency guidance\n\n"
        "How can I assist you today?";
        
    _addBotMessage(welcomeMessage);
    
    // Enhanced system prompt for Groq
    _conversationHistory.add({
      'role': 'system',
      'content': '''You are a professional AI medical assistant powered by Groq. Your responsibilities:

MEDICAL ASSISTANCE:
- Provide helpful medical information with appropriate disclaimers
- Always remind users you're an AI and cannot replace professional medical diagnosis
- For emergencies, immediately recommend calling emergency services
- Give general health advice while emphasizing the need for professional consultation

APPOINTMENT BOOKING:
- When users want to book appointments, respond EXACTLY with: "BOOK_APPOINTMENT_TRIGGER"
- Don't add any other text when triggering booking

COMMUNICATION STYLE:
- Be empathetic, professional, and caring
- Keep responses concise but informative
- Use medical terminology appropriately but explain complex terms
- Always prioritize patient safety

LIMITATIONS:
- You cannot diagnose medical conditions
- You cannot prescribe medications
- You cannot replace emergency medical services
- Always recommend consulting healthcare professionals for serious concerns'''
    });
  }

  Future<void> _checkGroqConnection() async {
    try {
      // Test connection with a simple prompt
      await _groqService.sendMessage("Test connection");
      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      print('Groq connection error: $e');
    }
  }

  Future<void> _fetchDoctors() async {
    try {
      final doctors = await _appointmentService.getAllDoctors();
      setState(() {
        // Remove duplicates by ID and filter out inactive doctors
        final uniqueDoctors = <String, Doctor>{};
        for (final doc in doctors) {
          final doctor = Doctor.fromMap(doc);
          if (doctor.id.isNotEmpty && !uniqueDoctors.containsKey(doctor.id)) {
            uniqueDoctors[doctor.id] = doctor;
          }
        }
        _doctors = uniqueDoctors.values.toList();
      });
      print('Fetched ${_doctors.length} unique doctors');
    } catch (e) {
      print('Error fetching doctors: $e');
      _addBotMessage("⚠️ Unable to load doctor information. Please try again later.");
    }
  }

  void _addUserMessage(String message) {
    setState(() {
      _chatMessages.add(chat_model.ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  @override
  dynamic _addBotMessage(dynamic message) {
    setState(() {
      _chatMessages.add(chat_model.ChatMessage(
        text: message.toString(),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    _addUserMessage(message);
    
    setState(() {
      _isTyping = true;
    });

    if (_isBookingMode) {
      await _handleBookingFlow(message);
    } else {
      await _handleGroqMessage(message);
    }
  }

  Future<void> _handleGroqMessage(String message) async {
    if (!_isConnected) {
      _addBotMessage(
        "🔧 I'm having trouble connecting to the Groq AI service. Please check your connection and try again.\n\n"
        "In the meantime, would you like to book an appointment with one of our doctors?"
      );
      return;
    }

    try {
      _conversationHistory.add({
        'role': 'user',
        'content': message,
      });

      // Format conversation for Groq API
      final conversationContext = _conversationHistory
          .map((msg) => "${msg['role']!.toUpperCase()}: ${msg['content']!}")
          .join("\n\n");
      
      final response = await _groqService.sendMessage(conversationContext);
      
      _conversationHistory.add({
        'role': 'assistant',
        'content': response,
      });

      // Check for appointment booking trigger
      if (response.trim() == 'BOOK_APPOINTMENT_TRIGGER') {
        _startBookingFlow();
      } else {
        _addBotMessage(response);
      }

      // Manage conversation history size for optimal performance
      if (_conversationHistory.length > 20) {
        // Keep system message and last 18 messages
        _conversationHistory = [_conversationHistory[0]] + 
                             _conversationHistory.sublist(_conversationHistory.length - 18);
      }

    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      _addBotMessage(
        "🔧 I'm experiencing connection issues with the Groq AI service. This might be due to:\n\n"
        "• Network connectivity\n"
        "• Service overload\n"
        "• API limitations\n\n"
        "Please try again in a moment, or would you like to book an appointment instead?"
      );
      print('Groq API Error: $e');
    }
  }

  void _startBookingFlow() {
    setState(() {
      _isBookingMode = true;
      _bookingStep = 1;
    });
    print('Doctor objects:');
    for (var doc in _doctors) {
      print('id: ${doc.id}, name: ${doc.name}, specialization: ${doc.specialization}');
    }
    if (_doctors.isEmpty) {
      _addBotMessage("⚠️ No doctors are currently available. Please try again later or contact our support team.");
      _resetBookingState();
      return;
    }

    // Show loading message and then display doctor selection dialog
    _addBotMessage("👨‍⚕️ Loading available doctors...");
    
    // Add a small delay to show the loading message
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showDoctorSelectionDialog();
      }
    });
  }

  Future<void> _handleBookingFlow(String message) async {
    switch (_bookingStep) {
      case 1:
        // Doctor selection is now handled by dialog, so we skip to date selection
        await _handleDateSelection(message);
        break;
      case 2:
        await _handleDateSelection(message);
        break;
      case 3:
        await _handleTimeSelection(message);
        break;
      case 4:
        await _handleUserInfo(message);
        break;
      case 5:
        await _handlePhoneCollection(message);
        break;
      default:
        _resetBookingState();
        _addBotMessage("❌ Booking session expired. Please start over by asking to book an appointment.");
    }
  }

  void _showDoctorSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Select Your Doctor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Doctor list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = _doctors[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).pop();
                              _selectDoctor(doctor);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Doctor image
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: accentColor.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: doctor.profileImageUrl != null && 
                                             doctor.profileImageUrl!.isNotEmpty
                                          ? Image.network(
                                              doctor.profileImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: cardColor,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: accentColor,
                                                    size: 30,
                                                  ),
                                                );
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  color: cardColor,
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: cardColor,
                                              child: Icon(
                                                Icons.person,
                                                color: accentColor,
                                                size: 30,
                                              ),
                                            ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  // Doctor info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDoctorName(doctor.name),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          doctor.specialization,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 16,
                                              color: Colors.amber[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              doctor.rating.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: textColor.withOpacity(0.8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (doctor.consultationFee != null) ...[
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.attach_money,
                                                size: 16,
                                                color: Colors.green[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '\$${doctor.consultationFee.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.green[600],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Selection indicator
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: accentColor.withOpacity(0.6),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Cancel button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetBookingState();
                        _addBotMessage("❌ Doctor selection cancelled. How else can I help you?");
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  void _selectDoctor(Doctor doctor) {
    _selectedDoctor = doctor;
    setState(() {
      _bookingStep = 2;
    });
    
    _addBotMessage(
      "✅ Selected: ${_formatDoctorName(_selectedDoctor!.name)} (${_selectedDoctor!.specialization})\n\n"
      "📅 Choose a date for your appointment:"
    );
    
    // Show date selection dialog after a brief delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _showDateSelectionDialog();
      }
    });
  }

  void _showDateSelectionDialog() {
    final today = DateTime.now();
    final maxDate = today.add(const Duration(days: 90)); // 90 days from today
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
                      child: Container(
              constraints: const BoxConstraints(maxHeight: 450, maxWidth: 320), // Made larger again
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Select Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Calendar
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        // Quick selection buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _selectDate(today);
                                },
                                icon: const Icon(Icons.today, size: 14),
                                label: const Text('Today', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _selectDate(today.add(const Duration(days: 1)));
                                },
                                icon: const Icon(Icons.event, size: 14),
                                label: const Text('Tomorrow', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Calendar widget - Made larger again
                        Container(
                          height: 240, // Made even larger
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withOpacity(0.3)),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              // Make calendar readable
                              textTheme: Theme.of(context).textTheme.copyWith(
                                bodyLarge: const TextStyle(fontSize: 12),
                                bodyMedium: const TextStyle(fontSize: 11),
                                titleMedium: const TextStyle(fontSize: 13),
                                titleSmall: const TextStyle(fontSize: 11),
                              ),
                            ),
                            child: CalendarDatePicker(
                              initialDate: today,
                              firstDate: today,
                              lastDate: maxDate,
                              onDateChanged: (date) {
                                Navigator.of(context).pop();
                                _selectDate(date);
                              },
                              selectableDayPredicate: (date) {
                                // Check if the date is not in the past
                                return date.isAfter(today.subtract(const Duration(days: 1)));
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Cancel button
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetBookingState();
                        _addBotMessage("❌ Date selection cancelled. How else can I help you?");
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  void _selectDate(DateTime date) async {
    print('📅 Date selected: ${DateFormat('yyyy-MM-dd').format(date)}');
    
    _selectedDate = date;
    setState(() {
      _bookingStep = 3; // Move to time selection step
    });
    
    _addBotMessage(
      "✅ Date selected: ${DateFormat('EEEE, MMM dd, yyyy').format(date)}\n\n"
      "⏰ Loading available time slots..."
    );
    
    // Fetch available slots and show time selection dialog
    await _fetchAvailableSlots();
    
    if (mounted) {
      if (_availableSlots.isNotEmpty) {
        print('✅ Found ${_availableSlots.length} slots, showing time dialog');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showTimeSelectionDialog();
          }
        });
      } else {
        // If no slots available, show a message and allow retry
        print('❌ No slots found for date: ${DateFormat('yyyy-MM-dd').format(date)}');
        _addBotMessage(
          "❌ No available slots on ${DateFormat('EEEE, MMM dd, yyyy').format(date)}.\n\n"
          "Please try a different date."
        );
        // Reset to date selection step
        setState(() {
          _bookingStep = 2;
        });
        // Don't automatically show dialog again - let user choose
      }
    }
  }

  Future<void> _handleDoctorSelection(String message) async {
    // This method is now deprecated since we use dialog selection
    // Keeping it for backward compatibility but it won't be called
    try {
      final selection = int.parse(message.trim());
      if (selection > 0 && selection <= _doctors.length) {
        _selectedDoctor = _doctors[selection - 1];
        setState(() {
          _bookingStep = 2;
        });
        
        _addBotMessage(
          "✅ Selected: ${_formatDoctorName(_selectedDoctor!.name)} (${_selectedDoctor!.specialization})\n\n"
          "📅 Choose a date:\n"
          "• Type 'today' for today's appointment\n"
          "• Type 'tomorrow' for tomorrow\n"
          "• Use format: YYYY-MM-DD (e.g., 2024-12-25)\n"
          "• Type 'cancel' to cancel booking"
        );
      } else {
        _addBotMessage("❌ Please choose a valid number between 1 and ${_doctors.length}, or type 'cancel' to exit.");
      }
    } catch (e) {
      _addBotMessage("❌ Please enter a valid number (1-${_doctors.length}) or 'cancel' to exit.");
    }
  }

  Future<void> _handleDateSelection(String message) async {
    final input = message.trim().toLowerCase();
    
    if (input == 'cancel') {
      _resetBookingState();
      _addBotMessage("❌ Booking cancelled. How else can I help you?");
      return;
    }
    
    DateTime? selectedDate;
    
    try {
      if (input == 'today') {
        selectedDate = DateTime.now();
      } else if (input == 'tomorrow') {
        selectedDate = DateTime.now().add(const Duration(days: 1));
      } else {
        selectedDate = DateTime.parse(message.trim());
      }
      
      // Check if date is in the past
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final selectedStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      
      if (selectedStart.isBefore(todayStart)) {
        _addBotMessage("❌ Cannot book appointments for past dates. Please choose today or a future date.");
        return;
      }
      
      // Check if date is too far in the future (e.g., more than 90 days)
      if (selectedDate.isAfter(DateTime.now().add(const Duration(days: 90)))) {
        _addBotMessage("❌ Cannot book appointments more than 90 days in advance. Please choose an earlier date.");
        return;
      }
      
      _selectedDate = selectedDate;
      await _fetchAvailableSlots();
      
    } catch (e) {
      _addBotMessage(
        "❌ Invalid date format. Please use:\n"
        "• 'today' or 'tomorrow'\n"
        "• YYYY-MM-DD format (e.g., 2024-12-25)\n"
        "• 'cancel' to exit booking"
      );
    }
  }

  Future<void> _fetchAvailableSlots() async {
    if (_selectedDoctor == null || _selectedDate == null) {
      print('❌ _fetchAvailableSlots: Doctor or date is null');
      print('Doctor: ${_selectedDoctor?.name}');
      print('Date: $_selectedDate');
      return;
    }
    
    try {
      setState(() {
        _isTyping = true;
      });
      
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      print('🔍 Fetching slots for doctor: ${_selectedDoctor!.name} (${_selectedDoctor!.id})');
      print('🔍 Date: $dateString');
      
      final slots = await _appointmentService.fetchAvailableSlots(
        _selectedDoctor!.id,
        dateString,
      );
      
      print('📅 Fetched ${slots.length} slots: $slots');
      
      setState(() {
        _availableSlots = slots;
        _isTyping = false;
      });
      
      if (_availableSlots.isEmpty) {
        print('❌ No slots available for the selected date');
        // Don't show message here - let _selectDate handle it
      } else {
        print('✅ Slots available: ${_availableSlots.length}');
      }
    } catch (e) {
      print('❌ Error in _fetchAvailableSlots: $e');
      setState(() {
        _isTyping = false;
      });
      _addBotMessage("❌ Error checking availability. Please try again or contact support.");
      _resetBookingState();
    }
  }

  void _showTimeSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Time Slot',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate!),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Time slots list
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: _availableSlots.isEmpty
                        ? const Center(
                            child: Text(
                              'No available slots for this date',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, // Changed from 2 to 3 for smaller buttons
                              childAspectRatio: 1.8, // Made more compact
                              crossAxisSpacing: 8, // Reduced spacing
                              mainAxisSpacing: 8, // Reduced spacing
                            ),
                            itemCount: _availableSlots.length,
                            itemBuilder: (context, index) {
                              final slot = _availableSlots[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8), // Smaller radius
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6, // Reduced blur
                                      offset: const Offset(0, 1), // Reduced offset
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8), // Smaller radius
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _selectTimeSlot(slot);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14), // Reduced padding
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          
                                          const SizedBox(height: 4), // Reduced spacing
                                          Text(
                                            DateFormat('h:mm a').format(DateFormat('HH:mm').parse(slot)),
                                            style: TextStyle(
                                              fontSize: 12, // Smaller font
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _bookingStep = 2; // Go back to date selection
                            });
                            _showDateSelectionDialog();
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Date'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _resetBookingState();
                            _addBotMessage("❌ Time selection cancelled. How else can I help you?");
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectTimeSlot(String timeSlot) {
    _selectedSlot = timeSlot;
    setState(() {
      _bookingStep = 4;
    });
    
    _addBotMessage(
      "✅ Time confirmed: $timeSlot\n\n"
      "👤 Please provide your Full name:"
    );
  }

  Future<void> _handleTimeSelection(String message) async {
    // This method is now deprecated since we use dialog selection
    // Keeping it for backward compatibility but it won't be called
    final input = message.trim().toLowerCase();
    
    if (input == 'cancel') {
      _resetBookingState();
      _addBotMessage("❌ Booking cancelled. How else can I help you?");
      return;
    }
    
    if (input == 'back') {
      setState(() {
        _bookingStep = 2;
      });
      _addBotMessage("📅 Please choose a different date:");
      return;
    }
    
    try {
      final selection = int.parse(message.trim());
      if (selection > 0 && selection <= _availableSlots.length) {
        _selectedSlot = _availableSlots[selection - 1];
        setState(() {
          _bookingStep = 4;
        });
        
        _addBotMessage(
          "✅ Time confirmed: $_selectedSlot\n\n"
          "👤 Please provide your Full name:"
        );
      } else {
        _addBotMessage("❌ Please choose a number between 1 and ${_availableSlots.length}");
      }
    } catch (e) {
      _addBotMessage("❌ Please enter a valid number (1-${_availableSlots.length})");
    }
  }

  Future<void> _handleUserInfo(String message) async {
    final name = message.trim();
    
    if (name.toLowerCase() == 'cancel') {
      _resetBookingState();
      _addBotMessage("❌ Booking cancelled. How else can I help you?");
      return;
    }
    
    if (name.length < 2) {
      _addBotMessage("❌ Please provide a valid full name (at least 2 characters).");
      return;
    }
    
    // Basic name validation
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      _addBotMessage("❌ Please provide a valid name using only letters and spaces.");
      return;
    }
    
    _userName = name;
    setState(() {
      _bookingStep = 5;
    });
    
    _addBotMessage(
      "✅ Thank you, $_userName!\n\n"
      "📱 Please provide your **phone number** (with country code if international):"
    );
  }

  Future<void> _handlePhoneCollection(String message) async {
    final input = message.trim();
    
    if (input.toLowerCase() == 'cancel') {
      _resetBookingState();
      _addBotMessage("❌ Booking cancelled. How else can I help you?");
      return;
    }
    
    // Clean phone number (keep only digits and +)
    final phone = input.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (phone.length < 10) {
      _addBotMessage("❌ Please provide a valid phone number (at least 10 digits).");
      return;
    }
    
    if (phone.length > 15) {
      _addBotMessage("❌ Phone number is too long. Please provide a valid phone number.");
      return;
    }
    
    _userPhone = phone;
    await _finalizeBooking();
  }

  Future<void> _finalizeBooking() async {
    try {
      setState(() {
        _isTyping = true;
      });
      
      _addBotMessage("⏳ Processing your appointment...\nPlease wait while I confirm your booking.");
      
      final appointmentId = await _appointmentService.bookAppointment(
        doctorId: _selectedDoctor!.id,
        userName: _userName,
        userPhone: _userPhone,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        time: _selectedSlot!,
      );

      // Schedule reminder notification
      try {
        final appointmentDateTime = DateFormat('yyyy-MM-dd HH:mm').parse(
          '${DateFormat('yyyy-MM-dd').format(_selectedDate!)} $_selectedSlot'
        );
        final reminderTime = appointmentDateTime.subtract(const Duration(minutes: 15));
        
        await _notificationService.scheduleNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🩺 Appointment Reminder',
          body: 'Your appointment is in 15 minutes with ${_formatDoctorName(_selectedDoctor!.name)}',
          scheduledDate: reminderTime,
        );
      } catch (e) {
        print('Error scheduling notification: $e');
      }

      _addBotMessage(
        "🎉 APPOINTMENT SUCCESSFULLY BOOKED!\n\n"
        "📋 Appointment Details:\n"
        "🆔 ID: $appointmentId\n"
        "👨‍⚕️ Doctor: ${_formatDoctorName(_selectedDoctor!.name)}\n"
        "🏥 Specialization: ${_selectedDoctor!.specialization}\n"
        "📅 Date: ${DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate!)}\n"
        "🕐 Time: $_selectedSlot\n"
        "👤 Patient: $_userName\n"
        "📱 Phone: $_userPhone\n\n"
        "📱 Reminder: You'll receive a notification 15 minutes before your appointment.\n\n"
        "💡 Important:\n"
        "• Please arrive 10 minutes early\n"
        "• Bring a valid ID and insurance card\n"
        "• Contact us if you need to reschedule\n\n"
        "Is there anything else I can help you with today?"
      );

      _resetBookingState();

    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _addBotMessage(
        "❌ Booking Error:** ${e.toString()}\n\n"
        "Please try again or contact our support team for assistance."
      );
      _resetBookingState();
    }
  }

  void _resetBookingState() {
    setState(() {
      _isBookingMode = false;
      _bookingStep = 0;
      _selectedDoctor = null;
      _selectedDate = null;
      _availableSlots.clear();
      _selectedSlot = null;
      _userName = '';
      _userPhone = '';
      _isTyping = false;
    });
  }

  void _restartChat() {
    setState(() {
      _chatMessages.clear();
      _conversationHistory.clear();
      _resetBookingState();
    });
    _initializeChat();
    _checkGroqConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isConnected ? accentColor : Colors.red[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isConnected ? accentColor : Colors.red[400]!).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Medical AI Assistant',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            tooltip: 'Admin Panel',
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Register Doctor',
            color: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DoctorRegistrationScreen()),
              );
              _fetchDoctors();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _restartChat,
            tooltip: 'Restart Chat',
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.update_outlined),
            onPressed: _initializeSampleDataIfNeeded,
            tooltip: 'Update Sample Data',
            color: Colors.white,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _isConnected ? accentColor.withOpacity(0.1) : Colors.red[50],
              border: Border(
                bottom: BorderSide(
                  color: _isConnected ? accentColor.withOpacity(0.2) : Colors.red[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? accentColor : Colors.red[400],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? 'Connected to Groq AI' : 'Connection Error',
                  style: TextStyle(
                    color: _isConnected ? accentColor : Colors.red[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_isBookingMode) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Booking Step $_bookingStep/5',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Chat area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20.0),
              itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _chatMessages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_chatMessages[index]);
              },
            ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -4),
                  blurRadius: 20,
                  color: Colors.black.withOpacity(0.08),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: _isBookingMode 
                            ? 'Follow the booking steps above...'
                            : 'Ask about your health or book an appointment...',
                          hintStyle: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          prefixIcon: Icon(
                            _isBookingMode ? Icons.event_outlined : Icons.chat_bubble_outline,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        onSubmitted: (message) {
                          if (message.trim().isNotEmpty && !_isTyping) {
                            _processMessage(message);
                            _messageController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _isTyping 
                        ? null 
                        : LinearGradient(
                            colors: [accentColor, accentColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                      color: _isTyping ? Colors.grey[300] : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _isTyping ? null : [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isTyping ? null : () {
                          final message = _messageController.text.trim();
                          if (message.isNotEmpty) {
                            _processMessage(message);
                            _messageController.clear();
                          }
                        },
                        child: Center(
                          child: _isTyping 
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.6)),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(chat_model.ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          decoration: BoxDecoration(
            gradient: message.isUser 
              ? LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
            color: message.isUser ? null : cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(message.isUser ? 20 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 8,
                color: Colors.black.withOpacity(0.08),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : textColor,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isUser) ...[
                    Icon(
                      Icons.psychology_outlined, 
                      size: 14, 
                      color: accentColor.withOpacity(0.7)
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Groq AI',
                      style: TextStyle(
                        color: accentColor.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: message.isUser 
                        ? Colors.white.withOpacity(0.8) 
                        : textColor.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 8,
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined, 
              color: accentColor, 
              size: 18
            ),
            const SizedBox(width: 10),
            Text(
              'AI is thinking',
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontStyle: FontStyle.italic,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}