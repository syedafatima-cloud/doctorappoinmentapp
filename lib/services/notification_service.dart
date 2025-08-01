// notifications/notification_service.dart
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notif;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notif.FlutterLocalNotificationsPlugin _localNotifications = notif.FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  StreamSubscription<QuerySnapshot>? _appointmentSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Initialize notification service
  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _initializeFCM();
    _setupRealtimeListeners();
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = notif.AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = notif.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = notif.InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions for Android 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<notif.AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Initialize Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    // Request permission for iOS
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final fcmToken = await _fcm.getToken();
    print('FCM Token: $fcmToken');

    // Save FCM token for admin device
    if (fcmToken != null) {
      await _saveFCMToken(fcmToken);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      await _firestore.collection('admin_tokens').doc('main_admin').set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'flutter',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Setup realtime listeners for Firestore changes
  void _setupRealtimeListeners() {
    // Listen for new appointments
    _appointmentSubscription = _firestore
        .collection('appointments')
        .where('createdAt', isGreaterThan: DateTime.now().subtract(Duration(minutes: 1)))
        .snapshots()
        .listen(_handleNewAppointment);

    // Listen for admin notifications
    _notificationSubscription = _firestore
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(_handleAdminNotification);
  }

  // Handle new appointments from Firestore stream
  void _handleNewAppointment(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        _showNewAppointmentNotification(data);
      }
    }
  }

  // Handle admin notifications from Firestore stream
  void _handleAdminNotification(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        _showAdminNotification(data);
      }
    }
  }

  // Show new appointment notification
  void _showNewAppointmentNotification(Map<String, dynamic> appointmentData) {
    final userName = appointmentData['userName'] ?? 'Unknown User';
    final doctorName = appointmentData['doctorName'] ?? 'Unknown Doctor';
    final date = appointmentData['date'] ?? '';
    final time = appointmentData['time'] ?? '';
    final appointmentType = appointmentData['appointmentType'] ?? 'chat';

    showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🩺 New Appointment Booked',
      body: '$userName booked a $appointmentType appointment with $doctorName on $date at $time',
      payload: 'appointment_${appointmentData['id'] ?? ''}',
      priority: NotificationPriority.high,
    );
  }

  // Show admin notification
  void _showAdminNotification(Map<String, dynamic> notificationData) {
    final title = notificationData['title'] ?? 'New Notification';
    final message = notificationData['message'] ?? '';
    final type = notificationData['type'] ?? 'general';

    String emoji = '📢';
    switch (type) {
      case 'new_appointment':
        emoji = '🩺';
        break;
      case 'appointment_cancelled':
        emoji = '❌';
        break;
      case 'appointment_rescheduled':
        emoji = '📅';
        break;
      case 'schedule_update':
        emoji = '⏰';
        break;
    }

    showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '$emoji $title',
      body: message,
      payload: 'notification_${notificationData['id'] ?? ''}',
      priority: NotificationPriority.high,
    );
  }

  // Handle foreground FCM messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.notification?.title}');
    
    if (message.notification != null) {
      showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data['payload'] ?? '',
      );
    }
  }

  // Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('Background message tapped: ${message.notification?.title}');
    // Handle navigation based on message data
    final payload = message.data['payload'] ?? '';
    _handleNotificationTap(payload);
  }

  // Handle notification tap
  void _onNotificationTap(notif.NotificationResponse response) {
    final payload = response.payload ?? '';
    _handleNotificationTap(payload);
  }

  // Handle notification tap navigation
  void _handleNotificationTap(String payload) {
    print('Notification tapped with payload: $payload');
    
    if (payload.startsWith('appointment_')) {
      final appointmentId = payload.replaceFirst('appointment_', '');
      // Navigate to appointment details
      // NavigationService.navigateToAppointment(appointmentId);
    } else if (payload.startsWith('notification_')) {
      final notificationId = payload.replaceFirst('notification_', '');
      // Navigate to notifications page
      // NavigationService.navigateToNotifications();
    }
  }

 // Show local notification - COMPLETION
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    notif.AndroidNotificationDetails androidDetails = notif.AndroidNotificationDetails(
      'appointment_channel',
      'Appointment Notifications',
      channelDescription: 'Notifications for appointment bookings and updates',
      importance: priority == NotificationPriority.high 
          ? notif.Importance.high 
          : notif.Importance.defaultImportance,
      priority: priority == NotificationPriority.high 
          ? notif.Priority.high 
          : notif.Priority.defaultPriority,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF2196F3),
      styleInformation: notif.BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Hospital Management',
      ),
    );

    const notif.DarwinNotificationDetails iosDetails = notif.DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: notif.InterruptionLevel.active,
    );

    notif.NotificationDetails platformDetails = notif.NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
  //schedule Notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      final karachi = tz.getLocation('Asia/Karachi');
      print('Current tz.local:  [32m${tz.local} [0m');
      print('Using tz.getLocation("Asia/Karachi"):  [32m$karachi [0m');
      print('Scheduled date:  [32m$scheduledDate [0m');
      print('TZDateTime:  [32m${tz.TZDateTime.from(scheduledDate, karachi)} [0m');
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, karachi),
        const notif.NotificationDetails(
          android: notif.AndroidNotificationDetails(
            'scheduled_channel',
            'Scheduled Notifications',
            channelDescription: 'Scheduled appointment reminders',
            importance: notif.Importance.high,
            priority: notif.Priority.high,
          ),
          iOS: notif.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
        androidScheduleMode: notif.AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      print('Error in scheduleNotification (timezone or notification): $e');
      rethrow;
    }
  }



  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Send notification to specific FCM token
  Future<void> sendNotificationToToken({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Note: This would typically be done from a server/cloud function
      // For client-side, you'd need to call your backend API
      print('Would send notification to token: $fcmToken');
      print('Title: $title, Body: $body');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Dispose streams
  void dispose() {
    _appointmentSubscription?.cancel();
    _notificationSubscription?.cancel();
  }
}

// Notification priority enum
enum NotificationPriority {
  low,
  normal,
  high,
  max,
}