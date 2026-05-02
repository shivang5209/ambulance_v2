import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  static const String _tag = 'EmergencyAmbulance';

  void debug(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void info(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void warning(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode && level == LogLevel.debug) {
      return; // Don't log debug messages in release mode
    }

    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag ?? _tag;
    final levelStr = level.name.toUpperCase();
    
    final logMessage = '[$timestamp] [$levelStr] [$logTag] $message';
    
    // Print to console in debug mode
    if (kDebugMode) {
      print(logMessage);
      
      if (error != null) {
        print('Error: $error');
      }
      
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // In production, you might want to send logs to a remote service
    // Example: _sendToRemoteLogging(level, message, tag, error, stackTrace);
  }

  // Method to log network requests
  void logNetworkRequest(String method, String url, {Map<String, dynamic>? data}) {
    debug('$method $url', tag: 'Network');
    if (data != null) {
      debug('Request data: $data', tag: 'Network');
    }
  }

  // Method to log network responses
  void logNetworkResponse(String method, String url, int statusCode, {dynamic data}) {
    debug('$method $url - Status: $statusCode', tag: 'Network');
    if (data != null) {
      debug('Response data: $data', tag: 'Network');
    }
  }

  // Method to log user actions
  void logUserAction(String action, {Map<String, dynamic>? parameters}) {
    info('User action: $action', tag: 'UserAction');
    if (parameters != null) {
      info('Parameters: $parameters', tag: 'UserAction');
    }
  }

  // Method to log authentication events
  void logAuthEvent(String event, {String? userId}) {
    info('Auth event: $event${userId != null ? ' (User: $userId)' : ''}', tag: 'Auth');
  }

  // Method to log location events
  void logLocationEvent(String event, {double? latitude, double? longitude}) {
    info('Location event: $event${latitude != null && longitude != null ? ' (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})' : ''}', tag: 'Location');
  }

  // Method to log WebSocket events
  void logWebSocketEvent(String event, {String? channel}) {
    info('WebSocket event: $event${channel != null ? ' (Channel: $channel)' : ''}', tag: 'WebSocket');
  }
}