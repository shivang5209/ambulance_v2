import 'package:flutter/material.dart';

/// AppColors — "Ops Dark" tactical emergency color system.
///
/// Dark-first palette inspired by air-traffic-control dashboards and
/// Apple Health. Every semantic color has both a dark and a light variant.
/// Widgets must always use Theme.of(context).colorScheme where possible;
/// these constants are the source-of-truth that feeds into ThemeData.
class AppColors {
  // ---------------------------------------------------------------------------
  // Constructor guard — this class is purely static.
  // ---------------------------------------------------------------------------
  AppColors._();

  // ---------------------------------------------------------------------------
  // DARK-THEME SURFACES
  // ---------------------------------------------------------------------------

  /// Deepest background layer — obsidian base. hsl(222,24%,7%)
  static const Color darkBackground = Color(0xFF0D1117);

  /// Card / panel surface — one step up from background. hsl(222,20%,11%)
  static const Color darkSurface = Color(0xFF161C2D);

  /// Elevated panel / modal surface. hsl(222,18%,16%)
  static const Color darkSurfaceElevated = Color(0xFF1E2640);

  // ---------------------------------------------------------------------------
  // LIGHT-THEME SURFACES
  // ---------------------------------------------------------------------------

  /// Page background in light mode.
  static const Color lightBackground = Color(0xFFF4F6FC);

  /// Card / panel surface in light mode.
  static const Color lightSurface = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------------------------

  /// Primary text on dark surfaces.
  static const Color darkTextPrimary = Color(0xFFF5F5F5);

  /// Secondary / muted text on dark surfaces.
  static const Color darkTextSecondary = Color(0xFF8B93AD);

  /// Primary text on light surfaces.
  static const Color lightTextPrimary = Color(0xFF111827);

  /// Secondary / muted text on light surfaces.
  static const Color lightTextSecondary = Color(0xFF6B7494);

  // ---------------------------------------------------------------------------
  // BRAND / SIGNAL COLORS  (same in both themes)
  // ---------------------------------------------------------------------------

  /// Tactical blue — primary interactive color. hsl(213,90%,58%)
  static const Color primary = Color(0xFF1A91F0);

  /// Emergency orange — high-urgency accent.
  static const Color accent = Color(0xFFF55C15);

  /// Success / safe-state green. hsl(152,65%,45%)
  static const Color success = Color(0xFF27A86B);

  /// Amber warning.
  static const Color warning = Color(0xFFF5A612);

  /// Critical-red error / alert.
  static const Color error = Color(0xFFE8384F);

  // ---------------------------------------------------------------------------
  // BORDER
  // ---------------------------------------------------------------------------

  /// Subtle border colour for cards and inputs (dark theme).
  static const Color border = Color(0xFF27304F);

  /// Subtle border colour for cards and inputs (light theme).
  static const Color lightBorder = Color(0xFFDDE2F0);

  // ---------------------------------------------------------------------------
  // BACKWARD-COMPATIBILITY ALIASES
  // (Existing screens reference AppTheme.xxx constants; those are re-exported
  // from lib/config/app_theme.dart which delegates here, so these aliases keep
  // everything compiling without touching the screen files.)
  // ---------------------------------------------------------------------------

  /// Alias kept for screens that reference the old monitoringActive colour.
  static const Color monitoringActive = Color(0xFF3B82F6);

  /// Alias kept for screens that reference emergencyResponse.
  static const Color emergencyResponse = Color(0xFFF97316);

  /// Alias kept for screens that reference normalOperation.
  static const Color normalOperation = Color(0xFF059669);

  /// Alias kept for screens that reference accidentDetected.
  static const Color accidentDetected = Color(0xFFDC2626);

  // ---------------------------------------------------------------------------
  // SEMANTIC HELPERS
  // ---------------------------------------------------------------------------

  /// Returns the severity colour for a string severity tag.
  /// Accepted values: 'critical', 'warning', 'info'.
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return error;
      case 'warning':
        return warning;
      case 'info':
      default:
        return primary;
    }
  }

  /// Returns a very-low-opacity tint of a severity colour (for card backgrounds).
  static Color severityTint(String severity) {
    return severityColor(severity).withOpacity(0.05);
  }

  /// Battery level → semantic colour.
  static Color batteryColor(double level) {
    if (level > 0.5) return success;
    if (level > 0.2) return warning;
    return error;
  }

  /// Device status dot colour.
  static Color deviceStatusColor(bool isOnline) {
    return isOnline ? success : const Color(0xFF4B5563);
  }
}
