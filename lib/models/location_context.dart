/// Location metadata appended to sensor features before ML inference.
///
/// All values are encoded as integers or normalized doubles so they slot
/// directly into the 38-float TFLite feature vector
/// (30 sensor floats + 8 location floats).
class LocationContext {
  /// Whether the current GPS point falls inside a known hotspot zone.
  final bool isKnownHotspot;

  /// Average severity of the nearest hotspot. 0.0 if not in a hotspot.
  /// Range: 0.0 – 1.0.
  final double hotspotSeverityAvg;

  /// Encoded road type:
  /// 0 = junction, 1 = highway, 2 = residential, 3 = school_zone, 4 = other.
  final int roadTypeEncoded;

  /// Posted speed limit in km/h. Defaults to 50 when unknown.
  final double speedLimit;

  /// Encoded time-of-day bucket:
  /// 0 = morning_rush (6–9), 1 = afternoon (9–16),
  /// 2 = evening_rush (16–20), 3 = night (20–6).
  final int timeOfDayEncoded;

  /// Day of week: 0 = Monday … 6 = Sunday.
  final int dayOfWeekEncoded;

  /// Encoded weather condition:
  /// 0 = clear, 1 = rain, 2 = fog, 3 = storm.
  final int weatherEncoded;

  /// Coarse grid-cell ID derived from lat/lng (avoids leaking raw GPS into
  /// the model). Computed as:
  ///   `(lat * 100).floor() * 1000 + (lng * 100).floor()`
  final int gridCell;

  const LocationContext({
    required this.isKnownHotspot,
    required this.hotspotSeverityAvg,
    required this.roadTypeEncoded,
    required this.speedLimit,
    required this.timeOfDayEncoded,
    required this.dayOfWeekEncoded,
    required this.weatherEncoded,
    required this.gridCell,
  });

  /// Default context used as fallback when enrichment is unavailable.
  factory LocationContext.unknown() => const LocationContext(
        isKnownHotspot: false,
        hotspotSeverityAvg: 0.0,
        roadTypeEncoded: 4, // other
        speedLimit: 50.0,
        timeOfDayEncoded: 1, // afternoon
        dayOfWeekEncoded: 0, // Monday
        weatherEncoded: 0, // clear
        gridCell: 0,
      );

  /// Flatten to 8 doubles for concatenation with the 30-float sensor vector.
  List<double> toFeatureSlice() => [
        isKnownHotspot ? 1.0 : 0.0,
        hotspotSeverityAvg,
        roadTypeEncoded.toDouble(),
        speedLimit / 120.0, // normalise to [0,1] assuming max 120 km/h
        timeOfDayEncoded.toDouble(),
        dayOfWeekEncoded.toDouble(),
        weatherEncoded.toDouble(),
        (gridCell % 10000).toDouble() / 10000.0, // coarse normalised cell
      ];

  // ── Serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'isKnownHotspot': isKnownHotspot,
        'hotspotSeverityAvg': hotspotSeverityAvg,
        'roadTypeEncoded': roadTypeEncoded,
        'speedLimit': speedLimit,
        'timeOfDayEncoded': timeOfDayEncoded,
        'dayOfWeekEncoded': dayOfWeekEncoded,
        'weatherEncoded': weatherEncoded,
        'gridCell': gridCell,
      };

  factory LocationContext.fromJson(Map<String, dynamic> json) =>
      LocationContext(
        isKnownHotspot: json['isKnownHotspot'] as bool,
        hotspotSeverityAvg: (json['hotspotSeverityAvg'] as num).toDouble(),
        roadTypeEncoded: json['roadTypeEncoded'] as int,
        speedLimit: (json['speedLimit'] as num).toDouble(),
        timeOfDayEncoded: json['timeOfDayEncoded'] as int,
        dayOfWeekEncoded: json['dayOfWeekEncoded'] as int,
        weatherEncoded: json['weatherEncoded'] as int,
        gridCell: json['gridCell'] as int,
      );

  @override
  String toString() =>
      'LocationContext(hotspot=$isKnownHotspot, road=$roadTypeEncoded, '
      'time=$timeOfDayEncoded, weather=$weatherEncoded)';
}
