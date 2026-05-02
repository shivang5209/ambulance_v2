import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

// Core
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';

// Providers
import 'providers/auth_provider.dart';

// Services
import 'services/firebase_auth_service.dart';
import 'services/secure_storage_service.dart';
import 'services/esp32_service.dart';
import 'services/iot_data_orchestrator_mobile.dart'
    if (dart.library.html) 'services/iot_data_orchestrator_web.dart';
import 'services/ml_accident_detector.dart';
import 'services/model_update_service.dart';
import 'services/hotspot_service.dart';
import 'services/location_enrichment_service.dart';

// Screens
import 'screens/splash_screen_new.dart';

/// Shared ESP32Service instance used by both the UI and the orchestrator.
final esp32Service = ESP32Service();

/// Global ML detector — loaded once at startup, hot-swappable via OTA.
final mlDetector = MLAccidentDetector();

/// IoT Data Orchestrator — routes sensor data to Firebase RTD + Supabase.
/// On web, uses a stub implementation that does nothing.
late final IoTDataOrchestrator iotOrchestrator;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Initialize Firebase ─────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── 2. OTA model update check ──────────────────────────────────────
  // Run before loading the bundled model so we can hot-swap immediately.
  final modelUpdateService = ModelUpdateService();
  final newModelPath = await modelUpdateService.checkAndUpdate();

  // ── 3. Load TFLite model ───────────────────────────────────────────
  try {
    if (newModelPath != null) {
      await mlDetector.reloadFromPath(newModelPath);
    } else {
      await mlDetector.loadModel();
    }
  } catch (_) {
    // Model load failed — orchestrator will use rule-based fallback
  }

  // ── 4. Initialize Supabase (cold-path analytics) ───────────────────
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // ── 5. Create and start the IoT data orchestrator ──────────────────
  iotOrchestrator = IoTDataOrchestrator(
    esp32Service: esp32Service,
    mlDetector: mlDetector,
  );
  iotOrchestrator.initialize();
  iotOrchestrator.start();

  // ── 6. Set preferred orientations ─────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── 7. System UI overlay style ────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const AmbulanceV2App());
}

class AmbulanceV2App extends StatelessWidget {
  const AmbulanceV2App({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = SecureStorageService();
    final authService = FirebaseAuthService();
    final hotspotService = HotspotService();
    final enrichmentService = LocationEnrichmentService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, storageService),
        ),
        Provider<ESP32Service>.value(value: esp32Service),
        Provider<IoTDataOrchestrator>.value(value: iotOrchestrator),
        Provider<MLAccidentDetector>.value(value: mlDetector),
        Provider<HotspotService>.value(value: hotspotService),
        Provider<LocationEnrichmentService>.value(value: enrichmentService),
      ],
      child: MaterialApp(
        title: 'RapidAid v2',
        debugShowCheckedModeBanner: false,

        // Theme Configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,

        // Home Screen - Splash with Auth Check
        home: const SplashScreenNew(),
      ),
    );
  }
}
