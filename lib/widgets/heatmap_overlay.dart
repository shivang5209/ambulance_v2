import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/accident_event.dart';
import '../models/hotspot_zone.dart';

/// Google Maps heatmap overlay for the admin dashboard.
///
/// Renders:
///   • Weighted heatmap circles from accident event GPS points
///     (weight = severity × recency decay)
///   • Hotspot zone circles (color-coded by avg severity)
///   • Tap-to-expand hotspot detail panel
///
/// Filters:
///   • Time range: 7 / 30 / 90 days
///   • Mode: all events / confirmed only / hotspots only
class HeatmapOverlay extends StatefulWidget {
  final List<AccidentEvent> events;
  final List<HotspotZone> hotspots;
  final void Function(HotspotZone zone)? onHotspotTap;

  const HeatmapOverlay({
    super.key,
    required this.events,
    required this.hotspots,
    this.onHotspotTap,
  });

  @override
  State<HeatmapOverlay> createState() => _HeatmapOverlayState();
}

class _HeatmapOverlayState extends State<HeatmapOverlay> {
  int _dayFilter = 30; // 7, 30, 90
  String _mode = 'all'; // 'all', 'confirmed', 'hotspots'
  GoogleMapController? _mapController;

  Set<Circle> _buildCircles() {
    final circles = <Circle>{};
    final cutoff =
        DateTime.now().subtract(Duration(days: _dayFilter));

    // ── Event heatmap circles ──────────────────────────────────────
    if (_mode != 'hotspots') {
      final filtered = widget.events.where((e) {
        if (e.detectionTime.isBefore(cutoff)) return false;
        if (_mode == 'confirmed' && e.analysis.isFalsePositive) return false;
        return true;
      });

      for (final event in filtered) {
        final age = DateTime.now().difference(event.detectionTime).inDays;
        final recencyWeight = 1.0 - (age / _dayFilter).clamp(0.0, 0.9);
        final severityWeight =
            event.severity.level / 4.0; // 0.25–1.0
        final weight = (recencyWeight * severityWeight).clamp(0.0, 1.0);

        circles.add(Circle(
          circleId: CircleId('evt_${event.eventId}'),
          center: LatLng(event.location.latitude, event.location.longitude),
          radius: 80 + weight * 120, // 80–200 m radius
          fillColor: _heatColor(weight).withOpacity(0.25),
          strokeColor: _heatColor(weight).withOpacity(0.6),
          strokeWidth: 1,
        ));
      }
    }

    // ── Hotspot zone circles ───────────────────────────────────────
    for (final zone in widget.hotspots) {
      if (!zone.isActive) continue;
      circles.add(Circle(
        circleId: CircleId('zone_${zone.zoneId}'),
        center: LatLng(zone.centerLat, zone.centerLng),
        radius: zone.radiusMeters,
        fillColor: _severityColor(zone.severityLevel).withOpacity(0.15),
        strokeColor: _severityColor(zone.severityLevel),
        strokeWidth: 2,
      ));
    }
    return circles;
  }

  Set<Marker> _buildMarkers() {
    return {
      for (final zone in widget.hotspots)
        if (zone.isActive)
          Marker(
            markerId: MarkerId('marker_${zone.zoneId}'),
            position: LatLng(zone.centerLat, zone.centerLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _severityHue(zone.severityLevel),
            ),
            infoWindow: InfoWindow(
              title: '${zone.incidentCount} incidents',
              snippet:
                  'Severity ${zone.avgSeverity.toStringAsFixed(1)} • ${zone.trend}',
            ),
            onTap: () => widget.onHotspotTap?.call(zone),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Map ──────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(20.5937, 78.9629), // India center
            zoom: 5,
          ),
          circles: _buildCircles(),
          markers: _buildMarkers(),
          onMapCreated: (c) => _mapController = c,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
        ),

        // ── Filter bar ──────────────────────────────────────────
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _FilterBar(
            dayFilter: _dayFilter,
            mode: _mode,
            onDayChanged: (d) => setState(() => _dayFilter = d),
            onModeChanged: (m) => setState(() => _mode = m),
          ),
        ),
      ],
    );
  }

  Color _heatColor(double weight) {
    // Cool blue → hot red gradient
    final r = (255 * weight).round();
    final b = (255 * (1 - weight)).round();
    return Color.fromARGB(255, r, 60, b);
  }

  Color _severityColor(int level) {
    switch (level) {
      case 4: return const Color(0xFFDC2626);
      case 3: return const Color(0xFFF97316);
      case 2: return const Color(0xFFF59E0B);
      default: return const Color(0xFF22C55E);
    }
  }

  double _severityHue(int level) {
    switch (level) {
      case 4: return BitmapDescriptor.hueRed;
      case 3: return BitmapDescriptor.hueOrange;
      case 2: return BitmapDescriptor.hueYellow;
      default: return BitmapDescriptor.hueGreen;
    }
  }
}

// ── Filter bar widget ─────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final int dayFilter;
  final String mode;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<String> onModeChanged;

  const _FilterBar({
    required this.dayFilter,
    required this.mode,
    required this.onDayChanged,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Day filter chips
          for (final d in [7, 30, 90])
            _Chip(
              label: '${d}d',
              selected: dayFilter == d,
              onTap: () => onDayChanged(d),
            ),
          const Spacer(),
          // Mode filter chips
          for (final entry in {
            'all': 'All',
            'confirmed': '✓ Confirmed',
            'hotspots': '🔥 Zones',
          }.entries)
            _Chip(
              label: entry.value,
              selected: mode == entry.key,
              onTap: () => onModeChanged(entry.key),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
