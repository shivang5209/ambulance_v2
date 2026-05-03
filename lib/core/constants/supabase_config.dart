/// Supabase configuration constants for cold-path data storage.
///
/// Supply credentials with:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static const String sensorReadingsTable = 'sensor_readings';
  static const String tripSummariesTable = 'trip_summaries';
  static const String crashEventsTable = 'crash_events';

  /// Flush the cold-path queue when it reaches this many records.
  static const int batchSizeThreshold = 50;

  /// Flush the cold-path queue after this duration regardless of count.
  static const Duration batchTimeThreshold = Duration(seconds: 30);
}
