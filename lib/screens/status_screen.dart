import 'package:flutter/material.dart';
import '../models/ambulance_request.dart';
import '../services/mock_ambulance_service.dart';

class StatusScreenArgs {
  final AmbulanceRequest request;
  final AmbulanceResponse response;

  StatusScreenArgs({required this.request, required this.response});
}

class StatusScreen extends StatefulWidget {
  static const routeName = '/status';

  final AmbulanceRequest request;
  final AmbulanceResponse response;

  const StatusScreen(
      {super.key, required this.request, required this.response});

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _service = MockAmbulanceService();
  bool _cancelling = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _status = widget.response.status;
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    final ok = await _service.cancelRequest(widget.response.ambulanceId);
    setState(() {
      _cancelling = false;
      _status = ok ? 'cancelled' : _status;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Request cancelled' : 'Unable to cancel now'),
      ),
    );
    if (ok) {
      // after cancelling, go back to home
      await Future.delayed(const Duration(milliseconds: 600));
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resp = widget.response;
    return Scaffold(
      appBar: AppBar(title: const Text('Request Status')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.local_hospital, color: Colors.red),
                title: Text('Ambulance ${resp.ambulanceId}'),
                subtitle: Text('Status: ${_status.toUpperCase()}'),
                trailing: Text('${resp.etaMinutes} min'),
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Patient', widget.request.patientName),
            _infoRow('Phone', widget.request.phone),
            _infoRow('Address', widget.request.address),
            _infoRow('Severity', widget.request.severity),
            _infoRow('Route Algo', resp.routeAlgorithm.toUpperCase()),
            const SizedBox(height: 20),
            _cancelling
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _status == 'dispatched' ? _cancel : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                    ),
                  ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // return to home to place a new request
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Back to Home'),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
