import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

/// Theme mode state notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'theme_mode';

  bool _userHasSetTheme = false;

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  /// Load theme mode from shared preferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_key);

    if (!_userHasSetTheme && themeModeIndex != null) {
      state = ThemeMode.values[themeModeIndex];
    }
  }

  /// Set theme mode and persist to shared preferences
  Future<void> setThemeMode(ThemeMode mode) async {
    _userHasSetTheme = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme({Brightness? currentBrightness}) async {
    final effectiveBrightness =
        state == ThemeMode.system
            ? (currentBrightness ??
                WidgetsBinding.instance.platformDispatcher.platformBrightness)
            : (state == ThemeMode.dark ? Brightness.dark : Brightness.light);

    final newMode =
        effectiveBrightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark;

    await setThemeMode(newMode);
  }

  /// Check if current theme is dark
  bool get isDark => state == ThemeMode.dark;
}
