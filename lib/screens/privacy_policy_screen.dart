import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: July 30, 2025',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildSection(
              'Information We Collect',
              'We collect information you provide directly to us, such as when you create an account, book appointments, or contact us for support. This includes:\n\n• Personal information (name, email, phone number)\n• Medical information (symptoms, medical history)\n• Usage data (app interactions, preferences)',
            ),
            _buildSection(
              'How We Use Your Information',
              'We use the information we collect to:\n\n• Provide and maintain our medical services\n• Process appointments and consultations\n• Send important notifications about your healthcare\n• Improve our app and services\n• Comply with legal obligations',
            ),
            _buildSection(
              'Information Sharing',
              'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except:\n\n• With healthcare providers for your treatment\n• When required by law\n• To protect our rights and safety\n• With your explicit consent',
            ),
            _buildSection(
              'Data Security',
              'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. Your medical data is encrypted and stored securely in compliance with healthcare regulations.',
            ),
            _buildSection(
              'Your Rights',
              'You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Delete your account and data\n• Restrict processing of your data\n• Data portability',
            ),
            _buildSection(
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@doctorapp.com\nPhone: +92-300-1234567\nAddress: Medical Plaza, Peshawar, KPK',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}