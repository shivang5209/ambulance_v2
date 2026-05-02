import 'package:flutter/material.dart';
import '../../models/user.dart';

class HospitalHome extends StatelessWidget {
  final User user;
  const HospitalHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hospital - ${user.fullName}'),
      ),
      body: const Center(
        child: Text('Hospital dashboard (placeholder)\nManage incoming patients and alerts.',
            textAlign: TextAlign.center),
      ),
    );
  }
}