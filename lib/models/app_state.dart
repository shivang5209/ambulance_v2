import 'package:equatable/equatable.dart';
import 'user.dart';

enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  reconnecting,
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  notRequested,
}

class AuthState extends Equatable {
  final bool isAuthenticated;
  final User? currentUser;
  final String? token;
  final DateTime? tokenExpiry;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.currentUser,
    this.token,
    this.tokenExpiry,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? currentUser,
    String? token,
    DateTime? tokenExpiry,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: currentUser ?? this.currentUser,
      token: token ?? this.token,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isTokenValid {
    if (token == null || tokenExpiry == null) return false;
    return DateTime.now().isBefore(tokenExpiry!);
  }

  bool get needsRefresh {
    if (tokenExpiry == null) return false;
    final now = DateTime.now();
    final refreshThreshold = tokenExpiry!.subtract(const Duration(minutes: 5));
    return now.isAfter(refreshThreshold);
  }

  @override
  List<Object?> get props => [
        isAuthenticated,
        currentUser,
        token,
        tokenExpiry,
        isLoading,
        error,
      ];
}

class ConnectionState extends Equatable {
  final ConnectionStatus status;
  final bool hasInternetConnection;
  final bool isWebSocketConnected;
  final DateTime? lastConnected;
  final String? error;

  const ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.hasInternetConnection = false,
    this.isWebSocketConnected = false,
    this.lastConnected,
    this.error,
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    bool? hasInternetConnection,
    bool? isWebSocketConnected,
    DateTime? lastConnected,
    String? error,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      hasInternetConnection: hasInternetConnection ?? this.hasInternetConnection,
      isWebSocketConnected: isWebSocketConnected ?? this.isWebSocketConnected,
      lastConnected: lastConnected ?? this.lastConnected,
      error: error,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting || 
                          status == ConnectionStatus.reconnecting;

  @override
  List<Object?> get props => [
        status,
        hasInternetConnection,
        isWebSocketConnected,
        lastConnected,
        error,
      ];
}

class LocationState extends Equatable {
  final LocationPermissionStatus permissionStatus;
  final bool isLocationServiceEnabled;
  final bool isTracking;
  final String? error;

  const LocationState({
    this.permissionStatus = LocationPermissionStatus.notRequested,
    this.isLocationServiceEnabled = false,
    this.isTracking = false,
    this.error,
  });

  LocationState copyWith({
    LocationPermissionStatus? permissionStatus,
    bool? isLocationServiceEnabled,
    bool? isTracking,
    String? error,
  }) {
    return LocationState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLocationServiceEnabled: isLocationServiceEnabled ?? this.isLocationServiceEnabled,
      isTracking: isTracking ?? this.isTracking,
      error: error,
    );
  }

  bool get hasLocationPermission => 
      permissionStatus == LocationPermissionStatus.granted;

  bool get canTrackLocation => 
      hasLocationPermission && isLocationServiceEnabled;

  @override
  List<Object?> get props => [
        permissionStatus,
        isLocationServiceEnabled,
        isTracking,
        error,
      ];
}

class NotificationState extends Equatable {
  final bool areNotificationsEnabled;
  final bool arePushNotificationsEnabled;
  final Map<String, bool> notificationPreferences;
  final List<String> pendingNotifications;

  const NotificationState({
    this.areNotificationsEnabled = false,
    this.arePushNotificationsEnabled = false,
    this.notificationPreferences = const {},
    this.pendingNotifications = const [],
  });

  NotificationState copyWith({
    bool? areNotificationsEnabled,
    bool? arePushNotificationsEnabled,
    Map<String, bool>? notificationPreferences,
    List<String>? pendingNotifications,
  }) {
    return NotificationState(
      areNotificationsEnabled: areNotificationsEnabled ?? this.areNotificationsEnabled,
      arePushNotificationsEnabled: arePushNotificationsEnabled ?? this.arePushNotificationsEnabled,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      pendingNotifications: pendingNotifications ?? this.pendingNotifications,
    );
  }

  bool isNotificationTypeEnabled(String type) {
    return notificationPreferences[type] ?? true;
  }

  @override
  List<Object?> get props => [
        areNotificationsEnabled,
        arePushNotificationsEnabled,
        notificationPreferences,
        pendingNotifications,
      ];
}

class AppState extends Equatable {
  final AuthState authState;
  final ConnectionState connectionState;
  final LocationState locationState;
  final NotificationState notificationState;

  const AppState({
    required this.authState,
    required this.connectionState,
    required this.locationState,
    required this.notificationState,
  });

  AppState copyWith({
    AuthState? authState,
    ConnectionState? connectionState,
    LocationState? locationState,
    NotificationState? notificationState,
  }) {
    return AppState(
      authState: authState ?? this.authState,
      connectionState: connectionState ?? this.connectionState,
      locationState: locationState ?? this.locationState,
      notificationState: notificationState ?? this.notificationState,
    );
  }

  @override
  List<Object?> get props => [
        authState,
        connectionState,
        locationState,
        notificationState,
      ];
}