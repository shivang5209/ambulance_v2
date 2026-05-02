import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/firebase_auth_service.dart';
import '../services/secure_storage_service.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsRoleSelection, // New Google user — must pick a role before profile is created
  error,
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService;
  final SecureStorageService _storageService;

  User? _currentUser;
  String? _token;
  AuthState _state = AuthState.initial;
  String? _errorMessage;

  AuthProvider(this._authService, this._storageService);

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated && _currentUser != null;
  bool get isLoading => _state == AuthState.loading;
  bool get needsRoleSelection => _state == AuthState.needsRoleSelection;

  // Check authentication status on app start
  Future<void> checkAuthStatus() async {
    try {
      _setState(AuthState.loading);

      final token = await _storageService.getToken();
      final user = await _storageService.getUser();

      if (token != null && user != null) {
        _token = token;
        _currentUser = user;
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setError('Failed to check authentication status');
      _setState(AuthState.unauthenticated);
    }
  }

  // Login
  Future<bool> login({required String email, required String password}) async {
    try {
      _setState(AuthState.loading);
      _errorMessage = null;

      final user = await _authService.login(
        email: email,
        password: password,
      );

      final token = await _authService.getIdToken();

      if (token != null) {
        await _storageService.saveToken(token);
        await _storageService.saveUser(user);
        _token = token;
        _currentUser = user;
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError('Failed to get token');
        _setState(AuthState.error);
        return false;
      }
    } on AuthException catch (e) {
      _setError(e.message);
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setState(AuthState.error);
      return false;
    }
  }

  // Google Sign-In
  // Returns true  → existing user, authenticated, navigate to home
  // Returns false → new user, state = needsRoleSelection, show role picker
  Future<bool> loginWithGoogle() async {
    try {
      _setState(AuthState.loading);
      _errorMessage = null;

      final result = await _authService.signInWithGoogle();

      if (!result.isNewUser) {
        // Existing user — complete sign-in
        final token = await _authService.getIdToken();
        if (token != null) {
          await _storageService.saveToken(token);
          await _storageService.saveUser(result.existingUser!);
          _token = token;
          _currentUser = result.existingUser;
          _setState(AuthState.authenticated);
          return true;
        } else {
          _setError('Failed to get token');
          _setState(AuthState.error);
          return false;
        }
      } else {
        // New user — needs to pick a role first
        _setState(AuthState.needsRoleSelection);
        return false;
      }
    } on AuthException catch (e) {
      _setError(e.message);
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setState(AuthState.error);
      return false;
    }
  }

  // Called after new Google user picks their role
  Future<bool> completeGoogleSignIn({required UserRole role}) async {
    try {
      _setState(AuthState.loading);
      _errorMessage = null;

      final user = await _authService.completeGoogleRegistration(role: role);
      final token = await _authService.getIdToken();

      if (token != null) {
        await _storageService.saveToken(token);
        await _storageService.saveUser(user);
        _token = token;
        _currentUser = user;
        _setState(AuthState.authenticated);
        return true;
      } else {
        _setError('Failed to get token');
        _setState(AuthState.error);
        return false;
      }
    } on AuthException catch (e) {
      _setError(e.message);
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setState(AuthState.error);
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required UserRole role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? hospitalId,
  }) async {
    try {
      _setState(AuthState.loading);
      _errorMessage = null;

      await _authService.register(
        email: email,
        password: password,
        username: username,
        role: role,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        hospitalId: hospitalId,
      );

      _setState(AuthState.unauthenticated);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', ''));
      _setState(AuthState.error);
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      _setState(AuthState.loading);
      await _storageService.clearAll();
      _token = null;
      _currentUser = null;
      _errorMessage = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      await _storageService.clearAll();
      _token = null;
      _currentUser = null;
      _errorMessage = null;
      _setState(AuthState.unauthenticated);
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Private helpers
  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
}
