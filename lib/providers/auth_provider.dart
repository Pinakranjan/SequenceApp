import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/auth_service.dart';

/// Singleton provider for AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Tracks whether the user is authenticated (in-memory token check).
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.isAuthenticated();
});

/// Provides the current user data (in-memory).
final storedUserProvider = Provider<Map<String, dynamic>?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.getStoredUser();
});

/// Provides the remembered email (persisted in SharedPreferences).
final rememberedEmailProvider = FutureProvider<String?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getRememberedEmail();
});
