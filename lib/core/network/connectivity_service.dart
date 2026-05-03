import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;
  List<ConnectivityResult> _lastResults = const [ConnectivityResult.none];

  Stream<bool> get connectionStream {
    _connectionController ??= StreamController<bool>.broadcast();
    return _connectionController!.stream;
  }

  Future<void> initialize() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    _lastResults = results;
    final isConnected = results.any((result) => result != ConnectivityResult.none);
    _connectionController?.add(isConnected);
  }

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<List<ConnectivityResult>> get connectivityResult async {
    final results = await _connectivity.checkConnectivity();
    return results;
  }

  bool get hasWifi => _lastResults.contains(ConnectivityResult.wifi);
  bool get hasMobile => _lastResults.contains(ConnectivityResult.mobile);
  bool get hasEthernet => _lastResults.contains(ConnectivityResult.ethernet);

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
  }
}
