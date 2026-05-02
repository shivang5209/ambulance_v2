import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Application-wide icon configuration
/// Use these widgets consistently throughout the app
class AppIcons {
  // Primary app icon - Medical Plus in a box
  static Widget appIcon({
    double size = 48,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primary,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AppTheme.primary).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.local_hospital,
        size: size * 0.6,
        color: iconColor ?? Colors.white,
      ),
    );
  }

  // App icon with pulse animation (for splash screens)
  static Widget pulsatingAppIcon({
    double size = 100,
    required Animation<double> animation,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: size + (animation.value * 10),
          height: size + (animation.value * 10),
          decoration: BoxDecoration(
            color: (backgroundColor ?? AppTheme.primary)
                .withValues(alpha: 0.1 + (0.9 * animation.value)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: appIcon(
              size: size * (0.9 + 0.1 * animation.value),
              backgroundColor: backgroundColor,
              iconColor: iconColor,
            ),
          ),
        );
      },
    );
  }

  // Circular app icon (for avatars, profile pics)
  static Widget circularAppIcon({
    double size = 48,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AppTheme.primary).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.local_hospital,
        size: size * 0.5,
        color: iconColor ?? Colors.white,
      ),
    );
  }

  // App logo with text
  static Widget appLogoWithText({
    double iconSize = 48,
    TextStyle? textStyle,
    Color? iconBackgroundColor,
    Color? iconColor,
    MainAxisAlignment alignment = MainAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        appIcon(
          size: iconSize,
          backgroundColor: iconBackgroundColor,
          iconColor: iconColor,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ambulance Service',
              style: textStyle ??
                  TextStyle(
                    fontSize: iconSize * 0.4,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
            ),
            Text(
              'Emergency Response',
              style: textStyle?.copyWith(
                    fontSize: (iconSize * 0.4) * 0.6,
                    fontWeight: FontWeight.w400,
                  ) ??
                  TextStyle(
                    fontSize: (iconSize * 0.4) * 0.6,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.primary.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  // Medical Plus icon (standalone)
  static const IconData medicalPlus = Icons.local_hospital;

  // Other commonly used icons
  static const IconData ambulance = Icons.local_hospital;
  static const IconData emergency = Icons.emergency;
  static const IconData firstAid = Icons.medical_services;
  static const IconData hospital = Icons.local_hospital;
  static const IconData driver = Icons.drive_eta;
  static const IconData family = Icons.family_restroom;
  static const IconData admin = Icons.admin_panel_settings;
}
