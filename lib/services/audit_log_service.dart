import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogService {
  static final CollectionReference _auditCollection = 
      FirebaseFirestore.instance.collection('audit_logs');
  
  static Future<void> logAdminAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _auditCollection.add({
        'adminId': adminId,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging admin action: $e');
    }
  }
}