// services/admin_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all appointments
  Future<List<Map<String, dynamic>>> getAllAppointments() async {
    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch appointments: $e');
    }
  }

  // Get all users (patients)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Get all doctors
  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection('doctors')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch doctors: $e');
    }
  }

  // Update appointment status
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update appointment status: $e');
    }
  }

  // Update user status (activate/deactivate)
  Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  // Send message to user
  Future<void> sendMessageToUser(String userId, String message) async {
    try {
      await _firestore
          .collection('user_notifications')
          .add({
        'userId': userId,
        'title': 'Message from Admin',
        'message': message,
        'type': 'admin_message',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get dashboard statistics
  Future<Map<String, int>> getDashboardStatistics() async {
    try {
      final futures = await Future.wait([
        _firestore.collection('appointments').get(),
        _firestore.collection('doctors').where('status', isEqualTo: 'approved').get(),
        _firestore.collection('doctor_registration_requests').where('status', isEqualTo: 'pending').get(),
        _firestore.collection('users').get(),
        _firestore.collection('admin_notifications').where('isRead', isEqualTo: false).get(),
      ]);

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Count today's appointments
      final todayAppointments = futures[0].docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['date'] == todayString;
      }).length;

      return {
        'totalAppointments': futures[0].docs.length,
        'activeDoctors': futures[1].docs.length,
        'pendingRequests': futures[2].docs.length,
        'totalUsers': futures[3].docs.length,
        'unreadNotifications': futures[4].docs.length,
        'todayAppointments': todayAppointments,
      };
    } catch (e) {
      throw Exception('Failed to fetch dashboard statistics: $e');
    }
  }

  // Get detailed statistics for different periods
  Future<Map<String, dynamic>> getDetailedStatistics(String period) async {
    try {
      DateTime startDate;
      final now = DateTime.now();

      switch (period) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'thisWeek':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'thisMonth':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'thisYear':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(2020, 1, 1); // All time
      }

      final appointments = await _firestore
          .collection('appointments')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final doctors = await _firestore
          .collection('doctors')
          .get();

      final users = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Calculate statistics
      final totalAppointments = appointments.docs.length;
      final completedAppointments = appointments.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'completed'
      ).length;
      final cancelledAppointments = appointments.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'cancelled'
      ).length;
      final pendingAppointments = appointments.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'pending'
      ).length;
      final confirmedAppointments = appointments.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'confirmed'
      ).length;

      // Calculate rates
      final completionRate = totalAppointments > 0 
          ? (completedAppointments / totalAppointments * 100).toDouble()
          : 0.0;
      final cancellationRate = totalAppointments > 0 
          ? (cancelledAppointments / totalAppointments * 100).toDouble()
          : 0.0;

      // Calculate revenue (assuming average consultation fee)
      final totalRevenue = completedAppointments * 50; // $50 average

      // Get top specializations
      final specializations = <String, int>{};
      for (var doc in doctors.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final spec = data['specialization'] as String?;
        if (spec != null) {
          specializations[spec] = (specializations[spec] ?? 0) + 1;
        }
      }

      final topSpecializations = specializations.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return {
        'totalAppointments': totalAppointments,
        'completedAppointments': completedAppointments,
        'cancelledAppointments': cancelledAppointments,
        'pendingAppointments': pendingAppointments,
        'confirmedAppointments': confirmedAppointments,
        'appointmentCompletionRate': completionRate,
        'appointmentCancellationRate': cancellationRate,
        'totalRevenue': totalRevenue,
        'activeDoctors': doctors.docs.where((doc) => 
          (doc.data() as Map<String, dynamic>)['status'] == 'approved'
        ).length,
        'pendingDoctors': doctors.docs.where((doc) => 
          (doc.data() as Map<String, dynamic>)['status'] == 'pending'
        ).length,
        'rejectedDoctors': doctors.docs.where((doc) => 
          (doc.data() as Map<String, dynamic>)['status'] == 'rejected'
        ).length,
        'totalUsers': users.docs.length,
        'newUsers': users.docs.length,
        'activeUsers': users.docs.where((doc) => 
          (doc.data() as Map<String, dynamic>)['isActive'] == true
        ).length,
        'activeToday': _calculateActiveToday(),
        'userRetentionRate': 85.0, // This would need more complex calculation
        'topSpecializations': topSpecializations,
        'avgResponseTime': 245, // Mock data
        'systemErrors': 3, // Mock data
        'dbQueriesPerSec': 127, // Mock data
        'activeSessions': 45, // Mock data
        'systemUptime': 99.9, // Mock data
      };
    } catch (e) {
      throw Exception('Failed to fetch detailed statistics: $e');
    }
  }

  int _calculateActiveToday() {
    // This would typically check user activity logs
    // For now, returning a mock value
    return 25;
  }

  // Get system health status
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      // This would typically check various system metrics
      // For now, returning mock data
      return {
        'status': 'healthy',
        'uptime': 99.9,
        'responseTime': 245,
        'errors': 3,
        'activeConnections': 127,
        'memoryUsage': 68.5,
        'cpuUsage': 34.2,
        'diskUsage': 45.8,
      };
    } catch (e) {
      throw Exception('Failed to fetch system health: $e');
    }
  }

  // Export data functionality
  Future<String> exportAppointmentsData(String format, String period) async {
    try {
      DateTime startDate;
      final now = DateTime.now();

      switch (period) {
        case 'thisMonth':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'thisYear':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(2020, 1, 1);
      }

      final appointments = await _firestore
          .collection('appointments')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Format data based on requested format (CSV, JSON, etc.)
      if (format == 'csv') {
        return _generateCSV(appointments.docs);
      } else {
        return _generateJSON(appointments.docs);
      }
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  String _generateCSV(List<QueryDocumentSnapshot> docs) {
    String csv = 'ID,Patient Name,Doctor Name,Date,Time,Status,Type\n';
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      csv += '${doc.id},${data['userName']},${data['doctorName']},${data['date']},${data['time']},${data['status']},${data['appointmentType']}\n';
    }
    return csv;
  }

  String _generateJSON(List<QueryDocumentSnapshot> docs) {
    final List<Map<String, dynamic>> jsonData = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // In a real app, you'd use dart:convert to jsonEncode
    return jsonData.toString();
  }

  // Backup functionality
  Future<void> createSystemBackup() async {
    try {
      // This would typically create a backup of the entire system
      // For now, just logging the action
      await _firestore.collection('system_logs').add({
        'action': 'backup_created',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'success',
      });
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  // Send bulk notifications
  Future<void> sendBulkNotification(String title, String message, List<String> userIds) async {
    try {
      final batch = _firestore.batch();
      
      for (String userId in userIds) {
        final notificationRef = _firestore.collection('user_notifications').doc();
        batch.set(notificationRef, {
          'userId': userId,
          'title': title,
          'message': message,
          'type': 'admin_announcement',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send bulk notification: $e');
    }
  }
}