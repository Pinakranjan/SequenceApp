import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_config.dart';

/// Key prefix for tracking which app version completed onboarding
const _onboardingKeyPrefix = 'onboarding_completed_';

/// Returns the SharedPreferences key for the current app version
String _onboardingKey() => '$_onboardingKeyPrefix${AppConfig.appVersion}';

/// Whether the onboarding walkthrough should be shown.
/// Returns `true` on first launch for a given app version.
final shouldShowOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final completed = prefs.getBool(_onboardingKey()) ?? false;
  return !completed;
});

/// Mark onboarding as completed for the current app version.
/// Call this when the user taps "Got it" or "Skip".
Future<void> completeOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingKey(), true);
}
