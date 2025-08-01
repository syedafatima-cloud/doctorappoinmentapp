import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DoctorChatManagementPage extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorChatManagementPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorChatManagementPage> createState() => _DoctorChatManagementPageState();
}

class _DoctorChatManagementPageState extends State<DoctorChatManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // all, active, pending, completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7E57C2),
        elevation: 0,
        title: const Text(
          'Patient Consultations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('doctor_notifications')
                .where('doctorId', isEqualTo: widget.doctorId)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () => _showNotifications(),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            height: 60,
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterTab('all', 'All'),
                _buildFilterTab('active', 'Active'),
                _buildFilterTab('pending', 'Pending'),
                _buildFilterTab('completed', 'Completed'),
              ],
            ),
          ),
          
          // Consultations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getConsultationsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading consultations',
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

                final consultations = snapshot.data?.docs ?? [];

                if (consultations.isEmpty) {
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
                          'No consultations found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patient consultations will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: consultations.length,
                  itemBuilder: (context, index) {
                    final consultation = consultations[index];
                    final data = consultation.data() as Map<String, dynamic>;
                    return _buildConsultationCard(consultation.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF7E57C2) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF7E57C2) : Colors.grey.shade600,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getConsultationsStream() {
    Query query = _firestore
        .collection('consultations')
        .where('doctorId', isEqualTo: widget.doctorId);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.orderBy('lastMessageTime', descending: true).snapshots();
  }

  Widget _buildConsultationCard(String consultationId, Map<String, dynamic> data) {
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final lastMessage = data['lastMessage'] ?? '';
    final lastMessageTime = data['lastMessageTime'] as Timestamp?;
    final status = data['status'] ?? 'pending';
    final unreadCount = data['unreadCount'] ?? 0;
    final lastMessageFrom = data['lastMessageFrom'] ?? '';

    final timeString = lastMessageTime != null
        ? _formatTime(lastMessageTime.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          onTap: () => _openChatForConsultation(consultationId, data),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Patient Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF7E57C2).withOpacity(0.1),
                  child: Text(
                    patientName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF7E57C2),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Chat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ),
                          if (timeString.isNotEmpty)
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (lastMessageFrom == 'doctor')
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                          if (lastMessageFrom == 'doctor')
                            const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: lastMessageFrom == 'patient' && unreadCount > 0
                                    ? const Color(0xFF424242)
                                    : Colors.grey.shade600,
                                fontWeight: lastMessageFrom == 'patient' && unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatusChip(status),
                          const Spacer(),
                          if (unreadCount > 0 && lastMessageFrom == 'patient')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7E57C2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status) {
      case 'active':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        displayText = 'Active';
        break;
      case 'completed':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        displayText = 'Completed';
        break;
      case 'pending':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        displayText = 'Pending';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(dateTime);
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  void _openChatForConsultation(String consultationId, Map<String, dynamic> data) {
    // Mark messages as read
    _markMessagesAsRead(consultationId);

    // Navigate to doctor chat screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DoctorChatPage(
          consultationId: consultationId,
          patientName: data['patientName'] ?? 'Patient',
          patientId: data['patientId'] ?? '',
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
          appointmentId: data['appointmentId'] ?? consultationId,
        ),
      ),
    );
  }

  Future<void> _markMessagesAsRead(String consultationId) async {
    try {
      // Reset unread count
      await _firestore.collection('consultations').doc(consultationId).update({
        'unreadCount': 0,
      });

      // Mark all unread messages as read
      final unreadMessages = await _firestore
          .collection('consultations')
          .doc(consultationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderType', isEqualTo: 'patient')
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DoctorNotificationsBottomSheet(
        doctorId: widget.doctorId,
      ),
    );
  }
}

// Doctor Chat Page for responding to patients
class DoctorChatPage extends StatefulWidget {
  final String consultationId;
  final String patientName;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String appointmentId;

  const DoctorChatPage({
    super.key,
    required this.consultationId,
    required this.patientName,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.appointmentId,
  });

  @override
  State<DoctorChatPage> createState() => _DoctorChatPageState();
}

class _DoctorChatPageState extends State<DoctorChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
          .doc(widget.consultationId)
          .collection('messages')
          .add({
        'senderId': widget.doctorId,
        'senderName': widget.doctorName,
        'senderType': 'doctor',
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update consultation metadata
      await _firestore
          .collection('consultations')
          .doc(widget.consultationId)
          .update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageFrom': 'doctor',
        'status': 'active',
      });

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
              child: Text(
                widget.patientName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Patient Consultation',
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
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('consultations')
                  .doc(widget.consultationId)
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
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the consultation with ${widget.patientName}',
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
                    final isMe = messageData['senderType'] == 'doctor';
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
                          hintText: 'Type your response...',
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
    );
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
                      messageData['senderName'] ?? 'Patient',
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
          ],
        ],
      ),
    );
  }
}

// Notifications Bottom Sheet
class DoctorNotificationsBottomSheet extends StatelessWidget {
  final String doctorId;

  const DoctorNotificationsBottomSheet({
    super.key,
    required this.doctorId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _markAllAsRead(context),
                  child: const Text('Mark all as read'),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('doctor_notifications')
                  .where('doctorId', isEqualTo: doctorId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading notifications'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data?.docs ?? [];

                if (notifications.isEmpty) {
                  return const Center(
                    child: Text('No notifications'),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final data = notification.data() as Map<String, dynamic>;
                    return _buildNotificationItem(context, notification.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, String notificationId, Map<String, dynamic> data) {
    final isRead = data['isRead'] ?? false;
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final type = data['type'] ?? '';

    final timeString = createdAt != null
        ? DateFormat('MMM dd, HH:mm').format(createdAt.toDate())
        : '';

    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'new_message':
        iconData = Icons.message;
        iconColor = Colors.blue;
        break;
      case 'consultation_ended':
        iconData = Icons.call_end;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      color: isRead ? Colors.white : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty)
              Text(
                body,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (timeString.isNotEmpty)
              Text(
                timeString,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        onTap: () {
          if (!isRead) {
            _markAsRead(notificationId);
          }
          Navigator.of(context).pop();
          // Handle notification tap based on type
        },
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('doctor_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('doctor_notifications')
          .where('doctorId', isEqualTo: doctorId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}