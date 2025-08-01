import 'package:doctorappoinmentapp/screens/contact_us_screen.dart';
import 'package:doctorappoinmentapp/screens/faq_screen.dart';
import 'package:doctorappoinmentapp/screens/live_chat_screen.dart';
import 'package:doctorappoinmentapp/screens/privacy_policy_screen.dart';
import 'package:doctorappoinmentapp/screens/terms_of_service_screen.dart';
import 'package:doctorappoinmentapp/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool isDarkMode = false;
  bool notificationsEnabled = true;
  bool locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSettings();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  Future<void> _loadSettings() async {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = themeManager.isDarkMode;
      notificationsEnabled = prefs.getBool('notifications') ?? true;
      locationEnabled = prefs.getBool('location') ?? false;
    });
  }

  Future<void> _saveThemePreference(bool value) async {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    await themeManager.setTheme(value);
    setState(() {
      isDarkMode = value;
    });
    _showSnackBar(value ? 'Dark theme enabled' : 'Light theme enabled');
  }

  Future<void> _saveNotificationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    setState(() {
      notificationsEnabled = value;
    });
    _showSnackBar(value ? 'Notifications enabled' : 'Notifications disabled');
  }

  Future<void> _saveLocationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location', value);
    setState(() {
      locationEnabled = value;
    });
    _showSnackBar(value ? 'Location access enabled' : 'Location access disabled');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7E57C2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _bookEmergencyAppointment() async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.red, size: 12),
            const SizedBox(width: 9),
            const Text(
              'Emergency Booking',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 18, // You can change this size as needed
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Are you experiencing a medical emergency?'),
            SizedBox(height: 14),
            Text(
              'For immediate life-threatening emergencies, please call 1122 or go to the nearest emergency room.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 14),
            Text('For urgent but non-life-threatening conditions, we can book you an emergency appointment.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEmergencyBookingForm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Book Emergency', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

  void _showEmergencyBookingForm() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController symptomsController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Emergency Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: symptomsController,
                  decoration: const InputDecoration(
                    labelText: 'Describe your symptoms',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSnackBar('Emergency appointment request submitted. You will be contacted within 5 minutes.');
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _callMedicalHelpline() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+923001234567');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showSnackBar('Unable to make phone call. Please dial +92-300-1234567 manually.');
    }
  }

  void _openLiveChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LiveChatScreen()),
    );
  }

  Future<void> _openEmailSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@doctorapp.com',
      query: 'subject=Medical Support Query',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showSnackBar('Unable to open email. Please email us at support@doctorapp.com');
    }
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Color(0xFF7E57C2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Medical Support'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How can we help you today?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _buildSupportOption(
                icon: Icons.medical_services,
                title: 'Book Emergency Appointment',
                subtitle: 'Get immediate medical attention',
                onTap: () {
                  Navigator.of(context).pop();
                  _bookEmergencyAppointment();
                },
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: Icons.phone,
                title: 'Call Medical Helpline',
                subtitle: '24/7 medical support: +92-300-1234567',
                onTap: () {
                  Navigator.of(context).pop();
                  _callMedicalHelpline();
                },
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: Icons.chat,
                title: 'Live Chat Support',
                subtitle: 'Chat with our medical team',
                onTap: () {
                  Navigator.of(context).pop();
                  _openLiveChat();
                },
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: Icons.email,
                title: 'Email Support',
                subtitle: 'Send us your medical query',
                onTap: () {
                  Navigator.of(context).pop();
                  _openEmailSupport();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFAQ() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FAQScreen()),
    );
  }

  void _showContactUs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactUsScreen()),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  void _showTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF7E57C2), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF7E57C2), size: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFC5CAE9).withOpacity(0.3),
                      const Color(0xFFEDE7F6).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC5CAE9).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF7E57C2).withOpacity(0.1),
                        border: Border.all(
                          color: const Color(0xFF7E57C2).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.person, size: 30, color: Color(0xFF7E57C2)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome User',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your app preferences',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Preferences Section
              _buildSectionHeader('Preferences', Icons.tune),
              const SizedBox(height: 16),
              
              _buildSettingTile(
                icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                title: 'Dark Mode',
                subtitle: isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: _saveThemePreference,
                  activeColor: const Color(0xFF7E57C2),
                ),
              ),
              
              _buildSettingTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: notificationsEnabled ? 'Receive app notifications' : 'Notifications disabled',
                trailing: Switch(
                  value: notificationsEnabled,
                  onChanged: _saveNotificationPreference,
                  activeColor: const Color(0xFF7E57C2),
                ),
              ),
              
              _buildSettingTile(
                icon: Icons.location_on_outlined,
                title: 'Location Services',
                subtitle: locationEnabled ? 'Find nearby healthcare' : 'Location access disabled',
                trailing: Switch(
                  value: locationEnabled,
                  onChanged: _saveLocationPreference,
                  activeColor: const Color(0xFF7E57C2),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Support Section
              _buildSectionHeader('Support & Help', Icons.help_outline),
              const SizedBox(height: 16),
              
              _buildSettingTile(
                icon: Icons.medical_services,
                title: 'Medical Support',
                subtitle: '24/7 emergency and appointment help',
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF7E57C2), size: 16),
                onTap: _showSupportDialog,
              ),
              
              _buildSettingTile(
                icon: Icons.quiz_outlined,
                title: 'FAQ',
                subtitle: 'Frequently asked questions',
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF7E57C2), size: 16),
                onTap: _showFAQ,
              ),
              
              _buildSettingTile(
                icon: Icons.contact_support_outlined,
                title: 'Contact Us',
                subtitle: 'Get in touch with our team',
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF7E57C2), size: 16),
                onTap: _showContactUs,
              ),
              
              const SizedBox(height: 30),
              
              // App Info Section
              _buildSectionHeader('App Information', Icons.info_outline),
              const SizedBox(height: 16),
              
              _buildSettingTile(
                icon: Icons.system_update_outlined,
                title: 'App Version',
                subtitle: 'v1.0.0',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Latest',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              _buildSettingTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data',
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF7E57C2), size: 16),
                onTap: _showPrivacyPolicy,
              ),
              
              _buildSettingTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'App usage terms and conditions',
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF7E57C2), size: 16),
                onTap: _showTermsOfService,
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF7E57C2), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF424242),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E57C2).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF7E57C2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF7E57C2), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}