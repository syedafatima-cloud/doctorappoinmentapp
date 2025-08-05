import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash_screen.dart';
import 'screens/homescreen.dart';
import 'screens/admin_screens/admin_dashboard.dart';
import 'screens/registeration_screens/login_screen.dart';
import 'screens/registeration_screens/signup_screen.dart';
import 'services/appointment_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

// Secure environment configuration class
class EnvironmentConfig {
  // Load from environment variables with secure fallbacks
  static String get GROQ_API_KEY => _getEnvVar('GROQ_API_KEY', '');
  static String get GROQ_MODEL => _getEnvVar('GROQ_MODEL',''); // Temporarily hardcoded to fix connection issue
  static String get DEBUG_MODE => _getEnvVar('DEBUG_MODE', 'false');
  static String get APP_NAME => _getEnvVar('APP_NAME', 'MediCare+');
  static String get APP_VERSION => _getEnvVar('APP_VERSION', '1.0.0');
  
  // Helper method to safely get environment variables
  static String _getEnvVar(String key, String defaultValue) {
    try {
      return dotenv.env[key] ?? defaultValue;
    } catch (e) {
      // If dotenv is not initialized, return default value
      return defaultValue;
    }
  }
  
  // Check if API key is configured
  static bool get hasApiKey => GROQ_API_KEY.isNotEmpty;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables securely
  await _loadEnvironmentVariables();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
  }

  try {
    // Initialize timezones
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    print('✅ Timezone initialized for Asia/Karachi');
  } catch (e) {
    print('❌ Error initializing timezone: $e');
  }

  try {
    // Initialize services
    final appointmentService = AppointmentService();
    final notificationService = NotificationService();
    
    await appointmentService.initializeNotifications();
    await notificationService.initialize();
    print('✅ Services initialized successfully');
  } catch (e) {
    print('❌ Error initializing services: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

Future<void> _loadEnvironmentVariables() async {
  try {
    print('🔍 Attempting to load .env file...');
    
    // Try to load .env file
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded from .env file');
    
    // Debug: Print all environment variables
    print('🔍 All environment variables:');
    dotenv.env.forEach((key, value) {
      if (key.contains('GROQ') || key.contains('API')) {
        print('  $key: ${value != null ? '${value.substring(0, 10)}...' : 'null'}');
      }
    });
    
    // Check if API key is loaded
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      print('✅ Groq API key found: ${apiKey.substring(0, 10)}...');
      print('🔑 Full API key length: ${apiKey.length}');
    } else {
      print('⚠️ No Groq API key found in .env file.');
      print('📝 Make sure your .env file contains: GROQ_API_KEY=your_key_here');
    }
  } catch (e) {
    print('❌ Error loading .env file: $e');
    print('📝 Make sure:');
    print('   1. .env file exists in project root (same level as pubspec.yaml)');
    print('   2. .env is added to assets in pubspec.yaml');
    print('   3. File format is correct (no spaces around =)');
    print('   4. File is saved and not corrupted');
    
    // Try alternative loading method
    try {
      print('🔄 Trying alternative loading method...');
      await dotenv.load();
      print('✅ Alternative loading successful');
      
      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
        print('✅ Groq API key found with alternative method: ${apiKey.substring(0, 10)}...');
      }
    } catch (e2) {
      print('❌ Alternative loading also failed: $e2');
    }
  }
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
          theme: AppTheme.lightTheme,     // Use your custom light theme
          darkTheme: AppTheme.darkTheme,  // Use your custom dark theme
          themeMode: themeManager.themeMode, // This makes the switching work
          home: const SplashScreen(
            nextScreen: LoginPage(),
          ),
          routes: {
            '/admin': (context) => const AdminDashboard(adminId: 'your_admin_id'),
            '/home': (context) => const HomeScreen(),
            '/signup': (context) => const Signup(),
          },
        );
      },
    );
  }
}