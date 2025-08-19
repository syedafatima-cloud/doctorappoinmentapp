import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final Map<String, List<DateTime>> _loginAttempts = {};
  static const int maxAttemptsPerHour = 5;

  static Future<bool> hasAdminRole(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      return userDoc.exists && userDoc.data()?['role'] == 'admin';
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }
  
  static bool isRateLimited(String email) {
    final now = DateTime.now();
    final attempts = _loginAttempts[email] ?? [];
    
    attempts.removeWhere((attempt) => now.difference(attempt).inHours >= 1);
    _loginAttempts[email] = attempts;
    
    return attempts.length >= maxAttemptsPerHour;
  }

  static void recordLoginAttempt(String email) {
    _loginAttempts[email] = (_loginAttempts[email] ?? [])..add(DateTime.now());
  }
}