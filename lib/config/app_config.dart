class AppConfig {
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  static const String adminEmail = isProduction 
    ? String.fromEnvironment('ADMIN_EMAIL', defaultValue: 'admin@yourapp.com')
    : 'admin@example.com';
    
  static const String adminPassword = isProduction
    ? String.fromEnvironment('ADMIN_PASSWORD', defaultValue: '')
    : 'admin123';
}