// Stub file for web platform - IoT orchestrator is not available on web
// This prevents firebase_database package from being loaded on web builds

import 'hotspot_service.dart';
import 'location_enrichment_service.dart';

class IoTDataOrchestrator {
  // Stub constructor that does nothing
  IoTDataOrchestrator({
    required dynamic esp32Service,
    dynamic mlDetector,
    HotspotService? hotspotService,
    LocationEnrichmentService? enrichmentService,
  })  : _hotspotService = hotspotService ?? HotspotService(),
        _enrichmentService = enrichmentService ?? LocationEnrichmentService();

  final HotspotService _hotspotService;
  final LocationEnrichmentService _enrichmentService;
  HotspotService get hotspotService => _hotspotService;
  LocationEnrichmentService get enrichmentService => _enrichmentService;
  
  void initialize() {
    // No-op on web
  }
  
  void start() {
    // No-op on web
  }
  
  void dispose() {
    // No-op on web
  }
}

class OrchestratorStatus {
  final int hotPathWriteCount;
  final int coldPathPendingCount;
  final int coldPathFlushCount;
  final int crashEventCount;
  final String? lastError;
  final DateTime updatedAt;

  const OrchestratorStatus({
    required this.hotPathWriteCount,
    required this.coldPathPendingCount,
    required this.coldPathFlushCount,
    required this.crashEventCount,
    this.lastError,
    required this.updatedAt,
  });
}
