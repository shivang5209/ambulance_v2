import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hotspot_zone.dart';
import '../theme/app_colors.dart';

class HotspotWarningBanner extends StatefulWidget {
  final HotspotZone zone;
  final double distanceMeters;
  final VoidCallback? onDismiss;

  const HotspotWarningBanner({
    super.key,
    required this.zone,
    required this.distanceMeters,
    this.onDismiss,
  });

  @override
  State<HotspotWarningBanner> createState() => _HotspotWarningBannerState();
}

class _HotspotWarningBannerState extends State<HotspotWarningBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _autoTimer = Timer(const Duration(seconds: 10), _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(widget.zone.severityLevel);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distanceLabel = widget.distanceMeters >= 1000
        ? '${(widget.distanceMeters / 1000).toStringAsFixed(1)} km ahead'
        : '${widget.distanceMeters.round()} m ahead';
    final peakWindow = widget.zone.peakHours.isNotEmpty
        ? widget.zone.peakHours.first
        : 'all day';

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                severityColor.withValues(alpha: isDark ? 0.24 : 0.18),
                severityColor.withValues(alpha: isDark ? 0.14 : 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: severityColor.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: severityColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'High-risk hotspot ahead',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          distanceLabel,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: severityColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.zone.incidentCount} incidents · Peak $peakWindow · ${widget.zone.weatherFactor}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                    .withValues(alpha: 0.74)
                                : AppColors.lightTextSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(int level) {
    switch (level) {
      case 4:
        return AppColors.error;
      case 3:
        return AppColors.accent;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }
}
