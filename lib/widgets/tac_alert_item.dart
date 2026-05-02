import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Severity values accepted by [TacAlertItem].
///
/// Using typed constants instead of raw strings prevents mistyping.
class TacAlertSeverity {
  TacAlertSeverity._();
  static const String critical = 'critical';
  static const String warning = 'warning';
  static const String info = 'info';
}

/// TacAlertItem — a single row in an alert feed.
///
/// Visual language:
///   • 3px left accent bar — colour-coded by severity so operators can triage
///     at a glance even in peripheral vision.
///   • Matching severity icon reinforces the signal.
///   • Subtle background tint ties the row to its severity category without
///     overwhelming dark surfaces.
///
/// Usage:
/// ```dart
/// TacAlertItem(
///   message: 'High G-force detected on IOT-003',
///   time: '2 min ago',
///   severity: TacAlertSeverity.critical,
///   location: 'Zone B-4',
/// )
/// ```
class TacAlertItem extends StatelessWidget {
  const TacAlertItem({
    super.key,
    required this.message,
    required this.time,
    required this.severity,
    this.location,
  });

  /// Main alert description text.
  final String message;

  /// Human-readable timestamp (e.g. "2 min ago", "14:32").
  final String time;

  /// One of 'critical', 'warning', 'info'.
  final String severity;

  /// Optional location string appended after the timestamp.
  final String? location;

  // --------------------------------------------------------------------------
  // Severity helpers
  // --------------------------------------------------------------------------

  Color _accentColor() {
    switch (severity.toLowerCase()) {
      case TacAlertSeverity.critical:
        return AppColors.error;
      case TacAlertSeverity.warning:
        return AppColors.warning;
      case TacAlertSeverity.info:
      default:
        return AppColors.primary;
    }
  }

  IconData _icon() {
    switch (severity.toLowerCase()) {
      case TacAlertSeverity.critical:
        return Icons.error_rounded;
      case TacAlertSeverity.warning:
        return Icons.warning_rounded;
      case TacAlertSeverity.info:
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accent = _accentColor();
    final icon = _icon();

    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Design: 5% accent tint on the background keeps the row visually
    // grouped without creating visual noise on dark surfaces.
    final bgTint = accent.withOpacity(0.05);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------------------------------------------------------------------
          // Left accent bar
          // Design: 3px width is narrow enough to be unobtrusive yet wide
          // enough to be colour-identifiable in peripheral vision.
          // ------------------------------------------------------------------
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                bottomLeft: Radius.circular(3),
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // Content
          // ------------------------------------------------------------------
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: bgTint,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      icon,
                      color: accent,
                      size: 18,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Message
                        Text(
                          message,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Time + optional location
                        _MetaLine(
                          time: time,
                          location: location,
                          textColor: textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// _MetaLine — timestamp and optional location in caption style
// ----------------------------------------------------------------------------

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.time,
    required this.textColor,
    this.location,
  });

  final String time;
  final String? location;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: textColor,
      letterSpacing: 0.2,
    );

    if (location == null) {
      return Text(time, style: style);
    }

    return Row(
      children: [
        Text(time, style: style),
        Text(
          '  ·  ',
          style: style.copyWith(
            color: textColor.withOpacity(0.5),
          ),
        ),
        Expanded(
          child: Text(
            location!,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
