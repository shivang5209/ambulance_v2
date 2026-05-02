import 'dart:async';

import 'package:flutter/material.dart';

import '../models/accident_prediction.dart';
import '../services/training_data_service.dart';

/// Post-alert dialog shown to the driver when the ML model detects an accident.
///
/// The driver has 30 seconds to confirm or dismiss. If they do nothing,
/// the alert auto-fires (assumes real accident — driver may be incapacitated).
///
/// Both actions write a label to [TrainingDataService] for model retraining.
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
    extends State<AccidentConfirmationDialog>
    with SingleTickerProviderStateMixin {
  static const _countdownSeconds = 30;
  int _remaining = _countdownSeconds;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _autoConfirm();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _autoConfirm() {
    _timer?.cancel();
    widget.trainingService.saveLabel(
      eventId: widget.eventId,
      trueLabel: 'accident',
      labelSource: 'auto',
    );
    widget.onConfirm();
    if (mounted) Navigator.of(context).pop();
  }

  void _handleConfirm() {
    _timer?.cancel();
    widget.trainingService.saveLabel(
      eventId: widget.eventId,
      trueLabel: 'accident',
      labelSource: 'driver',
    );
    widget.onConfirm();
    if (mounted) Navigator.of(context).pop();
  }

  void _handleDismiss() {
    _timer?.cancel();
    widget.trainingService.saveLabel(
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
    final severity = widget.prediction.severityClass;
    final type = widget.prediction.accidentType;
    final progress = _remaining / _countdownSeconds;

    final severityColor = _severityColor(severity);

    return WillPopScope(
      onWillPop: () async => false, // prevent back-button dismissal
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: severityColor.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: severityColor.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Pulsing alert icon ───────────────────────────────
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: severityColor
                        .withOpacity(0.15 + _pulseController.value * 0.25),
                    border: Border.all(color: severityColor, width: 2),
                  ),
                  child: Icon(Icons.warning_amber_rounded,
                      color: severityColor, size: 40),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────
              Text(
                '⚠️ Accident Detected',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'ML Confidence: $confidencePct%',
                style: TextStyle(color: severityColor, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Type: ${type.toUpperCase()}  •  Severity: ${severity.toUpperCase()}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── Countdown bar ────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(severityColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Auto-sending in $_remaining s',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // ── Action buttons ───────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: '❌  False Alarm',
                      color: Colors.white24,
                      textColor: Colors.white70,
                      onTap: _handleDismiss,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: '✅  Real Accident',
                      color: severityColor,
                      textColor: Colors.white,
                      onTap: _handleConfirm,
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
      case 'critical': return const Color(0xFFDC2626);
      case 'severe':   return const Color(0xFFEF4444);
      case 'moderate': return const Color(0xFFF97316);
      default:         return const Color(0xFFF59E0B);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
