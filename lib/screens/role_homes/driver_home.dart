import 'package:flutter/material.dart';
import '../../models/user.dart';

class DriverHome extends StatelessWidget {
  final User user;
  const DriverHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver - ${user.fullName}'),
      ),
      body: const Center(
        child: Text('Driver dashboard (placeholder)\nAdd ride accept / location tracking here.',
            textAlign: TextAlign.center),
      ),
    );
  }
}