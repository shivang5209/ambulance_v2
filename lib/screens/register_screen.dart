import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

import '../widgets/max_width_container.dart';
import '../utils/responsive_helper.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _hospitalIdController = TextEditingController();
  UserRole _selectedRole = UserRole.citizen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Center(
        child: MaxWidthContainer(
          maxWidth: 600,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: 'Username'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (ResponsiveHelper.isDesktop(context)) {
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: InputDecoration(labelText: 'First Name'),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: InputDecoration(labelText: 'Last Name'),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              TextFormField(
                                controller: _firstNameController,
                                decoration: InputDecoration(labelText: 'First Name'),
                              ),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: InputDecoration(labelText: 'Last Name'),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: InputDecoration(labelText: 'Phone Number'),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: InputDecoration(labelText: 'Role'),
                      onChanged: (UserRole? newValue) {
                        setState(() {
                          _selectedRole = newValue!;
                        });
                      },
                      items: UserRole.values.map((UserRole role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(role.toString().split('.').last),
                        );
                      }).toList(),
                    ),
                    if (_selectedRole == UserRole.hospitalStaff)
                      TextFormField(
                        controller: _hospitalIdController,
                        decoration: InputDecoration(labelText: 'Hospital ID'),
                        validator: (value) {
                          if (_selectedRole == UserRole.hospitalStaff &&
                              (value == null || value.isEmpty)) {
                            return 'Please enter your hospital ID';
                          }
                          return null;
                        },
                      ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final authProvider =
                                Provider.of<AuthProvider>(context, listen: false);
                            final success = await authProvider.register(
                              email: _emailController.text,
                              password: _passwordController.text,
                              username: _usernameController.text,
                              role: _selectedRole,
                              firstName: _firstNameController.text,
                              lastName: _lastNameController.text,
                              phoneNumber: _phoneNumberController.text,
                              hospitalId: _hospitalIdController.text,
                            );
                            if (success) {
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      authProvider.errorMessage ?? 'Registration failed'),
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Register'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}