/// Base exception class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException: $message';
}

/// Network related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

/// Authentication related exceptions
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Authorization related exceptions
class AuthorizationException extends AppException {
  const AuthorizationException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'AuthorizationException: $message';
}

/// Validation related exceptions
class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException(super.message, {
    super.code,
    super.originalError,
    this.fieldErrors,
  });

  @override
  String toString() => 'ValidationException: $message';
}

/// Server related exceptions
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'ServerException: $message';
}

/// Resource not found exceptions
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'NotFoundException: $message';
}

/// Location related exceptions
class LocationException extends AppException {
  const LocationException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'LocationException: $message';
}

/// Permission related exceptions
class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'PermissionException: $message';
}

/// Cache related exceptions
class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'CacheException: $message';
}

/// WebSocket related exceptions
class WebSocketException extends AppException {
  const WebSocketException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'WebSocketException: $message';
}

/// File operation related exceptions
class FileException extends AppException {
  const FileException(super.message, {super.code, super.originalError});

  @override
  String toString() => 'FileException: $message';
}