class SensorReadingSnapshot {
  final String deviceId;
  final DateTime timestamp;
  final double speed;
  final double impactForce;
  final double totalAcceleration;
  final double? latitude;
  final double? longitude;
  final double? batteryVoltage;

  const SensorReadingSnapshot({
    required this.deviceId,
    required this.timestamp,
    required this.speed,
    required this.impactForce,
    required this.totalAcceleration,
    this.latitude,
    this.longitude,
    this.batteryVoltage,
  });
}

class DeviceAnalyticsSummary {
  final String deviceId;
  final int readingCount;
  final double averageSpeed;
  final double maxImpactForce;
  final DateTime? lastSeen;

  const DeviceAnalyticsSummary({
    required this.deviceId,
    required this.readingCount,
    required this.averageSpeed,
    required this.maxImpactForce,
    required this.lastSeen,
  });
}

class SensorAnalyticsSummary {
  final int readingSampleCount;
  final int activeDeviceCount;
  final double averageSpeed;
  final double peakSpeed;
  final double averageImpactForce;
  final double peakImpactForce;
  final double averageAcceleration;
  final int crashEventCount;
  final int tripSummaryCount;
  final double totalTripDistanceKm;
  final DateTime? latestReadingAt;
  final List<SensorReadingSnapshot> recentReadings;
  final List<DeviceAnalyticsSummary> deviceBreakdown;
  final List<double> speedSeries;
  final List<double> impactSeries;
  final List<double> accelerationSeries;

  const SensorAnalyticsSummary({
    required this.readingSampleCount,
    required this.activeDeviceCount,
    required this.averageSpeed,
    required this.peakSpeed,
    required this.averageImpactForce,
    required this.peakImpactForce,
    required this.averageAcceleration,
    required this.crashEventCount,
    required this.tripSummaryCount,
    required this.totalTripDistanceKm,
    required this.latestReadingAt,
    required this.recentReadings,
    required this.deviceBreakdown,
    required this.speedSeries,
    required this.impactSeries,
    required this.accelerationSeries,
  });

  factory SensorAnalyticsSummary.empty() => const SensorAnalyticsSummary(
        readingSampleCount: 0,
        activeDeviceCount: 0,
        averageSpeed: 0,
        peakSpeed: 0,
        averageImpactForce: 0,
        peakImpactForce: 0,
        averageAcceleration: 0,
        crashEventCount: 0,
        tripSummaryCount: 0,
        totalTripDistanceKm: 0,
        latestReadingAt: null,
        recentReadings: <SensorReadingSnapshot>[],
        deviceBreakdown: <DeviceAnalyticsSummary>[],
        speedSeries: <double>[],
        impactSeries: <double>[],
        accelerationSeries: <double>[],
      );
}
