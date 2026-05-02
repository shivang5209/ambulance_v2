part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String username;

  const AuthAuthenticated({required this.username});

  @override
  List<Object> get props => [username];
}

class AuthUnauthenticated extends AuthState {}
