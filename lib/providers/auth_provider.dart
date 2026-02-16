import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/auth_service.dart';

/// Singleton provider for AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Tracks whether the user is authenticated (has a stored token).
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.isAuthenticated();
});

/// Provides the stored user data.
final storedUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getStoredUser();
});

/// Provides the remembered email.
final rememberedEmailProvider = FutureProvider<String?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getRememberedEmail();
});
