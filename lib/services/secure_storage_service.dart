import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class SecureStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Token methods
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // User methods
  Future<void> saveUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<User?> getUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson == null) return null;

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(userMap);
    } catch (e) {
      // If parsing fails, delete corrupted data
      await deleteUser();
      return null;
    }
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ESP32 device bearer token — used to authenticate /sensors and other device endpoints
  static const String _deviceBearerTokenKey = 'esp32_bearer_token';

  Future<void> saveDeviceBearerToken(String token) async {
    await _storage.write(key: _deviceBearerTokenKey, value: token);
  }

  Future<String?> getDeviceBearerToken() async {
    return await _storage.read(key: _deviceBearerTokenKey);
  }

  Future<void> deleteDeviceBearerToken() async {
    await _storage.delete(key: _deviceBearerTokenKey);
  }
}
