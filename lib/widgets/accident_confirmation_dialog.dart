import 'dart:async';

import 'package:flutter/material.dart';

import '../models/accident_prediction.dart';
import '../services/training_data_service.dart';
import '../theme/app_colors.dart';

class AccidentConfirmationDialog extends StatefulWidget {
  final String eventId;
  final AccidentPrediction prediction;
  final TrainingDataService trainingService;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const AccidentConfirmationDialog({
    super.key,
    required this.eventId,
    required this.prediction,
    required this.trainingService,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<AccidentConfirmationDialog> createState() =>
      _AccidentConfirmationDialogState();
}

class _AccidentConfirmationDialogState
    extends State<AccidentConfirmationDialog> {
  static const int _countdownSeconds = 30;

  int _remaining = _countdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _confirmAccident(source: 'auto');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmAccident({required String source}) async {
    _timer?.cancel();
    await widget.trainingService.saveLabel(
      eventId: widget.eventId,
      trueLabel: 'accident',
      labelSource: source,
    );
    widget.onConfirm();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _dismissFalseAlarm() async {
    _timer?.cancel();
    await widget.trainingService.saveLabel(
      eventId: widget.eventId,
      trueLabel: 'false_positive',
      labelSource: 'driver',
    );
    widget.onDismiss();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final confidencePct =
        (widget.prediction.accidentProbability * 100).toStringAsFixed(1);
    final severityColor = _severityColor(widget.prediction.severityClass);
    final progress = _remaining / _countdownSeconds;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).cardColor,
                isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: severityColor.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.emergency_rounded,
                      color: severityColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Possible accident detected',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence $confidencePct% · ${widget.prediction.severityClass}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: severityColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Confirm the event so the app can escalate, or dismiss it as a false alarm. If no action is taken, the system will auto-confirm after the countdown.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _DialogInfoRow(
                label: 'Predicted type',
                value: _titleCase(widget.prediction.accidentType),
              ),
              _DialogInfoRow(
                label: 'Near-miss score',
                value:
                    '${(widget.prediction.nearMissProbability * 100).toStringAsFixed(1)}%',
              ),
              _DialogInfoRow(
                label: 'Normal score',
                value:
                    '${(widget.prediction.normalProbability * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: severityColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(severityColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Auto-confirm in $_remaining seconds',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dismissFalseAlarm,
                      child: const Text('False alarm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAccident(source: 'driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: severityColor,
                      ),
                      child: const Text('Confirm accident'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
      case 'severe':
        return AppColors.error;
      case 'moderate':
        return AppColors.accent;
      case 'minor':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String _titleCase(String input) {
    if (input.isEmpty) return 'Unknown';
    final words = input.replaceAll('_', ' ').split(' ');
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
