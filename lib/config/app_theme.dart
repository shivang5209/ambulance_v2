/// lib/config/app_theme.dart
///
/// BACKWARD-COMPATIBILITY SHIM
///
/// All existing screens import this file as:
///   import '../config/app_theme.dart';
///
/// This file re-exports the new AppTheme class (lib/theme/app_theme.dart) so
/// that every reference to AppTheme.primary, AppTheme.neumorphicShadow(), etc.
/// continues to compile without any changes to the screen files.
///
/// New code should import from lib/theme/ directly.
library;

export 'package:ambulance_v2/theme/app_theme.dart';
export 'package:ambulance_v2/theme/app_colors.dart';
export 'package:ambulance_v2/theme/app_typography.dart';
