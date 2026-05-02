import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  // Screen type detection
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  // Get value based on screen size
  static T value<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    }
    if (isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  // Responsive spacing scale
  static double spacing(BuildContext context, double baseMobile) {
    if (isDesktop(context)) return baseMobile * 2;
    if (isTablet(context)) return baseMobile * 1.5;
    return baseMobile;
  }

  // Grid column calculator
  static int gridColumns(BuildContext context, {
    int mobile = 2,
    int? tablet,
    int? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? 4;
    if (isTablet(context)) return tablet ?? 3;
    return mobile;
  }
}
