import 'dart:async';
import '../models/user.dart';

class MockAuthService {
  // Very simple mock auth. In real app replace with real backend/auth provider.
  // Accepts a few hard-coded id/password combos for each role.
  Future<User> login({
    required UserRole role,
    required String id,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700)); // simulate network

    // sample credentials (for demo only)
    final creds = {
      UserRole.driver: {'driver1': 'pass123'},
      UserRole.citizen: {'citizen1': 'pass123'},
      UserRole.admin: {'admin1': 'adminpass'},
      UserRole.hospitalStaff: {'hospital1': 'hospass'},
    };

    final allowed = creds[role] ?? {};
    if (allowed[id] == password) {
      final name = '${role.toString().split('.').last.toUpperCase()}-$id';
      return User(
        id: id,
        username: id,
        firstName: name,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    throw AuthException('Invalid credentials for ${role.toString().split('.').last}');
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}