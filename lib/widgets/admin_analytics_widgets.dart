import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sensor_analytics.dart';
import '../theme/app_colors.dart';
import 'ops_ui.dart';

class AnalyticsLineChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<double> values;
  final Color tone;
  final String unit;

  const AnalyticsLineChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.tone,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return OpsSectionCard(
      title: title,
      subtitle: subtitle,
      child: values.isEmpty
          ? const _AnalyticsEmptyState(message: 'No recorded points yet.')
          : SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: _gridInterval(values),
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: OpsPalette.border(context).withValues(alpha: 0.45),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: _gridInterval(values),
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toStringAsFixed(0),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: OpsPalette.textSecondary(context)),
                          ),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _bottomInterval(values.length),
                        getTitlesWidget: (value, meta) => Text(
                          '#${value.toInt() + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: OpsPalette.textSecondary(context)),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).cardColor,
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              '${spot.y.toStringAsFixed(2)} $unit',
                              TextStyle(
                                color: tone,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int index = 0; index < values.length; index++)
                          FlSpot(index.toDouble(), values[index]),
                      ],
                      isCurved: true,
                      color: tone,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            tone.withValues(alpha: 0.24),
                            tone.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(show: values.length <= 24),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  double _gridInterval(List<double> values) {
    final peak = values.reduce((a, b) => a > b ? a : b);
    if (peak <= 4) return 1;
    if (peak <= 20) return 5;
    if (peak <= 80) return 10;
    return 20;
  }

  double _bottomInterval(int length) {
    if (length <= 8) return 1;
    if (length <= 16) return 2;
    if (length <= 32) return 4;
    return 6;
  }
}

class DeviceBreakdownChartCard extends StatelessWidget {
  final List<DeviceAnalyticsSummary> devices;

  const DeviceBreakdownChartCard({
    super.key,
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    return OpsSectionCard(
      title: 'Device breakdown',
      subtitle: 'Reading volume and average speed by active device.',
      child: devices.isEmpty
          ? const _AnalyticsEmptyState(message: 'No device readings available.')
          : SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: devices
                          .map((device) => device.readingCount)
                          .reduce((a, b) => a > b ? a : b)
                          .toDouble() +
                      2,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: OpsPalette.border(context).withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: OpsPalette.textSecondary(context)),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= devices.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              devices[index].deviceId,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: OpsPalette.textSecondary(context),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).cardColor,
                      getTooltipItem: (group, _, rod, __) {
                        final device = devices[group.x.toInt()];
                        return BarTooltipItem(
                          '${device.deviceId}\n${device.readingCount} readings\n${device.averageSpeed.toStringAsFixed(1)} km/h avg',
                          const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (int index = 0; index < devices.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: devices[index].readingCount.toDouble(),
                            width: 22,
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class RecentReadingsCard extends StatelessWidget {
  final List<SensorReadingSnapshot> readings;

  const RecentReadingsCard({
    super.key,
    required this.readings,
  });

  @override
  Widget build(BuildContext context) {
    return OpsSectionCard(
      title: 'Recent readings',
      subtitle: 'Latest telemetry records stored in Supabase.',
      child: readings.isEmpty
          ? const _AnalyticsEmptyState(message: 'No recent readings available.')
          : Column(
              children: [
                for (int index = 0; index < readings.length; index++) ...[
                  _ReadingRow(reading: readings[index]),
                  if (index != readings.length - 1)
                    Divider(
                      height: 18,
                      color: OpsPalette.border(context),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  final SensorReadingSnapshot reading;

  const _ReadingRow({
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            reading.deviceId,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${reading.speed.toStringAsFixed(1)} km/h',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${reading.impactForce.toStringAsFixed(2)} g',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${reading.totalAcceleration.toStringAsFixed(2)} G',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            _formatTimestamp(reading.timestamp),
            textAlign: TextAlign.right,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OpsPalette.textSecondary(context)),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '${value.day}/${value.month} $hour:$minute:$second';
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  final String message;

  const _AnalyticsEmptyState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: OpsPalette.elevatedSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OpsPalette.border(context)),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights_rounded,
              size: 36, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OpsPalette.textSecondary(context),
                ),
          ),
        ],
      ),
    );
  }
}
