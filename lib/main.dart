import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:provider/provider.dart'; // Add this import

import 'screens/splash_screen.dart';
import 'screens/homescreen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/registeration_screens/login_screen.dart';
import 'screens/registeration_screens/signup_screen.dart';
import 'services/appointment_service.dart';
import 'services/notification_service.dart';
import 'theme.dart'; // Add this import (adjust path as needed)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize timezones
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

  // Initialize services
  final appointmentService = AppointmentService();
  final notificationService = NotificationService();
  await appointmentService.initializeNotifications();
  await notificationService.initialize();

  // Uncomment the next line to initialize sample data with current dates
  // await FirestoreSetup.initializeSampleData();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: 'MediCare+',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,          // Use your custom light theme
          darkTheme: AppTheme.darkTheme,       // Use your custom dark theme
          themeMode: themeManager.themeMode,   // This makes the switching work
          home: const SplashScreen(
            nextScreen: LoginPage(),
          ),
          routes: {
            '/admin': (context) => const AdminDashboard(),
            '/home': (context) => const HomeScreen(),
            '/signup': (context) => const Signup(),
          },
        );
      },
    );
  }
}