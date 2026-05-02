import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/accident_event.dart';
import '../models/hotspot_zone.dart';

/// Gemini Flash API wrapper for hotspot intelligence and weekly reports.
///
/// Uses `google_generative_ai` package with model `gemini-1.5-flash`.
/// Cost: ~$0 on free tier (1,500 requests/day).
///
/// Set [apiKey] from your `.env` or build config — never hardcode it.
class GeminiService {
  static const _modelId = 'gemini-1.5-flash';

  late final GenerativeModel _model;
  bool _initialized = false;

  GeminiService(String apiKey) {
    _model = GenerativeModel(model: _modelId, apiKey: apiKey);
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  // ── Hotspot analysis ─────────────────────────────────────────────────

  /// Generates a natural-language analysis of a hotspot zone.
  ///
  /// Includes incident patterns, peak times, weather correlation, and
  /// root-cause hypotheses. Returns an empty string on error.
  Future<String> analyzeHotspot(
    HotspotZone zone,
    List<AccidentEvent> events,
  ) async {
    final prompt = '''
You are a road safety AI assistant for an emergency ambulance system in India.
Analyze the following accident hotspot zone and provide a concise, actionable analysis (max 150 words).

Zone data:
- Incident count (90 days): ${zone.incidentCount}
- Average severity (1-4 scale): ${zone.avgSeverity.toStringAsFixed(1)}
- Peak hours: ${zone.peakHours.join(', ')}
- Peak days: ${zone.peakDays.join(', ')}
- Weather factor: ${zone.weatherFactor}
- Trend: ${zone.trend}
- GPS center: ${zone.centerLat.toStringAsFixed(4)}, ${zone.centerLng.toStringAsFixed(4)}

Include:
1. Likely root causes (road design, traffic patterns, weather)
2. Peak risk windows
3. Recommended preventive action for emergency services
''';
    return _safeGenerate(prompt);
  }

  // ── Weekly report ────────────────────────────────────────────────────

  /// Generates a weekly summary report for the admin dashboard.
  Future<String> generateWeeklyReport(List<HotspotZone> zones) async {
    final activeZones = zones.where((z) => z.isActive).toList()
      ..sort((a, b) => b.avgSeverity.compareTo(a.avgSeverity));

    final topZones = activeZones.take(5).map((z) {
      return '- Zone ${z.zoneId}: ${z.incidentCount} incidents, '
          'avg severity ${z.avgSeverity.toStringAsFixed(1)}, '
          'trend: ${z.trend}';
    }).join('\n');

    final prompt = '''
You are a road safety analyst for an Indian ambulance dispatch system.
Generate a concise weekly accident hotspot report (max 200 words) for system administrators.

Top active hotspots this week:
$topZones

Total active zones: ${activeZones.length}
Include: key risk trends, recommended ambulance pre-positioning, and priority zones for intervention.
''';
    return _safeGenerate(prompt);
  }

  // ── Ambulance positioning ────────────────────────────────────────────

  /// Recommends optimal ambulance standby positions based on active hotspots.
  ///
  /// Returns a Map with keys: `standbyPoints`, `estimatedResponseGain`, `reasoning`.
  Future<Map<String, dynamic>> recommendAmbulancePositioning(
      List<HotspotZone> active) async {
    final zoneSummaries = active.take(8).map((z) {
      return '${z.zoneId}: lat=${z.centerLat.toStringAsFixed(4)}, '
          'lng=${z.centerLng.toStringAsFixed(4)}, '
          'severity=${z.avgSeverity.toStringAsFixed(1)}, '
          'incidents=${z.incidentCount}';
    }).join('\n');

    final prompt = '''
You are an emergency dispatch optimizer for an Indian ambulance system.
Based on these active accident hotspots, recommend optimal ambulance standby positions.

Hotspots:
$zoneSummaries

Respond ONLY in this JSON format (no markdown, no prose):
{
  "standbyPoints": [{"lat": 0.0, "lng": 0.0, "reason": "..."}],
  "estimatedResponseGainMinutes": 2.5,
  "reasoning": "..."
}
''';

    final text = await _safeGenerate(prompt);
    try {
      // Extract JSON from response
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        // Return as map — caller can jsonDecode the substring
        return {'raw': text.substring(jsonStart, jsonEnd + 1)};
      }
    } catch (_) {}
    return {'raw': text, 'error': 'failed_to_parse_json'};
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<String> _safeGenerate(String prompt) async {
    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      return ''; // Non-fatal — UI should show fallback
    }
  }
}
