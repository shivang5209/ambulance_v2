# 🚀 New Project Blueprint
## Emergency Ambulance v2 — ML-Enhanced Build Plan

---

## PHASE 1: Copy Existing Frontend & Working Features

### Source: `D:\Emergency Ambulance\stable_ambulance_app\`

Copy these files/folders as-is into the new project. They are working and tested.

### Files to COPY (no changes needed)

```
lib/
├── main.dart                                    ← App entry point
├── firebase_options.dart                        ← Firebase config (regenerate for new project)
│
├── config/
│   ├── app_icons.dart                           ← Icon definitions
│   └── app_theme.dart                           ← Theme config stub
│
├── core/
│   ├── constants/
│   │   ├── api_constants.dart                   ← API endpoints
│   │   ├── app_constants.dart                   ← App-wide constants
│   │   ├── app_theme.dart                       ← Full theme (glassmorphism, neumorphism)
│   │   └── supabase_config.dart                 ← Supabase connection
│   ├── errors/
│   │   ├── error_handler.dart                   ← Global error handling
│   │   └── exceptions.dart                      ← Custom exception classes
│   ├── network/
│   │   ├── connectivity_service.dart            ← Online/offline detection
│   │   └── dio_client.dart                      ← HTTP client wrapper
│   ├── services/
│   │   ├── firebase_service.dart                ← Firebase init wrapper
│   │   ├── notification_service.dart            ← Push notifications
│   │   └── web_socket_service.dart              ← WebSocket handler
│   ├── theme/
│   │   └── app_theme.dart                       ← ThemeData definitions
│   └── utils/
│       └── logger.dart                          ← Logging utility
│
├── models/
│   ├── models.dart                              ← Barrel export file
│   ├── user.dart                                ← User model + UserRole enum
│   ├── user.g.dart                              ← Generated serialization
│   ├── user_profile.dart                        ← Detailed user profile
│   ├── ambulance.dart                           ← Ambulance model
│   ├── ambulance.g.dart                         ← Generated serialization
│   ├── ambulance_request.dart                   ← Ambulance request model
│   ├── accident_alert.dart                      ← Alert model
│   ├── accident_alert.g.dart                    ← Generated serialization
│   ├── accident_event.dart                      ← Full accident event model
│   ├── emergency_response.dart                  ← Emergency response model
│   ├── hospital.dart                            ← Hospital model
│   ├── hospital.g.dart                          ← Generated serialization
│   ├── position.dart                            ← Position model
│   ├── position.g.dart                          ← Generated serialization
│   ├── vehicle_parameters.dart                  ← Sensor data model ⚠️ MODIFY LATER
│   ├── app_state.dart                           ← App state model
│   └── auth_response.dart                       ← Auth response model
│
├── providers/
│   └── auth_provider.dart                       ← Auth state management
│
├── screens/
│   ├── splash_screen_new.dart                   ← Animated splash
│   ├── onboarding_screen.dart                   ← First-time user onboarding
│   ├── user_type_selection_screen.dart           ← Role picker
│   ├── role_selection_screen.dart                ← Role selection variant
│   ├── login_screen.dart                        ← Login form
│   ├── initial_login_screen.dart                ← Initial login flow
│   ├── register_screen.dart                     ← Registration form
│   ├── home_screen.dart                         ← Generic home
│   ├── role_home_shell.dart                     ← Shell for role-based homes
│   ├── driver_home_screen.dart                  ← Driver dashboard ⚠️ MODIFY LATER
│   ├── driver_role_shell_screen.dart            ← Driver shell/nav
│   ├── admin_home_screen.dart                   ← Admin dashboard ⚠️ MODIFY LATER
│   ├── admin_role_shell_screen.dart             ← Admin shell/nav
│   ├── family_home_screen.dart                  ← Family/citizen dashboard
│   ├── hospital_home_screen.dart                ← Hospital dashboard
│   ├── esp32_management_screen.dart             ← IoT device management
│   ├── request_form_screen.dart                 ← Ambulance request form
│   ├── status_screen.dart                       ← Request status tracking
│   └── role_homes/
│       ├── driver_home.dart                     ← Simple driver home
│       ├── citizen_home.dart                    ← Simple citizen home
│       ├── admin_home.dart                      ← Simple admin home
│       └── hospital_home.dart                   ← Simple hospital home
│
├── services/
│   ├── esp32_service.dart                       ← Platform export
│   ├── esp32_service_io.dart                    ← ESP32 real device communication
│   ├── esp32_service_web.dart                   ← ESP32 web fallback
│   ├── esp32_simulator.dart                     ← Simulator for testing
│   ├── firebase_auth_service.dart               ← Firebase auth
│   ├── firebase_auth_service_template.dart      ← Auth service template
│   ├── firebase_rtd_repository.dart             ← Realtime DB repository
│   ├── iot_data_orchestrator_mobile.dart         ← IoT data pipeline ⚠️ MODIFY LATER
│   ├── iot_data_orchestrator_web.dart            ← IoT web fallback
│   ├── mock_ambulance_service.dart              ← Mock ambulance data
│   ├── mock_auth_service.dart                   ← Mock auth for testing
│   ├── secure_storage_service.dart              ← Encrypted local storage
│   ├── supabase_repository.dart                 ← Supabase analytics
│   └── routing/
│       ├── city_graph.dart                      ← Graph data structure
│       ├── demo_city_graph.dart                 ← Demo city data
│       └── fastest_route_service.dart           ← A* / Dijkstra routing
│
├── features/
│   ├── auth/                                    ← Auth feature (BLoC pattern)
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── ambulance/                               ← Ambulance feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── citizen/                                 ← Citizen feature (empty)
│   ├── admin/                                   ← Admin feature (empty)
│   ├── hospital/                                ← Hospital feature (empty)
│   └── driver/                                  ← Driver feature (empty)
│
├── utils/
│   └── responsive_helper.dart                   ← Screen size helpers
│
└── widgets/
    ├── max_width_container.dart                  ← Max width wrapper
    ├── responsive_grid.dart                      ← Responsive grid layout
    ├── tac_alert_item.dart                       ← Alert list item widget
    ├── tac_button.dart                            ← Custom button widget
    ├── tac_device_card.dart                       ← IoT device card widget
    ├── tac_stat_card.dart                         ← Statistics card widget
    └── tac_text_field.dart                        ← Custom text field widget
```

### Also Copy

```
esp32/
└── accident_detection.ino               ← Arduino code for ESP32 hardware

assets/
├── animations/                          ← Lottie animation files
├── icon/                                ← App icon
├── icons/                               ← UI icons
└── images/                              ← Image assets

android/                                 ← Android platform (regenerate for new project)
pubspec.yaml                             ← Dependencies ⚠️ MODIFY (add ML packages)
analysis_options.yaml                    ← Lint rules
```

---

## PHASE 2: Modify Existing Files

### 1. `pubspec.yaml` — Add ML dependencies

```yaml
# ADD these new dependencies:
  # ML / AI
  tflite_flutter: ^0.10.4            # On-device TFLite inference
  google_generative_ai: ^0.4.3       # Gemini Flash API
  
  # Location Intelligence
  google_maps_flutter_heatmap: ^0.2.0  # Heatmap overlay
  
  # Model Updates
  # path_provider already exists
  # shared_preferences already exists
  # firebase_storage — add if not present
  firebase_storage: ^12.3.6

# ADD to assets:
  assets:
    - assets/models/                   # TFLite model files
```

### 2. `lib/models/vehicle_parameters.dart` — Remove hardcoded thresholds

- Remove `exceedsAccidentThreshold` getter (ML replaces this)
- Keep `totalAcceleration`, `isNormalDriving` as utility getters
- Add `toFeatureVector()` method that flattens sensor data for ML input

### 3. `lib/models/accident_event.dart` — Add ML fields

- Add `mlConfidence` field to `AccidentAnalysis`
- Add `predictedType` field (frontal, rollover, side, rear)

### 4. `lib/services/iot_data_orchestrator_mobile.dart` — Replace detection logic

- Replace rule-based `exceedsAccidentThreshold` check
- Call `MLAccidentDetector.predict()` with 5-sample sliding window
- Save inference record to `/training_data` via `TrainingDataService`

### 5. `lib/screens/driver_home_screen.dart` — Add hotspot warnings

- Add geofence check on GPS updates
- Show non-intrusive hotspot warning banner

### 6. `lib/screens/admin_home_screen.dart` — Add heatmap

- Add Google Maps heatmap overlay from `/accident_events` GPS data
- Show hotspot zone circles from `/hotspots` collection

---

## PHASE 3: Create New Files (ML + Location Intelligence)

### New Models

| File | Purpose |
|---|---|
| `lib/models/location_context.dart` | Road type, weather, time-of-day, speed limit encoding |
| `lib/models/hotspot_zone.dart` | Hotspot data model with geofence radius, peak hours |
| `lib/models/accident_prediction.dart` | ML prediction result (probability, type, severity) |

### New Services

| File | Purpose |
|---|---|
| `lib/services/ml_accident_detector.dart` | TFLite model loader + 38-float inference |
| `lib/services/training_data_service.dart` | Save input/output/labels to Firestore `/training_data` |
| `lib/services/model_update_service.dart` | OTA model download from Firebase Storage on startup |
| `lib/services/hotspot_service.dart` | DBSCAN clustering + geofence proximity checks |
| `lib/services/location_enrichment_service.dart` | Adds road_type, weather, time context to events |
| `lib/services/gemini_service.dart` | Gemini Flash API wrapper for hotspot reasoning |

### New Widgets

| File | Purpose |
|---|---|
| `lib/widgets/accident_confirmation_dialog.dart` | Driver confirms/dismisses alert → training label |
| `lib/widgets/hotspot_warning_banner.dart` | Non-intrusive warning when approaching hotspot |
| `lib/widgets/heatmap_overlay.dart` | Admin dashboard heatmap component |

### New Assets

| File | Purpose |
|---|---|
| `assets/models/accident_detector.tflite` | Initial ML model (trained in Colab on simulator data) |

### Cloud Functions (Firebase)

| File | Purpose |
|---|---|
| `functions/index.js` | Contains 2 scheduled functions |
| — `hotspotAnalysis` | Every 15 min: DBSCAN + Gemini on accident GPS data |
| — `weeklyDriftCheck` | Every Monday: calculate FPR, alert admin if >20% |

### Training Pipeline (Google Colab)

| File | Purpose |
|---|---|
| `colab/retrain_model.py` | Weekly retraining notebook |
| `colab/generate_training_data.py` | Run ESP32Simulator → export 10,000 samples to CSV |
| `colab/initial_training.py` | First-time model training from scratch |

---

## PHASE 4: Firestore Collections (New)

| Collection | Purpose | Created By |
|---|---|---|
| `/training_data` | Input features + model output + true labels | Flutter app |
| `/model_versions` | OTA version tracking | Colab retraining script |
| `/model_health` | Weekly drift reports (FPR, precision) | Cloud Function |
| `/hotspots` | Clustered danger zones with Gemini analysis | Cloud Function |

---

## Build Order

```
Step 1: Create new Flutter project, copy all Phase 1 files
Step 2: flutter pub get (with updated pubspec.yaml)
Step 3: Run flutterfire configure for new Firebase project
Step 4: Create new models (location_context, hotspot_zone, accident_prediction)
Step 5: Create MLAccidentDetector service (TFLite wrapper)
Step 6: Generate initial training data in Colab using ESP32Simulator logic
Step 7: Train initial model in Colab → export .tflite → place in assets/models/
Step 8: Create TrainingDataService + ModelUpdateService
Step 9: Modify IoTDataOrchestrator to use ML instead of rules
Step 10: Create HotspotService + GeminiService
Step 11: Create AccidentConfirmationDialog widget
Step 12: Modify DriverHomeScreen (hotspot warnings)
Step 13: Modify AdminHomeScreen (heatmap)
Step 14: Deploy Cloud Functions (hotspot analysis + drift monitoring)
Step 15: Test end-to-end with ESP32 simulator
```

---

*Created: 2026-05-03 | Project: Emergency Ambulance v2*
