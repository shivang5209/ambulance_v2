import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/hotspot_zone.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';

/// Enriches a GPS location with road type, weather, time-of-day, and
/// hotspot context to build the [LocationContext] for ML feature augmentation.
///
/// Weather data is sourced from the Open-Meteo API (free, no key required).
/// Road type falls back to a hotspot-based heuristic when OSM is unavailable.
class LocationEnrichmentService {
  // Open-Meteo free weather endpoint
  static const _weatherApiBase =
      'https://api.open-meteo.com/v1/forecast?hourly=weathercode&forecast_days=1&';

  // Simple in-memory weather cache keyed by "lat_lng" rounded to 2dp
  final Map<String, int> _weatherCache = {};
  final List<HotspotZone> _hotspots;

  LocationEnrichmentService({List<HotspotZone> hotspots = const []})
      : _hotspots = hotspots;

  /// Update the hotspot list (called after [HotspotService.loadHotspots]).
  void updateHotspots(List<HotspotZone> zones) {
    _hotspots
      ..clear()
      ..addAll(zones);
  }

  // ── Public API ───────────────────────────────────────────────────────

  /// Build a [LocationContext] for [loc].
  ///
  /// Network calls are best-effort; failures fall back to sensible defaults.
  Future<LocationContext> enrich(GpsLocation loc) async {
    final now = DateTime.now();

    // Check if inside a known hotspot
    HotspotZone? nearestHotspot;
    double hotspotSeverity = 0.0;
    for (final zone in _hotspots) {
      if (!zone.isActive) continue;
      nearestHotspot = zone;
      hotspotSeverity = (zone.avgSeverity - 1.0) / 3.0; // scale 1-4 → 0-1
      break; // take first match for simplicity; HotspotService already filtered
    }

    final weather = await _getWeather(loc.latitude, loc.longitude);
    final roadType = _getRoadType(loc.latitude, loc.longitude);
    final speedLimit = _getSpeedLimit(roadType);

    return LocationContext(
      isKnownHotspot: nearestHotspot != null,
      hotspotSeverityAvg: hotspotSeverity.clamp(0.0, 1.0),
      roadTypeEncoded: roadType,
      speedLimit: speedLimit,
      timeOfDayEncoded: _classifyTimeOfDay(now),
      dayOfWeekEncoded: now.weekday - 1, // 0=Monday, 6=Sunday
      weatherEncoded: weather,
      gridCell: _gridCell(loc.latitude, loc.longitude),
    );
  }

  // ── Time of day ──────────────────────────────────────────────────────

  /// 0=morning_rush(6–9), 1=afternoon(9–16), 2=evening_rush(16–20), 3=night.
  int _classifyTimeOfDay(DateTime dt) {
    final h = dt.hour;
    if (h >= 6 && h < 9) return 0;
    if (h >= 9 && h < 16) return 1;
    if (h >= 16 && h < 20) return 2;
    return 3;
  }

  // ── Weather ──────────────────────────────────────────────────────────

  /// Returns encoded weather: 0=clear, 1=rain, 2=fog, 3=storm.
  Future<int> _getWeather(double lat, double lng) async {
    final key =
        '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';
    if (_weatherCache.containsKey(key)) return _weatherCache[key]!;

    try {
      final url = Uri.parse(
          '$_weatherApiBase'
          'latitude=${lat.toStringAsFixed(4)}&longitude=${lng.toStringAsFixed(4)}');
      final resp = await http.get(url).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final codes =
            (data['hourly']['weathercode'] as List).cast<int>();
        final currentCode =
            codes.isNotEmpty ? codes[DateTime.now().hour] : 0;
        final encoded = _encodeWeatherCode(currentCode);
        _weatherCache[key] = encoded;
        return encoded;
      }
    } catch (_) {
      // Fall back to clear
    }
    return 0; // clear
  }

  int _encodeWeatherCode(int code) {
    // WMO Weather Code → encoded bucket
    if (code == 0 || code <= 3) return 0; // clear/partly cloudy
    if (code >= 45 && code <= 48) return 2; // fog
    if (code >= 61 && code <= 82) return 1; // rain/drizzle
    if (code >= 95) return 3; // storm/thunderstorm
    return 0;
  }

  // ── Road type ────────────────────────────────────────────────────────

  /// Heuristic road type from hotspot proximity.
  /// 0=junction, 1=highway, 2=residential, 3=school_zone, 4=other.
  int _getRoadType(double lat, double lng) {
    for (final zone in _hotspots) {
      final dlat = (zone.centerLat - lat).abs();
      final dlng = (zone.centerLng - lng).abs();
      if (dlat < 0.005 && dlng < 0.005) {
        // Near a hotspot — guess junction
        return 0;
      }
    }
    return 4; // other
  }

  // ── Speed limit ──────────────────────────────────────────────────────

  double _getSpeedLimit(int roadType) {
    switch (roadType) {
      case 0: return 30.0; // junction
      case 1: return 100.0; // highway
      case 2: return 40.0; // residential
      case 3: return 25.0; // school zone
      default: return 50.0;
    }
  }

  // ── Grid cell ────────────────────────────────────────────────────────

  int _gridCell(double lat, double lng) {
    // Coarse 0.01° grid (~1 km resolution)
    final latCell = (lat * 100).floor();
    final lngCell = (lng * 100).floor();
    return latCell * 10000 + lngCell;
  }
}
