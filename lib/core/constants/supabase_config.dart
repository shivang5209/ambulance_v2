/// Supabase configuration constants for cold-path data storage.
///
/// Before running, replace the placeholder URL and anon key with your
/// Supabase project credentials from https://supabase.com/dashboard.
class SupabaseConfig {
  SupabaseConfig._();

  // ── Project credentials (replace with your own) ──────────────────────
  static const String url = 'https://fybqbafaoddkoeroxbnn.supabase.co';
  static const String anonKey = 'sb_publishable_v7NldEX4mZsFsCF-ezyNYg_ZUB031a4';

  // ── Table names ──────────────────────────────────────────────────────
  static const String sensorReadingsTable = 'sensor_readings';
  static const String tripSummariesTable = 'trip_summaries';
  static const String crashEventsTable = 'crash_events';

  // ── Batching thresholds ──────────────────────────────────────────────
  /// Flush the cold-path queue when it reaches this many records.
  static const int batchSizeThreshold = 50;

  /// Flush the cold-path queue after this duration regardless of count.
  static const Duration batchTimeThreshold = Duration(seconds: 30);
}
