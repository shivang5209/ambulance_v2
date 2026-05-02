import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// AppTypography — type scale for the "Ops Dark" design system.
///
/// Heading font : Space Grotesk  (authority, structure)
/// Body font    : DM Sans        (legibility under stress)
///
/// All sizes follow Material 3 naming but use bespoke values tuned for
/// emergency-response UIs where data density and legibility are critical.
class AppTypography {
  AppTypography._();

  // ---------------------------------------------------------------------------
  // PUBLIC FACTORY
  // ---------------------------------------------------------------------------

  /// Returns a complete [TextTheme] adapted for [isDark].
  ///
  /// Widgets should consume this through [Theme.of(context).textTheme] —
  /// never call this directly inside a widget.
  static TextTheme textTheme({required bool isDark}) {
    final Color primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      // -----------------------------------------------------------------------
      // DISPLAY  — SpaceGrotesk, large headings / hero numbers
      // -----------------------------------------------------------------------

      // Design: 36sp w700 ls-1.0 — used for single large KPI values (speed, count)
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: primary,
      ),

      // Design: 28sp w700 ls-0.5 — section hero number
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),

      // Design: 22sp w600 — smaller hero / stat value
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),

      // -----------------------------------------------------------------------
      // HEADLINE  — SpaceGrotesk, section titles
      // -----------------------------------------------------------------------

      // Design: 24sp w600 ls-0.3 — top-level section heading
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),

      // Design: 20sp w600 — card / panel heading
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primary,
      ),

      // Design: 18sp w600 — sub-section heading
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primary,
      ),

      // -----------------------------------------------------------------------
      // TITLE  — SpaceGrotesk, list / dialog titles
      // -----------------------------------------------------------------------

      // Design: 18sp w600 — list tile primary text, dialog title
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primary,
      ),

      // Design: 16sp w500 — secondary list title, tab label
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: primary,
      ),

      // Design: 14sp w500 — small title / label heading
      titleSmall: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: primary,
      ),

      // -----------------------------------------------------------------------
      // BODY  — DM Sans, readable prose and data
      // -----------------------------------------------------------------------

      // Design: 16sp w400 — paragraph / description text
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primary,
      ),

      // Design: 14sp w400 — most list / card body text
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primary,
      ),

      // Design: 12sp w400 ls0.2 — secondary info, timestamps
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: secondary,
      ),

      // -----------------------------------------------------------------------
      // LABEL  — DM Sans, buttons / chips / tags
      // -----------------------------------------------------------------------

      // Design: 14sp w600 ls0.5 — button text, prominent label
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: primary,
      ),

      // Design: 12sp w500 ls0.4 — chip text, secondary badge
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: secondary,
      ),

      // Design: 11sp w500 ls0.8 — micro label, status badge
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: secondary,
      ),
    );
  }
}
