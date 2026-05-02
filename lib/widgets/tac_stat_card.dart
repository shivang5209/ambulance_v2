import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive_helper.dart';
import '../theme/app_colors.dart';

/// TacStatCard — tactical KPI / statistic card.
///
/// Shows a single labelled metric with an icon and an optional trend
/// indicator. Responds to taps with a subtle scale-down animation to give
/// tactile feedback in high-stress situations.
///
/// Usage:
/// ```dart
/// TacStatCard(
///   title: 'Response Time',
///   value: '1.2s',
///   icon: Icons.speed,
///   accentColor: AppColors.success,
///   subtitle: 'Avg API response',
///   trend: -12.5,  // negative = improvement for time metrics
/// )
/// ```
class TacStatCard extends StatefulWidget {
  const TacStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.subtitle,
    this.trend,
    this.onTap,
  });

  /// Short label displayed below the value (e.g. "Avg API response").
  final String title;

  /// Primary large numeric / text value (e.g. "1.2s", "142").
  final String value;

  /// Icon displayed in the coloured container in the top-left.
  final IconData icon;

  /// Colour applied to the icon container and trend indicator.
  final Color accentColor;

  /// Optional secondary descriptor line under the title.
  final String? subtitle;

  /// Optional trend percentage.
  /// Positive values → increase (good or bad depending on context).
  /// Negative values → decrease.
  /// The sign determines arrow direction; the colour is always semantic.
  final double? trend;

  /// Optional tap handler; the card itself is tappable even without this.
  final VoidCallback? onTap;

  @override
  State<TacStatCard> createState() => _TacStatCardState();
}

class _TacStatCardState extends State<TacStatCard>
    with SingleTickerProviderStateMixin {
  // Design: 0.97 scale on press gives subtle tactile feedback without
  // being distracting in an emergency dashboard context.
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _isPressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _isPressed = false);
  void _onTapCancel() => setState(() => _isPressed = false);

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
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        // Design: 200ms easeOutCubic — fast enough to not feel laggy
        // during rapid dashboard interactions.
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(ResponsiveHelper.value(context, mobile: 16.0, desktop: 24.0)),
          decoration: BoxDecoration(
            color: _isPressed
                ? cardColor.withOpacity(0.9)
                : cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isPressed ? 0.12 : 0.25),
                blurRadius: _isPressed ? 8 : 20,
                offset: _isPressed
                    ? const Offset(0, 2)
                    : const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --------------------------------------------------------
              // Top row: icon container + optional trend badge
              // --------------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconContainer(
                    icon: widget.icon,
                    accentColor: widget.accentColor,
                  ),
                  const Spacer(),
                  if (widget.trend != null)
                    _TrendBadge(trend: widget.trend!),
                ],
              ),

              const SizedBox(height: 12),

              // --------------------------------------------------------
              // Value — SpaceGrotesk bold, large
              // Design: displayMedium from the type scale keeps the number
              // visually dominant on the card.
              // --------------------------------------------------------
              Text(
                widget.value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: ResponsiveHelper.value(context, mobile: 28.0, desktop: 36.0),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: textPrimary,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // --------------------------------------------------------
              // Title
              // --------------------------------------------------------
              Text(
                widget.title,
                style: GoogleFonts.dmSans(
                  fontSize: ResponsiveHelper.value(context, mobile: 13.0, desktop: 15.0),
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // --------------------------------------------------------
              // Optional subtitle
              // --------------------------------------------------------
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: textSecondary.withOpacity(0.7),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// _IconContainer
// ----------------------------------------------------------------------------

class _IconContainer extends StatelessWidget {
  const _IconContainer({
    required this.icon,
    required this.accentColor,
  });

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    // Design: rounded square (radius 10) at 40×40 keeps the icon visually
    // anchored without dominating the card. 10% opacity fill is subtle enough
    // not to clash with dark surfaces.
    double size = ResponsiveHelper.value(context, mobile: 40.0, desktop: 56.0);
    double iconSize = ResponsiveHelper.value(context, mobile: 20.0, desktop: 28.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: accentColor,
        size: iconSize,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// _TrendBadge
// ----------------------------------------------------------------------------

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    // Design: green for positive, red for negative. Arrow direction mirrors
    // the sign so operators can read the trend at a glance.
    final isPositive = trend >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final icon =
        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label =
        '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
