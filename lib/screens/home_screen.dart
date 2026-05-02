import 'package:flutter/material.dart';
import 'request_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openRequestForm(BuildContext context) {
    Navigator.of(context).pushNamed('/request');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Ambulance'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_hospital, size: 96, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'Need an ambulance?',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Request quick medical assistance with one tap.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 260,
                      height: 60,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call),
                        label: const Text('Request Ambulance', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => _openRequestForm(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.grey[100],
              child: ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text('Emergency Dispatch'),
                subtitle: const Text('Call: 911 (or local emergency number)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: integrate phone call
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dialing emergency dispatch...')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}