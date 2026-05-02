import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hotspot_zone.dart';

/// Non-intrusive animated banner shown at the top of the driver screen
/// when the vehicle enters a hotspot zone's warning radius (500 m buffer).
///
/// Auto-dismisses after 10 seconds or when manually swiped away.
/// Color intensity scales from amber (severity 1) → red (severity 4).
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
  State<HotspotWarningBanner> createState() =>
      _HotspotWarningBannerState();
}

class _HotspotWarningBannerState extends State<HotspotWarningBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    _autoTimer = Timer(const Duration(seconds: 10), _dismiss);
  }

  void _dismiss() {
    _autoTimer?.cancel();
    _controller.reverse().then((_) => widget.onDismiss?.call());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(widget.zone.severityLevel);
    final distKm = (widget.distanceMeters / 1000).toStringAsFixed(1);
    final peakInfo = widget.zone.peakHours.isNotEmpty
        ? widget.zone.peakHours.first
        : 'any time';

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: _dismiss,
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -200) {
              _dismiss();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.95), color.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // ── Icon ──────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),

                // ── Text block ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'ACCIDENT HOTSPOT — $distKm km ahead',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.zone.incidentCount} incidents  •  Peak: $peakInfo  '
                        '•  ${widget.zone.weatherFactor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ── Severity badge ────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _severityLabel(widget.zone.severityLevel),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _severityColor(int level) {
    switch (level) {
      case 4: return const Color(0xFFDC2626); // critical – red
      case 3: return const Color(0xFFEA580C); // severe – deep orange
      case 2: return const Color(0xFFF59E0B); // moderate – amber
      default: return const Color(0xFF16A34A); // low – green
    }
  }

  String _severityLabel(int level) {
    switch (level) {
      case 4: return '🔴 CRITICAL';
      case 3: return '🟠 HIGH';
      case 2: return '🟡 MED';
      default: return '🟢 LOW';
    }
  }
}
