import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_mode_controller.dart';
import 'screens/splash_screen_new.dart';
import 'services/esp32_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/hotspot_service.dart';
import 'services/iot_data_orchestrator_mobile.dart'
    if (dart.library.html) 'services/iot_data_orchestrator_web.dart';
import 'services/location_enrichment_service.dart';
import 'services/ml_accident_detector.dart';
import 'services/model_update_service.dart';
import 'services/secure_storage_service.dart';
import 'theme/app_theme.dart';

final esp32Service = ESP32Service();
final mlDetector = MLAccidentDetector();

late final IoTDataOrchestrator iotOrchestrator;
late final HotspotService sharedHotspotService;
late final LocationEnrichmentService sharedEnrichmentService;
late final ThemeModeController themeModeController;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final modelUpdateService = ModelUpdateService();
  final newModelPath = await modelUpdateService.checkAndUpdate();

  try {
    if (newModelPath != null) {
      await mlDetector.reloadFromPath(newModelPath);
    } else {
      await mlDetector.loadModel();
    }
  } catch (_) {
    // Model load failed. The app will fall back to rule-based behavior.
  }

  sharedHotspotService = HotspotService();
  sharedEnrichmentService = LocationEnrichmentService();
  try {
    final zones = await sharedHotspotService.loadHotspots();
    sharedEnrichmentService.updateHotspots(zones);
  } catch (_) {
    // Hotspot context is best-effort at startup.
  }

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  themeModeController = ThemeModeController();
  await themeModeController.load();

  iotOrchestrator = IoTDataOrchestrator(
    esp32Service: esp32Service,
    mlDetector: mlDetector,
    hotspotService: sharedHotspotService,
    enrichmentService: sharedEnrichmentService,
  );
  iotOrchestrator.initialize();
  iotOrchestrator.start();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, storageService),
        ),
        Provider<ESP32Service>.value(value: esp32Service),
        Provider<IoTDataOrchestrator>.value(value: iotOrchestrator),
        Provider<MLAccidentDetector>.value(value: mlDetector),
        Provider<HotspotService>.value(value: sharedHotspotService),
        ChangeNotifierProvider<ThemeModeController>.value(
          value: themeModeController,
        ),
        Provider<LocationEnrichmentService>.value(
          value: sharedEnrichmentService,
        ),
      ],
      child: Consumer<ThemeModeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: 'rapidAid V2',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeController.themeMode,
          home: const SplashScreenNew(),
        ),
      ),
    );
  }
}
