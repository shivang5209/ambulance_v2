import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// TacDeviceCard — ESP32 / IoT device status card.
///
/// Design decisions:
///   • Pulsing green dot for online devices uses a [RepeatableScaleTransition]
///     (1.0 → 1.3 → 1.0, 1000ms) to draw attention to live devices without
///     being distracting.  Offline devices show a static grey dot.
///   • Battery bar is a thin (4px) progress bar with semantic colours
///     (green/amber/red) so status is readable at small sizes.
///   • Device name uses SpaceGrotesk (heading family) while metadata uses
///     DM Sans (body family) — consistent with the rest of the design system.
///
/// Usage:
/// ```dart
/// TacDeviceCard(
///   deviceId: 'IOT-003',
///   deviceName: 'Ambulance Unit 3',
///   isOnline: true,
///   ipAddress: '192.168.1.103',
///   batteryLevel: 0.72,
///   lastSeen: 'Just now',
/// )
/// ```
class TacDeviceCard extends StatefulWidget {
  const TacDeviceCard({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.isOnline,
    this.ipAddress,
    this.batteryLevel,
    this.lastSeen,
    this.onTap,
  });

  /// Short identifier (e.g. "IOT-003") shown below the device name.
  final String deviceId;

  /// Human-readable device name (e.g. "Ambulance Unit 3").
  final String deviceName;

  /// Whether the device is currently reachable.
  final bool isOnline;

  /// Optional IP address string displayed when the device is online.
  final String? ipAddress;

  /// Battery level 0.0 – 1.0. When null the battery bar is hidden.
  final double? batteryLevel;

  /// Human-readable last-seen timestamp (e.g. "Just now", "3 min ago").
  final String? lastSeen;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  State<TacDeviceCard> createState() => _TacDeviceCardState();
}

class _TacDeviceCardState extends State<TacDeviceCard>
    with SingleTickerProviderStateMixin {
  // Design: 1000ms pulse with repeat — matches the "emergency pulse" spec.
  // Only created when the device is online (no wasted animation for offline).
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(TacDeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && _pulseController == null) {
      _startPulse();
    } else if (!widget.isOnline && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
      _pulseAnimation = null;
    }
  }

  void _startPulse() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Design: scale 1.0 → 1.3 → 1.0 — clear pulse without feeling aggressive.
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ----------------------------------------------------------------
            // Top row: icon + device name + status dot
            // ----------------------------------------------------------------
            Row(
              children: [
                _DeviceIcon(isOnline: widget.isOnline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.deviceName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.deviceId,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Online pulse / offline dot
                _StatusDot(
                  isOnline: widget.isOnline,
                  animation: _pulseAnimation,
                ),
              ],
            ),

            // ----------------------------------------------------------------
            // Battery bar
            // ----------------------------------------------------------------
            if (widget.batteryLevel != null) ...[
              const SizedBox(height: 14),
              _BatteryBar(
                level: widget.batteryLevel!.clamp(0.0, 1.0),
                textColor: textSecondary,
              ),
            ],

            // ----------------------------------------------------------------
            // Metadata row: IP + last seen
            // ----------------------------------------------------------------
            if (widget.ipAddress != null || widget.lastSeen != null) ...[
              const SizedBox(height: 10),
              _MetaRow(
                ipAddress: widget.ipAddress,
                lastSeen: widget.lastSeen,
                textColor: textSecondary,
                isOnline: widget.isOnline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// _DeviceIcon
// ----------------------------------------------------------------------------

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.deviceStatusColor(isOnline);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.sensors_rounded,
        color: color,
        size: 22,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// _StatusDot
// ----------------------------------------------------------------------------

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.isOnline,
    this.animation,
  });

  final bool isOnline;

  /// Scale animation (only provided when online).
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.deviceStatusColor(isOnline);
    const dotSize = 10.0;

    if (!isOnline || animation == null) {
      // Static grey dot for offline devices
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    // Pulsing green dot for online devices
    return AnimatedBuilder(
      animation: animation!,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring scales with the animation
            Transform.scale(
              scale: animation!.value,
              child: Container(
                width: dotSize + 4,
                height: dotSize + 4,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Inner solid dot stays the same size
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// _BatteryBar
// ----------------------------------------------------------------------------

class _BatteryBar extends StatelessWidget {
  const _BatteryBar({
    required this.level,
    required this.textColor,
  });

  /// Clamped 0.0 – 1.0.
  final double level;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = AppColors.batteryColor(level);
    final trackColor = isDark
        ? AppColors.darkSurfaceElevated
        : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _batteryIcon(),
              color: barColor,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '${(level * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: barColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Design: 4px height — thin enough to not dominate the card but
        // readable as a proportional indicator.
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: level,
            minHeight: 4,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  IconData _batteryIcon() {
    if (level > 0.75) return Icons.battery_full_rounded;
    if (level > 0.5) return Icons.battery_5_bar_rounded;
    if (level > 0.25) return Icons.battery_3_bar_rounded;
    if (level > 0.1) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}

// ----------------------------------------------------------------------------
// _MetaRow
// ----------------------------------------------------------------------------

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.textColor,
    required this.isOnline,
    this.ipAddress,
    this.lastSeen,
  });

  final String? ipAddress;
  final String? lastSeen;
  final Color textColor;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final metaStyle = GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: textColor,
      letterSpacing: 0.2,
    );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (ipAddress != null && isOnline)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lan_outlined, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(ipAddress!, style: metaStyle),
            ],
          ),
        if (lastSeen != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(lastSeen!, style: metaStyle),
            ],
          ),
      ],
    );
  }
}
