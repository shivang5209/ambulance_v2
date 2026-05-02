import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checks for a new TFLite model version in Firestore on app startup and
/// downloads it from Firebase Storage if a newer version exists.
///
/// OTA flow:
///   1. Query `/model_versions` where `is_active=true`, order by `created_at`
///      desc, limit 1.
///   2. Compare `version_id` with the one stored in SharedPreferences.
///   3. If different: download the `.tflite` from `storage_path`.
///   4. Save to the app documents directory and persist the new version_id.
///   5. Return the local file path so [MLAccidentDetector] can hot-swap.
class ModelUpdateService {
  static const _collection = 'model_versions';
  static const _prefKey = 'ml_model_version';

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ModelUpdateService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Returns the local file path if a new model was downloaded, or `null`
  /// if the app is already running the latest version.
  Future<String?> checkAndUpdate() async {
    try {
      // 1. Fetch the active model version from Firestore
      final snap = await _db
          .collection(_collection)
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final doc = snap.docs.first;
      final remoteVersion = doc.id; // version_id is the document ID
      final storagePath = doc.data()['storage_path'] as String? ?? '';

      if (storagePath.isEmpty) return null;

      // 2. Compare with stored version
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getString(_prefKey);

      if (localVersion == remoteVersion) return null; // Already up to date

      // 3. Download the .tflite file
      final ref = _storage.ref(storagePath);
      final bytes = await ref.getData(10 * 1024 * 1024); // max 10 MB
      if (bytes == null) return null;

      // 4. Save to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/accident_detector_$remoteVersion.tflite');
      await localFile.writeAsBytes(bytes);

      // 5. Update SharedPreferences and return path for hot-swap
      await prefs.setString(_prefKey, remoteVersion);
      return localFile.path;
    } catch (_) {
      // Network errors, storage errors — silently skip update
      return null;
    }
  }

  /// Returns the currently active version ID stored locally.
  Future<String?> get currentVersion async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }
}
