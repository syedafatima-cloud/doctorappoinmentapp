import 'package:doctorappoinmentapp/models/chat_model.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Enum for message types
enum MessageType { text, image, voice }

// Extended message class to add functionality while keeping your model
class ExtendedMessage {
  final ChatMessage chatMessage;
  final MessageType messageType;
  final String? imagePath;
  final String? audioPath;

  ExtendedMessage({
    required this.chatMessage,
    this.messageType = MessageType.text,
    this.imagePath,
    this.audioPath,
  });
}

class TalkToDoctorScreen extends StatefulWidget {
  final bool isDarkMode;
  
  const TalkToDoctorScreen({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<TalkToDoctorScreen> createState() => _TalkToDoctorScreenState();
}

class _TalkToDoctorScreenState extends State<TalkToDoctorScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ExtendedMessage> _messages = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String? _lastAudioPath;
  bool _isRecording = false;
  final bool _isDoctorOnline = true;
  bool _isPlayingAudio = false;
  String? _currentPlayingAudio;
  
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  late AnimationController _recordingAnimationController;
  late Animation<double> _recordingAnimation;

  // Theme colors based on current mode
  Color get primaryColor => widget.isDarkMode ? const Color(0xFF7E57C2) : const Color(0xFFC5CAE9);
  Color get accentColor => widget.isDarkMode ? const Color(0xFFC5CAE9) : const Color(0xFF7E57C2);
  Color get backgroundColor => widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAF8F5);
  Color get cardColor => widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFEDE7F6);
  Color get textColor => widget.isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF424242);
  Color get buttonColor => widget.isDarkMode ? const Color(0xFF7E57C2) : const Color(0xFFD1C4E9);

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _recordingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _recordingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Add welcome message
    _addMessage(ExtendedMessage(
      chatMessage: ChatMessage(
        text: "Hello! I'm Dr. Sarah, your free consultation doctor. How can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
      messageType: MessageType.text,
    ));

    _requestPermissions();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _recordingAnimationController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
  await Permission.microphone.request();
  await Permission.storage.request();
  await Permission.camera.request(); // Add this line
}

  void _addMessage(ExtendedMessage message) {
    setState(() {
      _messages.add(message);
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

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = ExtendedMessage(
      chatMessage: ChatMessage(
        text: _messageController.text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ),
      messageType: MessageType.text,
    );

    _addMessage(message);
    _messageController.clear();

    // Simulate doctor response
    _simulateDoctorResponse();
  }

  void _simulateDoctorResponse() {
    Future.delayed(const Duration(seconds: 2), () {
      final responses = [
        "Thank you for sharing that with me. Can you provide more details about when this started?",
        "I understand your concern. Based on what you've described, here are some recommendations...",
        "That's a common issue. Let me suggest some steps you can take to address this.",
        "It's good that you're being proactive about your health. Have you experienced this before?",
        "I'd recommend monitoring this for a few days. If symptoms persist, please consider visiting a clinic.",
      ];

      final response = ExtendedMessage(
        chatMessage: ChatMessage(
          text: responses[DateTime.now().millisecond % responses.length],
          isUser: false,
          timestamp: DateTime.now(),
        ),
        messageType: MessageType.text,
      );

      _addMessage(response);
    });
  }

  void _startVoiceCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Voice Call', style: TextStyle(color: textColor)),
        content: Text('Connecting to Dr. Sarah...', style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: accentColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Voice call feature coming soon!');
            },
            child: Text('Call', style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }

  void _startVideoCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Video Call', style: TextStyle(color: textColor)),
        content: Text('Start video consultation with Dr. Sarah?', style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: accentColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Video call feature coming soon!');
            },
            child: Text('Start', style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }

  void _sendImage() async {
  showModalBottomSheet(
    context: context,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Image Source',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImageSourceOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              _buildImageSourceOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}
Widget _buildImageSourceOption({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: buttonColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: accentColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickImage(ImageSource source) async {
  Navigator.pop(context); // Close the bottom sheet
  
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: source,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  
  if (image != null) {
    final message = ExtendedMessage(
      chatMessage: ChatMessage(
        text: source == ImageSource.camera ? 'Photo taken' : 'Image shared',
        isUser: true,
        timestamp: DateTime.now(),
      ),
      messageType: MessageType.image,
      imagePath: image.path,
    );
    _addMessage(message);

    // Simulate doctor response to image
    Future.delayed(const Duration(seconds: 2), () {
      final response = ExtendedMessage(
        chatMessage: ChatMessage(
          text: source == ImageSource.camera 
              ? "Thank you for taking that photo. I can see the area clearly. Let me provide some guidance based on what I observe."
              : "Thank you for sharing the image. I can see what you're referring to. Let me provide some guidance based on what I observe.",
          isUser: false,
          timestamp: DateTime.now(),
        ),
        messageType: MessageType.text,
      );
      _addMessage(response);
    });
  }
}
  Future<String> _getAudioFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${directory.path}/$fileName';
  }

  void _toggleVoiceRecording() async {
    if (!_isRecording) {
      // Start recording
      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          _showSnackBar('Microphone permission is required for voice messages!');
          return;
        }
      }

      try {
        final path = await _getAudioFilePath();
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
          _lastAudioPath = path;
        });
        
        _recordingAnimationController.repeat(reverse: true);
        _showSnackBar('Recording voice message...');
      } catch (e) {
        _showSnackBar('Failed to start recording: ${e.toString()}');
      }
    } else {
      // Stop recording
      try {
        final path = await _audioRecorder.stop();
        _recordingAnimationController.stop();
        _recordingAnimationController.reset();
        
        setState(() {
          _isRecording = false;
        });
        
        if (path != null && path.isNotEmpty) {
          _showSnackBar('Voice recording completed');
          
          final message = ExtendedMessage(
            chatMessage: ChatMessage(
              text: 'Voice message',
              isUser: true,
              timestamp: DateTime.now(),
            ),
            messageType: MessageType.voice,
            audioPath: path,
          );
          _addMessage(message);

          // Simulate doctor response to voice message
          Future.delayed(const Duration(seconds: 3), () {
            final response = ExtendedMessage(
              chatMessage: ChatMessage(
                text: "I've listened to your voice message. Thank you for explaining your symptoms clearly. Let me provide some guidance based on what you've shared.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
              messageType: MessageType.text,
            );
            _addMessage(response);
          });
        } else {
          _showSnackBar('Recording failed. Please try again.');
        }
      } catch (e) {
        _showSnackBar('Failed to stop recording: ${e.toString()}');
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  Future<void> _playAudio(String audioPath) async {
    try {
      if (_isPlayingAudio && _currentPlayingAudio == audioPath) {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
          _currentPlayingAudio = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(audioPath));
        setState(() {
          _isPlayingAudio = true;
          _currentPlayingAudio = audioPath;
        });

        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _isPlayingAudio = false;
            _currentPlayingAudio = null;
          });
        });
      }
    } catch (e) {
      _showSnackBar('Failed to play audio: ${e.toString()}');
      setState(() {
        _isPlayingAudio = false;
        _currentPlayingAudio = null;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dr. Sarah Johnson',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isDoctorOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isDoctorOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _startVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: _startVideoCall,
          ),
        ],
      ),
      body: Column(
        children: [
          // Free consultation banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, accentColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Free Consultation - No charges applied',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Message input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? cardColor : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: accentColor),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? backgroundColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _recordingAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _recordingAnimation.value : 1.0,
                      child: GestureDetector(
                        onTap: _toggleVoiceRecording,
                        onLongPress: _toggleVoiceRecording,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isRecording ? Colors.red : accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ExtendedMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.chatMessage.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.chatMessage.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_hospital,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.chatMessage.isUser 
                    ? accentColor
                    : cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.messageType == MessageType.image && message.imagePath != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(message.imagePath!)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (message.messageType == MessageType.voice && message.audioPath != null)
                    GestureDetector(
                      onTap: () => _playAudio(message.audioPath!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: message.chatMessage.isUser 
                              ? Colors.white.withOpacity(0.2)
                              : accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (_isPlayingAudio && _currentPlayingAudio == message.audioPath)
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: message.chatMessage.isUser ? Colors.white : accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.graphic_eq,
                              color: message.chatMessage.isUser ? Colors.white : accentColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Voice message',
                              style: TextStyle(
                                color: message.chatMessage.isUser ? Colors.white : textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (message.messageType != MessageType.image)
                    Text(
                      message.chatMessage.text,
                      style: TextStyle(
                        color: message.chatMessage.isUser ? Colors.white : textColor,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.chatMessage.timestamp),
                    style: TextStyle(
                      color: message.chatMessage.isUser 
                          ? Colors.white70 
                          : textColor.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.chatMessage.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: textColor,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}