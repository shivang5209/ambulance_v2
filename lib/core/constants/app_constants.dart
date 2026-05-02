/// Application-wide constants
class AppConstants {
  // App Information
  static const String appName = 'Accident Detection System';
  static const String appVersion = '1.0.0';
  
  // API Endpoints (placeholder - update with actual endpoints)
  static const String baseApiUrl = 'https://api.example.com';
  static const String emergencyServiceApiUrl = 'https://emergency.example.com';
  
  // MQTT Configuration
  static const String mqttBrokerUrl = 'mqtt.example.com';
  static const int mqttBrokerPort = 8883;
  static const String mqttClientPrefix = 'accident_detection_';
  
  // Monitoring Configuration
  static const Duration parameterCollectionInterval = Duration(seconds: 1);
  static const Duration baselineEstablishmentPeriod = Duration(minutes: 5);
  static const int maxParameterHistorySize = 300; // 5 minutes at 1 second intervals
  
  // Accident Detection Thresholds
  static const double impactThresholdG = 4.0; // G-force threshold
  static const double suddenDecelerationThreshold = 30.0; // km/h per second
  static const double speedThresholdKmh = 150.0; // Maximum safe speed
  
  // Emergency Response
  static const Duration emergencyResponseTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryBackoffBase = Duration(seconds: 1);
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // Responsive Breakpoints
  static const double smallScreenBreakpoint = 600;
  static const double mediumScreenBreakpoint = 840;
  
  // Database
  static const String databaseName = 'accident_detection.db';
  static const int databaseVersion = 1;
  
  // Shared Preferences Keys
  static const String keyUserId = 'user_id';
  static const String keyThemeMode = 'theme_mode';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyDeviceToken = 'device_token';
  
  // Error Messages
  static const String errorGeneric = 'An error occurred. Please try again.';
  static const String errorNetwork = 'Network connection failed. Please check your internet.';
  static const String errorDeviceOffline = 'IoT device is offline.';
  static const String errorInvalidCredentials = 'Invalid device credentials.';
  static const String errorEmergencyServiceUnavailable = 'Emergency service unavailable. Trying alternative...';
  
  // Success Messages
  static const String successDeviceRegistered = 'Device registered successfully!';
  static const String successProfileUpdated = 'Profile updated successfully!';
  static const String successContactAdded = 'Emergency contact added!';
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxPhoneLength = 15;
  
  // Permissions
  static const List<String> requiredPermissions = [
    'location',
    'notification',
    'camera',
    'storage',
  ];
}
