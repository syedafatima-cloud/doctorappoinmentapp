import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms of Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: July 30, 2025',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildSection(
              'Acceptance of Terms',
              'By using our Doctor Appointment App, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our app.',
            ),
            _buildSection(
              'Medical Disclaimer',
              'This app is designed to facilitate appointment booking and basic medical consultations. It is not intended to replace professional medical advice, diagnosis, or treatment. Always seek the advice of qualified healthcare providers for any medical concerns.',
            ),
            _buildSection(
              'User Responsibilities',
              'You agree to:\n\n• Provide accurate and complete information\n• Keep your account credentials secure\n• Use the app only for lawful purposes\n• Respect the privacy of other users\n• Follow healthcare provider instructions',
            ),
            _buildSection(
              'Appointment Policies',
              '• Appointments must be cancelled at least 2 hours in advance\n• Late cancellations may result in charges\n• Emergency appointments are subject to availability\n• Video consultations require stable internet connection',
            ),
            _buildSection(
              'Payment and Fees',
              'You agree to pay all fees associated with your use of the app, including:\n\n• Consultation fees\n• Appointment booking fees\n• Cancellation fees (if applicable)\n• Payment is processed securely through our payment partners',
            ),
            _buildSection(
              'Privacy and Data Protection',
              'Your privacy is important to us. Our collection and use of personal information is governed by our Privacy Policy, which is incorporated into these Terms by reference.',
            ),
            _buildSection(
              'Limitation of Liability',
              'The app and its services are provided on an "as is" basis. We make no warranties, expressed or implied, and disclaim all other warranties. We shall not be liable for any indirect, incidental, or consequential damages.',
            ),
            _buildSection(
              'Modifications to Terms',
              'We reserve the right to modify these terms at any time. We will notify users of significant changes through the app or email. Continued use of the app after changes constitutes acceptance of the new terms.',
            ),
            _buildSection(
              'Emergency Situations',
              'This app is not intended for emergency medical situations. In case of a medical emergency, immediately call 1122 or go to the nearest emergency room.',
            ),
            _buildSection(
              'Contact Information',
              'For questions about these Terms of Service, contact us at:\n\nEmail: legal@doctorapp.com\nPhone: +92-300-1234567\nAddress: Medical Plaza, Peshawar, KPK',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7E57C2).withOpacity(0.3)),
              ),
              child: const Text(
                'By continuing to use this app, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7E57C2),
                ),
                textAlign: TextAlign.center,
              ),
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