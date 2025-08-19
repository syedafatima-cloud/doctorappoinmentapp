class EmailService {
  static Future<void> sendApprovalNotification(String email, String doctorName) async {
    await _sendEmail(
      to: email,
      subject: 'Doctor Registration Approved',
      body: '''
      Dear Dr. $doctorName,
      
      Congratulations! Your doctor registration has been approved.
      You can now login to the app using your registered email and password.
      
      Welcome to our medical platform!
      
      Best regards,
      Medical App Team
      ''',
    );
  }
  
  static Future<void> sendRejectionNotification(String email, String doctorName, String reason) async {
    await _sendEmail(
      to: email,
      subject: 'Doctor Registration Update',
      body: '''
      Dear Dr. $doctorName,
      
      We regret to inform you that your doctor registration has been declined.
      Reason: $reason
      
      If you have any questions, please contact our support team.
      
      Best regards,
      Medical App Team
      ''',
    );
  }
  
  static Future<void> _sendEmail({required String to, required String subject, required String body}) async {
    // Implement your email service here
    print('📧 Sending email to: $to');
    print('📧 Subject: $subject');
  }
}