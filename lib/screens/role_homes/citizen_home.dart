import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../home_screen.dart' show HomeScreen; // reuse home if needed

class CitizenHome extends StatelessWidget {
  final User user;
  const CitizenHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Citizen - ${user.fullName}'),
      ),
      body: const Center(
        child: Text('Citizen dashboard (placeholder)\nRequest ambulance and see status here.',
            textAlign: TextAlign.center),
      ),
    );
  }
}