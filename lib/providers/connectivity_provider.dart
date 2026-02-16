import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/connectivity_service.dart';

/// Provider for ConnectivityService instance
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for offline status stream
final isOfflineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.isOfflineStream;
});

/// Provider for current offline status
final isOfflineProvider = StateNotifierProvider<_OfflineNotifier, bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return _OfflineNotifier(service);
});

class _OfflineNotifier extends StateNotifier<bool> {
  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;
  Timer? _pollTimer;
  
  _OfflineNotifier(this._service) : super(_service.isOffline) {
    // Listen to the stream from connectivity service
    _subscription = _service.isOfflineStream.listen((isOffline) {
      if (state != isOffline) {
        state = isOffline;
      }
    });
    
    // Fallback: Poll connectivity every 3 seconds for iOS reliability
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _service.checkConnectivity();
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
