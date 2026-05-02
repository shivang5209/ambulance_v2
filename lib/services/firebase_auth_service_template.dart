// FIREBASE AUTH SERVICE - Production Ready Implementation
// Copy this file to: lib/services/firebase_auth_service.dart
// Then update login_screen.dart to use this instead of MockAuthService

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user.dart';

class FirebaseAuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ============================================
  // LOGIN
  // ============================================
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authenticate with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw AuthException('Login failed: No user returned');
      }

      // 2. Fetch user profile from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw AuthException('User profile not found in database');
      }

      // 3. Update last login timestamp
      await _updateLastLogin(credential.user!.uid);

      // 4. Save FCM token for push notifications
      await _saveFCMToken(credential.user!.uid);

      // 5. Convert Firestore document to User model
      final userData = userDoc.data()!;
      return User.fromJson({
        'id': userDoc.id,
        ...userData,
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthError(e));
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  // ============================================
  // REGISTER
  // ============================================
  Future<User> register({
    required String email,
    required String password,
    required String username,
    required UserRole role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? hospitalId, // For hospital staff
  }) async {
    try {
      // 1. Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw AuthException('Registration failed: No user created');
      }

      // 2. Create user profile in Firestore
      final now = DateTime.now();
      final user = User(
        id: credential.user!.uid,
        username: username.trim(),
        email: email.trim(),
        firstName: firstName?.trim(),
        lastName: lastName?.trim(),
        role: role,
        hospitalId: hospitalId,
        preferences: {},
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('users')
          .doc(user.id)
          .set(user.toJson());

      // 3. Create role-specific profile
      await _createRoleSpecificProfile(user, phoneNumber);

      // 4. Save FCM token
      await _saveFCMToken(user.id);

      // 5. Send email verification (optional)
      await credential.user!.sendEmailVerification();

      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthError(e));
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  // ============================================
  // LOGOUT
  // ============================================
  Future<void> logout() async {
    try {
      final userId = _auth.currentUser?.uid;

      // 1. Remove FCM token from Firestore
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
          'lastLogout': FieldValue.serverTimestamp(),
        });
      }

      // 2. Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Logout failed: $e');
    }
  }

  // ============================================
  // GET CURRENT USER
  // ============================================
  Future<User?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) return null;

      return User.fromJson({
        'id': userDoc.id,
        ...userDoc.data()!,
      });
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // PASSWORD RESET
  // ============================================
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthError(e));
    }
  }

  // ============================================
  // UPDATE USER PROFILE
  // ============================================
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw AuthException('No user logged in');
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      if (preferences != null) updates['preferences'] = preferences;

      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      throw AuthException('Profile update failed: $e');
    }
  }

  // ============================================
  // CHANGE PASSWORD
  // ============================================
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException('No user logged in');
      }

      // 1. Re-authenticate user
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Update password
      await user.updatePassword(newPassword);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthError(e));
    }
  }

  // ============================================
  // DELETE ACCOUNT
  // ============================================
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException('No user logged in');
      }

      // 1. Re-authenticate
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Delete Firestore data
      await _deleteUserData(user.uid);

      // 3. Delete Firebase Auth account
      await user.delete();
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthError(e));
    }
  }

  // ============================================
  // PRIVATE HELPER METHODS
  // ============================================

  Future<void> _updateLastLogin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveFCMToken(String userId) async {
    try {
      // Request notification permission (iOS)
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token
      final token = await _messaging.getToken();

      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      // Non-critical error, don't throw
      print('FCM token save failed: $e');
    }
  }

  Future<void> _createRoleSpecificProfile(User user, String? phoneNumber) async {
    switch (user.role) {
      case UserRole.driver:
        await _firestore.collection('drivers').doc(user.id).set({
          'userId': user.id,
          'phoneNumber': phoneNumber ?? '',
          'vehicleNumber': '',
          'vehicleType': '',
          'licenseNumber': '',
          'emergencyContacts': [],
          'isOnDuty': false,
          'deviceId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;

      case UserRole.citizen:
        await _firestore.collection('citizens').doc(user.id).set({
          'userId': user.id,
          'phoneNumber': phoneNumber ?? '',
          'trackedDrivers': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;

      case UserRole.hospitalStaff:
        if (user.hospitalId != null) {
          await _firestore.collection('hospitalStaff').doc(user.id).set({
            'userId': user.id,
            'hospitalId': user.hospitalId!,
            'phoneNumber': phoneNumber ?? '',
            'department': '',
            'position': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        break;

      case UserRole.admin:
      case UserRole.dispatcher:
        // No additional profile needed
        break;
    }
  }

  Future<void> _deleteUserData(String userId) async {
    // Delete all user-related data from Firestore
    final batch = _firestore.batch();

    // Delete user profile
    batch.delete(_firestore.collection('users').doc(userId));

    // Delete role-specific profiles
    batch.delete(_firestore.collection('drivers').doc(userId));
    batch.delete(_firestore.collection('citizens').doc(userId));
    batch.delete(_firestore.collection('hospitalStaff').doc(userId));

    await batch.commit();
  }

  String _handleAuthError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address format';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled';
      case 'requires-recent-login':
        return 'Please log in again to perform this action';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  // ============================================
  // AUTH STATE STREAM
  // ============================================

  // Listen to authentication state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is currently logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get current Firebase user ID
  String? get currentUserId => _auth.currentUser?.uid;
}

// ============================================
// CUSTOM EXCEPTION CLASS
// ============================================
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

// ============================================
// USAGE EXAMPLES
// ============================================

/*
// IN login_screen.dart:

final _authService = FirebaseAuthService();

Future<void> _submit() async {
  try {
    final user = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // Navigate to home based on role
    _navigateToHome(user.role);
  } on AuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}

// IN register_screen.dart:

Future<void> _register() async {
  try {
    final user = await _authService.register(
      email: _emailController.text,
      password: _passwordController.text,
      username: _usernameController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      role: selectedRole,
      phoneNumber: _phoneController.text,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account created! Please verify your email.')),
    );
  } on AuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}

// IN splash_screen.dart (check auth state on app start):

class _SplashScreenState extends State<SplashScreen> {
  final _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(Duration(seconds: 2)); // Show splash

    final user = await _authService.getCurrentUser();

    if (user != null) {
      // User is logged in, go to home
      _navigateToHome(user.role);
    } else {
      // Not logged in, go to user selection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserTypeSelectionScreen()),
      );
    }
  }
}

// IN any screen - LOGOUT:

ElevatedButton(
  onPressed: () async {
    await _authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => UserTypeSelectionScreen()),
      (route) => false,
    );
  },
  child: Text('Logout'),
)

// LISTEN TO AUTH STATE CHANGES (for real-time updates):

StreamBuilder<firebase_auth.User?>(
  stream: FirebaseAuthService().authStateChanges,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }

    if (snapshot.hasData) {
      return HomeScreen(); // User is logged in
    } else {
      return LoginScreen(); // User is logged out
    }
  },
)
*/
