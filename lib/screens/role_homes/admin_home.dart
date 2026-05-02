import 'package:flutter/material.dart';
import '../../models/user.dart';

class AdminHome extends StatelessWidget {
  final User user;
  const AdminHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin (IOT) - ${user.fullName}'),
      ),
      body: const Center(
        child: Text('Admin dashboard (placeholder)\nShow device status, telemetry, vehicle control.',
            textAlign: TextAlign.center),
      ),
    );
  }
}