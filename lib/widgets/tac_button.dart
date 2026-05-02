import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Visual variants for [TacButton].
enum TacButtonVariant {
  /// Filled blue — primary action.
  primary,

  /// Filled red — destructive / emergency action.
  danger,

  /// Transparent with blue border — secondary action.
  outlined,

  /// No fill, no border — subtle tertiary action.
  ghost,
}

/// TacButton — full-width action button for the "Ops Dark" design system.
///
/// Design decisions:
///   • 52px height matches comfortable thumb-tap area on mobile.
///   • 12px border radius is softer than sharp corners but not pill-shaped —
///     feels authoritative without being aggressive.
///   • Opacity animation on disable clearly signals unavailability without
///     changing the button's shape/size (avoids layout shifts).
///   • Loading state preserves the button's full footprint so the UI
///     does not jump when async work starts/ends.
///
/// Usage:
/// ```dart
/// TacButton(
///   label: 'Dispatch Ambulance',
///   onPressed: _dispatch,
///   variant: TacButtonVariant.danger,
///   icon: Icons.local_shipping,
/// )
/// ```
class TacButton extends StatelessWidget {
  const TacButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TacButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  /// Button label text.
  final String label;

  /// Tap handler; pass null to disable the button.
  final VoidCallback? onPressed;

  /// Visual style variant.
  final TacButtonVariant variant;

  /// Optional leading icon.
  final IconData? icon;

  /// When true the label is replaced by a small circular progress indicator.
  final bool isLoading;

  // --------------------------------------------------------------------------
  // Derived style properties
  // --------------------------------------------------------------------------

  bool get _isDisabled => onPressed == null || isLoading;

  Color _backgroundColor() {
    switch (variant) {
      case TacButtonVariant.primary:
        return AppColors.primary;
      case TacButtonVariant.danger:
        return AppColors.error;
      case TacButtonVariant.outlined:
      case TacButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _foregroundColor() {
    switch (variant) {
      case TacButtonVariant.primary:
      case TacButtonVariant.danger:
        return AppColors.darkTextPrimary; // white-ish on coloured fill
      case TacButtonVariant.outlined:
        return AppColors.primary;
      case TacButtonVariant.ghost:
        return AppColors.primary;
    }
  }

  BorderSide _borderSide() {
    switch (variant) {
      case TacButtonVariant.outlined:
        return const BorderSide(color: AppColors.primary, width: 1.5);
      case TacButtonVariant.primary:
      case TacButtonVariant.danger:
      case TacButtonVariant.ghost:
        return BorderSide.none;
    }
  }

  Color _progressColor() {
    switch (variant) {
      case TacButtonVariant.primary:
      case TacButtonVariant.danger:
        return AppColors.darkTextPrimary;
      case TacButtonVariant.outlined:
      case TacButtonVariant.ghost:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Design: AnimatedOpacity wraps the whole button so the fade happens
    // at the widget level — no separate disabled-colour calculation needed.
    return AnimatedOpacity(
      opacity: _isDisabled ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: _isDisabled ? BorderSide.none : _borderSide(),
    );

    return ElevatedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _backgroundColor(),
        foregroundColor: _foregroundColor(),
        disabledBackgroundColor: _backgroundColor(),
        disabledForegroundColor: _foregroundColor(),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        // Prevent Flutter's default disabled colour override
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      // Design: 20×20 indicator centred in the button — small enough to not
      // feel intrusive but large enough to be unambiguous.
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_progressColor()),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          _labelText(),
        ],
      );
    }

    return _labelText();
  }

  Widget _labelText() {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: _foregroundColor(),
      ),
    );
  }
}
