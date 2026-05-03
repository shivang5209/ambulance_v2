import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_mode_controller.dart';
import '../theme/app_colors.dart';

class OpsSpacing {
  static const double page = 20;
  static const double card = 20;
  static const double sectionGap = 18;
  static const double tileGap = 14;
  static const double radius = 24;

  const OpsSpacing._();
}

class OpsPalette {
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.border
          : AppColors.lightBorder;

  static Color elevatedSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceElevated
          : const Color(0xFFF7F9FF);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.lightBackground;

  static LinearGradient pageGradient(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [
          Color(0xFF07101E),
          AppColors.darkBackground,
          Color(0xFF10182A),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return const LinearGradient(
      colors: [
        Color(0xFFF8FBFF),
        AppColors.lightBackground,
        Color(0xFFEFF4FF),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  const OpsPalette._();
}

class OpsStatusPill extends StatelessWidget {
  final String label;
  final Color tone;
  final IconData? icon;

  const OpsStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: 12, color: tone),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class OpsSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? tone;
  final Widget? trailing;

  const OpsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.tone,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final sectionTone = tone ?? Theme.of(context).colorScheme.primary;
    final borderColor = sectionTone.withValues(alpha: 0.22);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(OpsSpacing.radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(OpsSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: OpsPalette.textSecondary(context),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class OpsMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;
  final IconData icon;
  final Color tone;

  const OpsMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OpsPalette.elevatedSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OpsPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const Spacer(),
              Icon(Icons.circle, size: 10, color: tone),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: OpsPalette.textSecondary(context),
                  letterSpacing: 0.8,
                ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OpsPalette.textSecondary(context),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class OpsInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const OpsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: OpsPalette.textSecondary(context),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class OpsActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  const OpsActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: tone.withValues(alpha: 0.12),
          foregroundColor: tone,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: tone.withValues(alpha: 0.24)),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class OpsSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const OpsSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OpsPalette.textSecondary(context),
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class OpsSparklineCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final Color tone;
  final List<double> points;

  const OpsSparklineCard({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.tone,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OpsPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 78,
            child: CustomPaint(
              painter: _SparklinePainter(
                points: points,
                tone: tone,
                backgroundTone: OpsPalette.border(context),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class OpsThemeModeSelector extends StatelessWidget {
  const OpsThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeModeController>();
    return OpsSectionCard(
      title: 'Theme mode',
      subtitle: 'Choose a system-driven, light, or dark ops shell.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<AppThemePreference>(
            segments: const [
              ButtonSegment<AppThemePreference>(
                value: AppThemePreference.system,
                icon: Icon(Icons.settings_suggest_rounded),
                label: Text('System'),
              ),
              ButtonSegment<AppThemePreference>(
                value: AppThemePreference.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Light'),
              ),
              ButtonSegment<AppThemePreference>(
                value: AppThemePreference.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Dark'),
              ),
            ],
            selected: {controller.preference},
            multiSelectionEnabled: false,
            onSelectionChanged: (selection) {
              controller.setPreference(selection.first);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Current mode: ${controller.preference.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OpsPalette.textSecondary(context),
                ),
          ),
        ],
      ),
    );
  }
}

class OpsOperationalStrip extends StatelessWidget {
  final List<OpsOperationalItem> items;

  const OpsOperationalStrip({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OpsPalette.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          if (isWide) {
            return Row(
              children: [
                for (int index = 0; index < items.length; index++) ...[
                  Expanded(child: _OperationalCell(item: items[index])),
                  if (index != items.length - 1)
                    Container(
                      width: 1,
                      height: 54,
                      color: OpsPalette.border(context),
                    ),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final item in items)
                SizedBox(
                  width: math.max((constraints.maxWidth - 14) / 2, 140),
                  child: _OperationalCell(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class OpsOperationalItem {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color tone;

  const OpsOperationalItem({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.tone,
  });
}

class _OperationalCell extends StatelessWidget {
  final OpsOperationalItem item;

  const _OperationalCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: item.tone.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: item.tone),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OpsPalette.textSecondary(context),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: item.tone,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                item.helper,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OpsPalette.textSecondary(context),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OpsRoutePreview extends StatelessWidget {
  final String title;
  final String badge;
  final double risk;
  final bool caution;

  const OpsRoutePreview({
    super.key,
    required this.title,
    required this.badge,
    required this.risk,
    required this.caution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePreviewPainter(
                risk: risk,
                caution: caution,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    caution ? 'Caution zone active' : 'Route clear',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color tone;
  final Color backgroundTone;

  _SparklinePainter({
    required this.points,
    required this.tone,
    required this.backgroundTone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = backgroundTone.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (int index = 1; index <= 3; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    if (points.isEmpty) return;
    final minValue = points.reduce(math.min);
    final maxValue = points.reduce(math.max);
    final spread =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : (maxValue - minValue);

    final path = Path();
    for (int index = 0; index < points.length; index++) {
      final x = size.width * index / math.max(points.length - 1, 1);
      final normalized = (points[index] - minValue) / spread;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            tone.withValues(alpha: 0.28),
            tone.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = tone
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.tone != tone;
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final double risk;
  final bool caution;

  _RoutePreviewPainter({
    required this.risk,
    required this.caution,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.85)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.62,
        size.width * 0.42,
        size.height * 0.74,
        size.width * 0.51,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.24,
        size.width * 0.75,
        size.height * 0.32,
        size.width * 0.82,
        size.height * 0.12,
      );

    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF1A91F0)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final hazardCenter = Offset(size.width * 0.52, size.height * 0.38);
    final hazardTone = caution ? AppColors.error : AppColors.warning;
    canvas.drawCircle(
      hazardCenter,
      48,
      Paint()..color = hazardTone.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      hazardCenter,
      18,
      Paint()..color = hazardTone.withValues(alpha: 0.35),
    );

    final lowCenter = Offset(size.width * 0.76, size.height * 0.72);
    canvas.drawCircle(
      lowCenter,
      38,
      Paint()..color = AppColors.warning.withValues(alpha: 0.12),
    );

    final ambulanceCenter = Offset(size.width * 0.42, size.height * 0.58);
    canvas.drawCircle(
      ambulanceCenter,
      10,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      ambulanceCenter,
      7,
      Paint()..color = const Color(0xFFE8384F),
    );

    final badgeWidth = 94.0;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - badgeWidth - 12, 12, badgeWidth, 34),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(risk * 100).round()}%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(size.width - badgeWidth + 16, 20),
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.risk != risk || oldDelegate.caution != caution;
  }
}
