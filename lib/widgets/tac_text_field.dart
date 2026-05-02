import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// TacTextField — labelled input field for the "Ops Dark" design system.
///
/// Design decisions:
///   • Filled dark surface background blends the field into panels while
///     remaining clearly interactive.
///   • Standard [InputDecoration] with [FloatingLabelBehavior.auto] means
///     Flutter animates the label natively — no custom animation code needed.
///   • Error state: red border + red error text below the field; no icon
///     change (avoids layout shifts that disorient operators).
///   • Obscure-text toggle keeps the suffix icon slot consistent; the toggle
///     button uses the secondary text colour so it does not compete with
///     the prefix icon.
///
/// Usage:
/// ```dart
/// TacTextField(
///   controller: _emailController,
///   label: 'Email address',
///   prefixIcon: Icons.email_outlined,
///   keyboardType: TextInputType.emailAddress,
/// )
/// ```
class TacTextField extends StatefulWidget {
  const TacTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.obscureText = false,
    this.errorText,
    this.keyboardType,
    this.onChanged,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
    this.maxLines = 1,
    this.hint,
  });

  /// Text editing controller — caller owns the lifecycle.
  final TextEditingController controller;

  /// Floating label text.
  final String label;

  /// Optional prefix icon in the left slot.
  final IconData? prefixIcon;

  /// Whether to obscure the text (password mode).
  /// An eye toggle button is automatically added in the suffix slot.
  final bool obscureText;

  /// When non-null the field renders in error state with this message.
  final String? errorText;

  /// Keyboard type hint.
  final TextInputType? keyboardType;

  /// Called on every text change.
  final ValueChanged<String>? onChanged;

  /// IME action button (e.g. [TextInputAction.next], [TextInputAction.done]).
  final TextInputAction? textInputAction;

  /// Autofill hints for password managers.
  final Iterable<String>? autofillHints;

  /// Whether the field is interactive.
  final bool enabled;

  /// Maximum lines (defaults to 1 for single-line inputs).
  final int? maxLines;

  /// Placeholder hint text shown when the field is empty and focused.
  final String? hint;

  @override
  State<TacTextField> createState() => _TacTextFieldState();
}

class _TacTextFieldState extends State<TacTextField> {
  // Internal obscure state — toggled by the eye button.
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final labelColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      enabled: widget.enabled,
      maxLines: _obscure ? 1 : widget.maxLines,
      // Design: DM Sans 16sp matches bodyLarge for comfortable reading.
      style: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,

        // Label styles
        labelStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: labelColor,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          color: widget.errorText != null ? AppColors.error : AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: labelColor.withOpacity(0.6),
        ),

        // Error text style
        errorStyle: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.error,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 2,

        // Border states
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // Design: slightly more visible border in error state even when
          // not focused, so the operator spots the issue immediately.
          borderSide: BorderSide(
            color: widget.errorText != null ? AppColors.error : borderColor,
            width: widget.errorText != null ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: widget.errorText != null ? AppColors.error : AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderColor.withOpacity(0.5),
            width: 1,
          ),
        ),

        // Icons
        prefixIcon: widget.prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  widget.prefixIcon,
                  size: 20,
                  color: widget.errorText != null
                      ? AppColors.error
                      : labelColor,
                ),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),

        // Suffix: obscure toggle (only when the field is a password field)
        suffixIcon: widget.obscureText
            ? _ObscureToggle(
                isObscured: _obscure,
                color: labelColor,
                onToggle: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// _ObscureToggle — eye / eye-off icon button
// ----------------------------------------------------------------------------

class _ObscureToggle extends StatelessWidget {
  const _ObscureToggle({
    required this.isObscured,
    required this.color,
    required this.onToggle,
  });

  final bool isObscured;
  final Color color;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isObscured
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 20,
        color: color,
      ),
      onPressed: onToggle,
      // Design: no splash radius — keeps the suffix area clean.
      splashRadius: 18,
      tooltip: isObscured ? 'Show password' : 'Hide password',
    );
  }
}
