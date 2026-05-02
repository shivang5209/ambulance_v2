import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hotspot_zone.dart';
import '../models/vehicle_parameters.dart';

/// Manages accident hotspot zones:
///   • Loads pre-computed zones from Firestore `/hotspots`
///   • Provides fast proximity checking for the driver warning banner
///   • Exposes a client-side DBSCAN helper for demo/testing purposes
///     (production clustering runs in the Cloud Function)
class HotspotService {
  static const _collection = 'hotspots';
  static const double _warningBufferMeters = 500.0;

  final FirebaseFirestore _db;

  List<HotspotZone> _cachedZones = [];
  DateTime? _lastFetch;

  HotspotService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  List<HotspotZone> get cachedZones => List.unmodifiable(_cachedZones);

  // ── Load hotspots ────────────────────────────────────────────────────

  /// Fetch active hotspot zones from Firestore and cache locally.
  /// Re-fetches only if cache is older than [maxAgeMinutes].
  Future<List<HotspotZone>> loadHotspots({int maxAgeMinutes = 15}) async {
    final now = DateTime.now();
    if (_lastFetch != null &&
        now.difference(_lastFetch!).inMinutes < maxAgeMinutes &&
        _cachedZones.isNotEmpty) {
      return _cachedZones;
    }

    try {
      final snap = await _db
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      _cachedZones = snap.docs.map(HotspotZone.fromFirestore).toList();
      _lastFetch = now;
    } catch (_) {
      // Return stale cache on network failure
    }
    return _cachedZones;
  }

  // ── Proximity check ──────────────────────────────────────────────────

  /// Returns the nearest active hotspot zone within its warning radius,
  /// or `null` if the driver is not near any known hotspot.
  HotspotZone? checkProximity(GpsLocation current) {
    HotspotZone? nearest;
    double nearestDistance = double.infinity;

    for (final zone in _cachedZones) {
      if (!zone.isActive) continue;
      final dist = _haversineMeters(
        current.latitude,
        current.longitude,
        zone.centerLat,
        zone.centerLng,
      );
      final threshold = zone.radiusMeters + _warningBufferMeters;
      if (dist <= threshold && dist < nearestDistance) {
        nearest = zone;
        nearestDistance = dist;
      }
    }
    return nearest;
  }

  // ── Client-side DBSCAN (demo / unit-test use) ────────────────────────

  /// Clusters [points] using DBSCAN.
  ///
  /// [eps] in degrees ≈ 300 m at the equator.
  /// [minPts] minimum points to form a cluster core.
  List<HotspotZone> dbscanCluster(
    List<GpsLocation> points, {
    double eps = 0.003,
    int minPts = 3,
  }) {
    final n = points.length;
    final labels = List<int>.filled(n, -1); // -1 = unvisited
    int clusterId = 0;

    for (int i = 0; i < n; i++) {
      if (labels[i] != -1) continue;
      final neighbours = _regionQuery(points, i, eps);
      if (neighbours.length < minPts) {
        labels[i] = 0; // noise
        continue;
      }
      clusterId++;
      labels[i] = clusterId;
      final seed = List<int>.from(neighbours)..remove(i);
      while (seed.isNotEmpty) {
        final j = seed.removeLast();
        if (labels[j] == 0) labels[j] = clusterId;
        if (labels[j] != -1) continue;
        labels[j] = clusterId;
        final jNeighbours = _regionQuery(points, j, eps);
        if (jNeighbours.length >= minPts) seed.addAll(jNeighbours);
      }
    }

    // Build HotspotZone for each cluster
    final zones = <HotspotZone>[];
    for (int c = 1; c <= clusterId; c++) {
      final clusterPoints = <GpsLocation>[];
      for (int i = 0; i < n; i++) {
        if (labels[i] == c) clusterPoints.add(points[i]);
      }
      if (clusterPoints.isEmpty) continue;

      final avgLat =
          clusterPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
              clusterPoints.length;
      final avgLng =
          clusterPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
              clusterPoints.length;

      zones.add(HotspotZone(
        zoneId: 'local_cluster_$c',
        centerLat: avgLat,
        centerLng: avgLng,
        radiusMeters: eps * 111320, // degrees → metres approximation
        incidentCount: clusterPoints.length,
        avgSeverity: 2.0,
        peakHours: [],
        peakDays: [],
        weatherFactor: 'unknown',
        trend: 'stable',
        geminiAnalysis: '',
        ambulanceRecommendation: {},
        isActive: true,
        lastUpdated: DateTime.now(),
      ));
    }
    return zones;
  }

  // ── Private helpers ──────────────────────────────────────────────────

  List<int> _regionQuery(List<GpsLocation> points, int idx, double eps) {
    final result = <int>[];
    for (int i = 0; i < points.length; i++) {
      final dist = _euclideanDeg(points[idx], points[i]);
      if (dist <= eps) result.add(i);
    }
    return result;
  }

  /// Fast degree-space distance (no trig) — good enough for eps ≪ 1°.
  double _euclideanDeg(GpsLocation a, GpsLocation b) {
    final dlat = a.latitude - b.latitude;
    final dlng = a.longitude - b.longitude;
    return sqrt(dlat * dlat + dlng * dlng);
  }

  /// Haversine distance between two GPS points in metres.
  double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lng2 - lng1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
