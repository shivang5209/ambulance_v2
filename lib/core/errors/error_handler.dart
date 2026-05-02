import 'package:flutter/foundation.dart';
import 'exceptions.dart';

class ErrorHandler {
  static void handleError(dynamic error, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Log to crash reporting service in production
    // Example: FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }

    // Handle common Flutter/Dart exceptions
    if (error is FormatException) {
      return 'Invalid data format';
    }

    if (error is TypeError) {
      return 'Data type error occurred';
    }

    if (error is ArgumentError) {
      return 'Invalid argument provided';
    }

    // Default error message
    return 'An unexpected error occurred';
  }

  static String getUserFriendlyMessage(AppException exception) {
    switch (exception) {
      case NetworkException _:
        return _getNetworkErrorMessage(exception);
      case AuthenticationException _:
        return 'Please check your login credentials and try again';
      case AuthorizationException _:
        return 'You don\'t have permission to perform this action';
      case ValidationException _:
        return _getValidationErrorMessage(exception);
      case ServerException _:
        return 'Server is temporarily unavailable. Please try again later';
      case NotFoundException _:
        return 'The requested resource was not found';
      case LocationException _:
        return _getLocationErrorMessage(exception);
      case PermissionException _:
        return 'Permission required to continue. Please grant the necessary permissions';
      case WebSocketException _:
        return 'Connection lost. Attempting to reconnect...';
      default:
        return exception.message;
    }
  }

  static String _getNetworkErrorMessage(NetworkException exception) {
    if (exception.message.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection and try again';
    }
    if (exception.message.contains('connection')) {
      return 'No internet connection. Please check your network settings';
    }
    return 'Network error occurred. Please try again';
  }

  static String _getValidationErrorMessage(ValidationException exception) {
    if (exception.fieldErrors != null && exception.fieldErrors!.isNotEmpty) {
      final firstError = exception.fieldErrors!.values.first.first;
      return firstError;
    }
    return exception.message;
  }

  static String _getLocationErrorMessage(LocationException exception) {
    if (exception.message.contains('permission')) {
      return 'Location permission is required for this feature';
    }
    if (exception.message.contains('disabled')) {
      return 'Please enable location services in your device settings';
    }
    return 'Unable to access location. Please check your location settings';
  }

  static bool isRetryableError(AppException exception) {
    switch (exception) {
      case NetworkException _:
        return !exception.message.contains('certificate') &&
               !exception.message.contains('cancelled');
      case ServerException _:
        return true;
      case WebSocketException _:
        return true;
      default:
        return false;
    }
  }

  static Duration getRetryDelay(int attemptNumber) {
    // Exponential backoff: 1s, 2s, 4s, 8s, etc.
    final delay = Duration(seconds: (1 << attemptNumber).clamp(1, 30));
    return delay;
  }
}