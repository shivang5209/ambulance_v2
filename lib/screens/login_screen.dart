import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'role_home_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String get _roleLabel => widget.role.toString().split('.').last.toUpperCase();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.login(
      email: _idCtrl.text.trim(),
      password: _pwCtrl.text,
    );

    if (!mounted) return;

    if (success && authProvider.currentUser != null) {
      final home = buildHomeForRole(authProvider.currentUser!.role);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => home),
      );
    } else {
      // Show error message
      final errorMsg = authProvider.errorMessage ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading;

    final hintId = {
      UserRole.driver: 'driver1',
      UserRole.citizen: 'citizen1',
      UserRole.admin: 'admin1',
      UserRole.hospitalStaff: 'hospital1',
    }[widget.role];

    final hintPw = {
      UserRole.driver: 'pass123',
      UserRole.citizen: 'pass123',
      UserRole.admin: 'adminpass',
      UserRole.hospitalStaff: 'hospass',
    }[widget.role];

    return Scaffold(
      appBar: AppBar(title: Text('Login ($_roleLabel)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text('Enter credentials for $_roleLabel',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idCtrl,
                      decoration:
                          InputDecoration(labelText: 'ID', hintText: hintId),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pwCtrl,
                      decoration: InputDecoration(
                          labelText: 'Password', hintText: hintPw),
                      obscureText: true,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: Text('Login'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        // Navigate to registration screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(),
                          ),
                        );
                      },
                      child:
                          const Text('Don\'t have an account? Register here'),
                    ),
                    TextButton(
                      onPressed: () {
                        // go back to user type selection
                        Navigator.of(context).pushReplacementNamed('/');
                      },
                      child: const Text('Change user type'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
