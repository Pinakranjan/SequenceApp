import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _isOfflineController =
      StreamController<bool>.broadcast();

  /// Stream of offline status (true = offline, false = online)
  Stream<bool> get isOfflineStream => _isOfflineController.stream;

  bool _isOffline = false;

  /// Current offline status
  bool get isOffline => _isOffline;

  /// Initialize and start listening to connectivity changes
  Future<void> initialize() async {
    try {
      // Check initial connectivity first and update state
      final initialResults = await _connectivity.checkConnectivity();
      _handleConnectivityChange(initialResults, emitAlways: true);

      // Then start listening to ongoing changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) => _handleConnectivityChange(results),
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Connectivity initialization failed: $e');
      // Assume online if we can't check
      _isOffline = false;
      _isOfflineController.add(false);
    }
  }

  void _handleConnectivityChange(
    List<ConnectivityResult> results, {
    bool emitAlways = false,
  }) {
    // In v7+, results is a list. It is considered offline if the list contains ONLY none,
    // or is empty. If it contains any other connection type (wifi, mobile, ethernet, etc), it is online.
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);

    if (offline != _isOffline || emitAlways) {
      _isOffline = offline;
      _isOfflineController.add(offline);
    }
  }

  /// Manually check connectivity (used for polling fallback)
  Future<void> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      // Silently ignore errors during polling
      debugPrint('Connectivity check failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _isOfflineController.close();
  }
}
