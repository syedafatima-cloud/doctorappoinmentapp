import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatConsultationPage extends StatefulWidget {
  final String appointmentId;
  final String doctorId;
  final String doctorName;
  final String patientName;
  final String patientId; // You might want to add user authentication

  const ChatConsultationPage({
    super.key,
    required this.appointmentId,
    required this.doctorId,
    required this.doctorName,
    required this.patientName,
    required this.patientId,
  });

  @override
  State<ChatConsultationPage> createState() => _ChatConsultationPageState();
}

class _ChatConsultationPageState extends State<ChatConsultationPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSending = false;
  final bool _isTyping = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();

    // Mark appointment as active when chat starts
    _updateAppointmentStatus('active');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    try {
      // Add message to chat collection
      await _firestore
          .collection('consultations')
          .doc(widget.appointmentId)
          .collection('messages')
          .add({
        'senderId': widget.patientId,
        'senderName': widget.patientName,
        'senderType': 'patient',
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update consultation metadata
      await _firestore
          .collection('consultations')
          .doc(widget.appointmentId)
          .set({
        'appointmentId': widget.appointmentId,
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageFrom': 'patient',
        'status': 'active',
        'unreadCount': FieldValue.increment(1),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send notification to doctor
      await _sendNotificationToDoctor(messageText);

      // Auto scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendNotificationToDoctor(String message) async {
    try {
      await _firestore.collection('doctor_notifications').add({
        'doctorId': widget.doctorId,
        'appointmentId': widget.appointmentId,
        'patientName': widget.patientName,
        'patientId': widget.patientId,
        'type': 'new_message',
        'title': 'New Message from ${widget.patientName}',
        'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'appointmentId': widget.appointmentId,
          'chatId': widget.appointmentId,
          'patientName': widget.patientName,
        }
      });
    } catch (e) {
      print('Error sending notification to doctor: $e');
    }
  }

  Future<void> _updateAppointmentStatus(String status) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating appointment status: $e');
    }
  }

  Future<void> _endConsultation() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End Consultation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to end this consultation? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'End',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      try {
        // Update consultation status
        await _firestore
            .collection('consultations')
            .doc(widget.appointmentId)
            .update({
          'status': 'completed',
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': 'patient',
        });

        // Update appointment status
        await _updateAppointmentStatus('completed');

        // Notify doctor
        await _firestore.collection('doctor_notifications').add({
          'doctorId': widget.doctorId,
          'appointmentId': widget.appointmentId,
          'patientName': widget.patientName,
          'patientId': widget.patientId,
          'type': 'consultation_ended',
          'title': 'Consultation Ended',
          'body': '${widget.patientName} has ended the consultation',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending consultation: $e'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    }
  }

  Widget _buildMessage(Map<String, dynamic> messageData, bool isMe) {
    final timestamp = messageData['timestamp'] as Timestamp?;
    final timeString = timestamp != null
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF7E57C2),
              child: Text(
                widget.doctorName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFFC5CAE9)],
                      )
                    : null,
                color: isMe ? null : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      messageData['senderName'] ?? 'Doctor',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 2),
                  Text(
                    messageData['message'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey.shade300,
              child: Text(
                widget.patientName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E57C2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(
                Icons.local_hospital,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Chat Consultation',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'end') {
                _endConsultation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'end',
                child: Row(
                  children: [
                    Icon(Icons.call_end, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('End Consultation'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Chat Messages
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('consultations')
                    .doc(widget.appointmentId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading messages',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7E57C2),
                      ),
                    );
                  }

                  final messages = snapshot.data?.docs ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start your consultation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send a message to begin chatting with ${widget.doctorName}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Auto scroll to bottom when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageData = messages[index].data() as Map<String, dynamic>;
                      final isMe = messageData['senderType'] == 'patient';
                      return _buildMessage(messageData, isMe);
                    },
                  );
                },
              ),
            ),

            // Message Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: TextStyle(fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7E57C2), Color(0xFFC5CAE9)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7E57C2).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isSending
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}