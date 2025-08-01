// admin/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final tomorrow = DateFormat('yyyy-MM-dd').format(
        DateTime.now().add(const Duration(days: 1))
      );

      // Get today's appointments
      final todayAppointments = await _firestore
          .collection('appointments')
          .where('date', isEqualTo: today)
          .where('status', isEqualTo: 'confirmed')
          .get();

      // Get tomorrow's appointments
      final tomorrowAppointments = await _firestore
          .collection('appointments')
          .where('date', isEqualTo: tomorrow)
          .where('status', isEqualTo: 'confirmed')
          .get();

      // Get total appointments this month
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      
      final monthlyAppointments = await _firestore
          .collection('appointments')
          .where('createdAt', isGreaterThanOrEqualTo: monthStart)
          .where('createdAt', isLessThanOrEqualTo: monthEnd)
          .get();

      // Get pending appointments
      final pendingAppointments = await _firestore
          .collection('appointments')
          .where('status', isEqualTo: 'pending')
          .get();

      // Get cancelled appointments today
      final cancelledToday = await _firestore
          .collection('appointments')
          .where('date', isEqualTo: today)
          .where('status', isEqualTo: 'cancelled')
          .get();

      // Get active doctors count
      final activeDoctors = await _firestore
          .collection('doctors')
          .where('isActive', isEqualTo: true)
          .get();

      // Get unread notifications
      final unreadNotifications = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      return {
        'todayAppointments': todayAppointments.docs.length,
        'tomorrowAppointments': tomorrowAppointments.docs.length,
        'monthlyAppointments': monthlyAppointments.docs.length,
        'pendingAppointments': pendingAppointments.docs.length,
        'cancelledToday': cancelledToday.docs.length,
        'activeDoctors': activeDoctors.docs.length,
        'unreadNotifications': unreadNotifications.docs.length,
        'revenue': _calculateRevenue(monthlyAppointments.docs),
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {};
    }
  }

  double _calculateRevenue(List<QueryDocumentSnapshot> appointments) {
    double total = 0.0;
    for (var appointment in appointments) {
      final data = appointment.data() as Map<String, dynamic>;
      if (data['status'] == 'completed') {
        // You can add consultation fee to appointment data or fetch from doctor
        total += 1500.0; // Default fee, should be fetched from doctor's data
      }
    }
    return total;
  }

  // Get all appointments with filters
  Future<List<Map<String, dynamic>>> getFilteredAppointments({
    String? status,
    String? date,
    String? doctorId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore.collection('appointments');

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }

      if (doctorId != null && doctorId.isNotEmpty) {
        query = query.where('doctorId', isEqualTo: doctorId);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'document': doc, // For pagination
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      print('Error getting filtered appointments: $e');
      return [];
    }
  }

  // Get notifications for admin
  Future<List<Map<String, dynamic>>> getAdminNotifications({
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      Query query = _firestore
          .collection('admin_notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      print('Error getting admin notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('admin_notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final unreadNotifications = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Update appointment status
  Future<void> updateAppointmentStatus(String appointmentId, String newStatus, {String? reason}) async {
    try {
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reason != null) {
        if (newStatus == 'cancelled') {
          updateData['cancellationReason'] = reason;
          updateData['cancelledAt'] = FieldValue.serverTimestamp();
        }
      }

      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);

      // Create notification for status update
      await _createStatusUpdateNotification(appointmentId, newStatus, reason);
    } catch (e) {
      print('Error updating appointment status: $e');
      rethrow;
    }
  }

  Future<void> _createStatusUpdateNotification(String appointmentId, String status, String? reason) async {
    String message = 'Appointment $appointmentId status updated to $status';
    if (reason != null) {
      message += '. Reason: $reason';
    }

    await _firestore.collection('admin_notifications').add({
      'type': 'status_update',
      'title': 'Appointment Status Updated',
      'message': message,
      'appointmentId': appointmentId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get doctor's daily schedule
  Future<Map<String, dynamic>> getDoctorDailySchedule(String doctorId, String date) async {
    try {
      // Get doctor info
      final doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();
      if (!doctorDoc.exists) {
        return {'error': 'Doctor not found'};
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final doctorName = doctorData['name'];
      final availableSlots = List<String>.from(doctorData['availableSlots'][date] ?? []);

      // Get appointments for the day
      final appointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .orderBy('time')
          .get();

      final appointmentList = appointments.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      // Calculate statistics
      final totalSlots = availableSlots.length;
      final bookedSlots = appointments.docs.where((doc) => 
        (doc.data())['status'] == 'confirmed'
      ).length;
      final cancelledSlots = appointments.docs.where((doc) => 
        (doc.data())['status'] == 'cancelled'
      ).length;

      return {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'date': date,
        'totalSlots': totalSlots,
        'bookedSlots': bookedSlots,
        'availableSlots': totalSlots - bookedSlots + cancelledSlots,
        'cancelledSlots': cancelledSlots,
        'appointments': appointmentList,
        'allTimeSlots': availableSlots,
      };
    } catch (e) {
      print('Error getting doctor daily schedule: $e');
      return {'error': 'Failed to fetch schedule'};
    }
  }

  // Generate reports
  Future<Map<String, dynamic>> generateMonthlyReport(int year, int month) async {
    try {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);

      final appointments = await _firestore
          .collection('appointments')
          .where('createdAt', isGreaterThanOrEqualTo: monthStart)
          .where('createdAt', isLessThanOrEqualTo: monthEnd)
          .get();

      final doctorsQuery = await _firestore.collection('doctors').get();
      final doctorStats = <String, Map<String, dynamic>>{};

      // Initialize doctor stats
      for (var doctorDoc in doctorsQuery.docs) {
        final doctorData = doctorDoc.data();
        doctorStats[doctorDoc.id] = {
          'name': doctorData['name'],
          'specialization': doctorData['specialization'],
          'totalAppointments': 0,
          'completedAppointments': 0,
          'cancelledAppointments': 0,
          'revenue': 0.0,
        };
      }

      // Process appointments
      int totalAppointments = 0;
      int completedAppointments = 0;
      int cancelledAppointments = 0;
      double totalRevenue = 0.0;

      for (var appointmentDoc in appointments.docs) {
        final data = appointmentDoc.data();
        final doctorId = data['doctorId'];
        final status = data['status'];

        totalAppointments++;

        if (doctorStats.containsKey(doctorId)) {
          doctorStats[doctorId]!['totalAppointments']++;

          if (status == 'completed') {
            completedAppointments++;
            doctorStats[doctorId]!['completedAppointments']++;
            // Add consultation fee (you should fetch this from doctor's data)
            final fee = 1500.0; // Default, should be dynamic
            totalRevenue += fee;
            doctorStats[doctorId]!['revenue'] += fee;
          } else if (status == 'cancelled') {
            cancelledAppointments++;
            doctorStats[doctorId]!['cancelledAppointments']++;
          }
        }
      }

      return {
        'year': year,
        'month': month,
        'monthName': DateFormat('MMMM yyyy').format(DateTime(year, month)),
        'totalAppointments': totalAppointments,
        'completedAppointments': completedAppointments,
        'cancelledAppointments': cancelledAppointments,
        'pendingAppointments': totalAppointments - completedAppointments - cancelledAppointments,
        'totalRevenue': totalRevenue,
        'averageRevenuePerAppointment': completedAppointments > 0 ? totalRevenue / completedAppointments : 0.0,
        'doctorStats': doctorStats.values.toList(),
        'generatedAt': DateTime.now(),
      };
    } catch (e) {
      print('Error generating monthly report: $e');
      return {'error': 'Failed to generate report'};
    }
  }

  // Update doctor availability
  Future<void> updateDoctorAvailability({
    required String doctorId,
    required String date,
    required List<String> timeSlots,
  }) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({
        'availableSlots.$date': timeSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification
      await _firestore.collection('admin_notifications').add({
        'type': 'schedule_update',
        'title': 'Doctor Schedule Updated',
        'message': 'Schedule updated for doctor on $date',
        'doctorId': doctorId,
        'date': date,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating doctor availability: $e');
      rethrow;
    }
  }

  // Search appointments
  Future<List<Map<String, dynamic>>> searchAppointments(String searchQuery) async {
    try {
      // Search by patient name (case-insensitive)
      final nameQuery = await _firestore
          .collection('appointments')
          .where('userName', isGreaterThanOrEqualTo: searchQuery.toLowerCase())
          .where('userName', isLessThan: '${searchQuery.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      // Search by phone number
      final phoneQuery = await _firestore
          .collection('appointments')
          .where('userPhone', isGreaterThanOrEqualTo: searchQuery)
          .where('userPhone', isLessThan: '$searchQuery\uf8ff')
          .limit(20)
          .get();

      final results = <String, Map<String, dynamic>>{};

      // Combine results and remove duplicates
      for (var doc in [...nameQuery.docs, ...phoneQuery.docs]) {
        results[doc.id] = {
          'id': doc.id,
          ...doc.data(),
        };
      }

      return results.values.toList();
    } catch (e) {
      print('Error searching appointments: $e');
      return [];
    }
  }

  // Get appointment analytics
  Future<Map<String, dynamic>> getAppointmentAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final appointments = await _firestore
          .collection('appointments')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      final analytics = {
        'totalAppointments': 0,
        'chatAppointments': 0,
        'callAppointments': 0,
        'statusBreakdown': <String, int>{},
        'dailyTrends': <String, int>{},
        'doctorPerformance': <String, Map<String, dynamic>>{},
        'peakHours': <String, int>{},
      };

      for (var doc in appointments.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final appointmentType = data['appointmentType'] ?? 'chat';
        final status = data['status'] ?? 'pending';
        final time = data['time'] ?? '';
        final doctorId = data['doctorId'] ?? '';

        analytics['totalAppointments'] = (analytics['totalAppointments'] as int) + 1;

        // Appointment type breakdown
        if (appointmentType == 'chat') {
          analytics['chatAppointments'] = (analytics['chatAppointments'] as int) + 1;
        } else {
          analytics['callAppointments'] = (analytics['callAppointments'] as int) + 1;
        }

        // Status breakdown
        final statusBreakdown = analytics['statusBreakdown'] as Map<String, int>;
        statusBreakdown[status] = (statusBreakdown[status] ?? 0) + 1;

        // Daily trends
        if (createdAt != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
          final dailyTrends = analytics['dailyTrends'] as Map<String, int>;
          dailyTrends[dateKey] = (dailyTrends[dateKey] ?? 0) + 1;
        }

        // Peak hours analysis
        if (time.isNotEmpty) {
          final hour = time.split(':')[0];
          final peakHours = analytics['peakHours'] as Map<String, int>;
          peakHours[hour] = (peakHours[hour] ?? 0) + 1;
        }

        // Doctor performance
        if (doctorId.isNotEmpty) {
          final doctorPerformance = analytics['doctorPerformance'] as Map<String, Map<String, dynamic>>;
          if (!doctorPerformance.containsKey(doctorId)) {
            doctorPerformance[doctorId] = {
              'totalAppointments': 0,
              'completed': 0,
              'cancelled': 0,
            };
          }
          doctorPerformance[doctorId]!['totalAppointments'] = (doctorPerformance[doctorId]!['totalAppointments'] as int) + 1;
          if (status == 'completed') {
            doctorPerformance[doctorId]!['completed'] = (doctorPerformance[doctorId]!['completed'] as int) + 1;
          } else if (status == 'cancelled') {
            doctorPerformance[doctorId]!['cancelled'] = (doctorPerformance[doctorId]!['cancelled'] as int) + 1;
          }
        }
      }

      return analytics;
    } catch (e) {
      print('Error getting appointment analytics: $e');
      return {};
    }
  }

  // Get all appointments (simple, for admin dashboard)
  Future<List<Map<String, dynamic>>> getAllAppointments() async {
    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting all appointments: $e');
      return [];
    }
  }
}