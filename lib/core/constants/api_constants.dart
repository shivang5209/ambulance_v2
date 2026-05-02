class ApiConstants {
  // Base URL - Update this to match your Django backend
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = '$baseUrl/api/$apiVersion';

  // WebSocket URL
  static const String wsBaseUrl = 'ws://localhost:8000/ws';

  // Authentication endpoints
  static const String loginEndpoint = '/auth/login/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String refreshTokenEndpoint = '/auth/refresh/';
  static const String userProfileEndpoint = '/auth/user/';

  // Ambulance endpoints
  static const String ambulancesEndpoint = '/ambulances/';
  static const String ambulanceLocationEndpoint = '/ambulances/{id}/location/';
  static const String ambulanceStatusEndpoint = '/ambulances/{id}/status/';

  // Hospital endpoints
  static const String hospitalsEndpoint = '/hospitals/';
  static const String hospitalDetailsEndpoint = '/hospitals/{id}/';

  // Accident endpoints
  static const String accidentsEndpoint = '/accidents/';
  static const String accidentDetailsEndpoint = '/accidents/{id}/';
  static const String reportAccidentEndpoint = '/accidents/report/';

  // Dispatch endpoints
  static const String dispatchEndpoint = '/dispatch/';
  static const String assignAmbulanceEndpoint = '/dispatch/assign/';

  // Analytics endpoints
  static const String analyticsEndpoint = '/analytics/';
  static const String accidentProneAreasEndpoint = '/analytics/accident-prone-areas/';
  static const String reportsEndpoint = '/analytics/reports/';

  // WebSocket channels
  static const String ambulanceUpdatesChannel = '/ambulance-updates/';
  static const String accidentAlertsChannel = '/accident-alerts/';
  static const String hospitalNotificationsChannel = '/hospital-notifications/';
  static const String dispatcherChannel = '/dispatcher/';

  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // File upload
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];

  // Location settings
  static const double defaultLocationRadius = 2000; // 2km in meters
  static const Duration locationUpdateInterval = Duration(seconds: 15);

  // Cache settings
  static const Duration cacheExpiration = Duration(minutes: 5);
  static const Duration offlineCacheExpiration = Duration(hours: 24);

  /// Build full API URL
  static String buildUrl(String endpoint) {
    return '$apiBaseUrl$endpoint';
  }

  /// Build WebSocket URL
  static String buildWsUrl(String channel) {
    return '$wsBaseUrl$channel';
  }

  /// Replace path parameters in endpoint
  static String replacePathParams(String endpoint, Map<String, String> params) {
    String result = endpoint;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}