import 'package:flutter/material.dart';
import '../models/ambulance_request.dart';
import '../services/mock_ambulance_service.dart';
import 'status_screen.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  _RequestFormScreenState createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _severity = 'Critical';
  bool _loading = false;
  final _service = MockAmbulanceService();

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final req = AmbulanceRequest(
      patientName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      severity: _severity,
      notes: _notesCtrl.text.trim(),
      timestamp: DateTime.now(),
    );

    setState(() => _loading = true);
    try {
      final resp = await _service.requestAmbulance(req);
      // go to status screen
      Navigator.of(context).pushReplacementNamed(
        StatusScreen.routeName,
        arguments: StatusScreenArgs(request: req, response: resp),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Request Ambulance')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Patient name'),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone'),
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(labelText: 'Address / Location'),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _severity,
                            items: ['Critical', 'Serious', 'Stable']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _severity = v ?? 'Critical'),
                            decoration: const InputDecoration(labelText: 'Severity'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(labelText: 'Notes (optional)'),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Confirm Request'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ));
  }
}