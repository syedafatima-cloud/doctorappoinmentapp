import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  // Light theme colors
  static const Color primaryColor = Color(0xFFC5CAE9); // Lavender Mist
  static const Color accentColor = Color(0xFF7E57C2);  // Muted Plum
  static const Color backgroundColor = Color(0xFFFAF8F5); // Soft Cream
  static const Color cardColor = Color(0xFFEDE7F6); // Light Lavender
  static const Color textColor = Color(0xFF424242); // Deep Gray
  static const Color buttonColor = Color(0xFFD1C4E9); // Dusty Lilac

  // Dark theme colors
  static const Color darkPrimaryColor = Color(0xFF7E57C2);
  static const Color darkAccentColor = Color(0xFFC5CAE9);
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkTextColor = Color(0xFFE0E0E0);
  static const Color darkButtonColor = Color(0xFF7E57C2);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        onSecondary: Colors.white,
        surface: cardColor,
        onSurface: textColor,
        error: Colors.red.shade400,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      primaryColor: primaryColor,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor),
        titleMedium: TextStyle(fontSize: 18, color: textColor),
        bodyMedium: TextStyle(fontSize: 16, color: textColor),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor),
        ),
      ),
      iconTheme: const IconThemeData(color: accentColor),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.grey.shade500,
        selectedIconTheme: const IconThemeData(size: 26),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimaryColor,
        onPrimary: Colors.white,
        secondary: darkAccentColor,
        onSecondary: Colors.black,
        surface: darkCardColor,
        onSurface: darkTextColor,
        error: Colors.red.shade400,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      cardColor: darkCardColor,
      primaryColor: darkPrimaryColor,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: darkTextColor),
        titleMedium: TextStyle(fontSize: 18, color: darkTextColor),
        bodyMedium: TextStyle(fontSize: 16, color: darkTextColor),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkButtonColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardColor,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkAccentColor),
        ),
      ),
      iconTheme: const IconThemeData(color: darkAccentColor),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkCardColor,
        selectedItemColor: darkAccentColor,
        unselectedItemColor: Colors.grey.shade400,
        selectedIconTheme: const IconThemeData(size: 26),
      ),
    );
  }
}

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeManager() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('darkMode', isDark);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setTheme(!isDarkMode);
  }
}