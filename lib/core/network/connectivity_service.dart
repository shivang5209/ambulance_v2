import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;

  Stream<bool> get connectionStream {
    _connectionController ??= StreamController<bool>.broadcast();
    return _connectionController!.stream;
  }

  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;
    _connectionController?.add(isConnected);
  }

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<ConnectivityResult> get connectivityResult async {
    final result = await _connectivity.checkConnectivity();
    return result;
  }

  bool get hasWifi => _lastResult == ConnectivityResult.wifi;
  bool get hasMobile => _lastResult == ConnectivityResult.mobile;
  bool get hasEthernet => _lastResult == ConnectivityResult.ethernet;

  final ConnectivityResult _lastResult = ConnectivityResult.none;

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
  }
}