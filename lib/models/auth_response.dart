import 'user.dart';

class AuthResponse {
  final User user;
  final String accessToken;
  final String expiresIn;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns: { status: 'success', data: { user: {...}, tokens: {...} } }
    final data = json['data'] as Map<String, dynamic>;
    final userData = data['user'] as Map<String, dynamic>;
    final tokensData = data['tokens'] as Map<String, dynamic>;

    return AuthResponse(
      user: User.fromJson(userData),
      accessToken: tokensData['accessToken'] as String,
      expiresIn: tokensData['expiresIn'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'accessToken': accessToken,
      'expiresIn': expiresIn,
    };
  }

  @override
  String toString() {
    return 'AuthResponse(user: ${user.email}, expiresIn: $expiresIn)';
  }
}
