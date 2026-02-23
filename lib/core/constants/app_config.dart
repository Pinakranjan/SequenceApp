import 'package:flutter/material.dart';

/// Application Configuration
///
/// Centralized configuration file for easily changing app-wide settings.
/// Modify these values to configure the application behavior.
class AppConfig {
  AppConfig._();

  // ============================================
  // APP VERSION (used for onboarding gating)
  // ============================================

  /// Current app version string — update when bumping pubspec version.
  /// Onboarding walkthrough re-shows when this value changes.
  static const String appVersion = '1.5.0';

  // ============================================
  // LAYOUT
  // ============================================

  /// Default expanded height used by SliverAppBars across screens.
  /// Keep this compact to match the legacy app header proportions.
  static const double sliverAppBarExpandedHeight = 135;

  // ============================================
  // API CONFIGURATION
  // ============================================

  /// API authentication token
  static const String apiToken = '3dd43398ddc6de3f413295e54fdf6cf8';

  /// Request timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ============================================
  // THEME COLORS
  // ============================================

  /// Primary theme color (single place to change the app's main color).
  /// Update this (and optionally the related variants below) to re-skin the app.
  static const int themePrimaryColorValue = 0xFF745418; //0xFF0D4E2A

  /// Primary color light variant
  static const int primaryColorLightValue = 0xFF1A7A45;

  /// Primary color dark variant
  static const int primaryColorDarkValue = 0xFF083D1F;

  /// Accent/Gold color
  static const int accentColorValue = 0xFFD4AF37;

  /// Accent color light variant
  static const int accentColorLightValue = 0xFFE5C76B;

  /// Foreground icon/logo tint color used over header/splash backgrounds.
  /// Keep separate from themePrimaryColorValue for better contrast.
  static const int iconTintColorValue = 0xFF38B1C9;

  // ============================================
  // HEADER & LABEL COLORS
  // ============================================

  /// Header label color for light mode
  static const Color headerLabelColorLight = Colors.white;

  /// Header label color for dark mode
  static const Color headerLabelColorDark = Colors.white;

  /// Get header label color based on theme brightness
  static Color getHeaderLabelColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? headerLabelColorDark
        : headerLabelColorLight;
  }

  /// Default header title style (e.g. AppBar/FlexibleSpaceBar titles)
  static TextStyle? headerTitleTextStyle(ThemeData theme) {
    return theme.textTheme.titleLarge?.copyWith(
      color: getHeaderLabelColor(theme.brightness),
      fontWeight: FontWeight.w700,
      fontSize: 20,
    );
  }

  // ============================================
  // NOTIFICATION FEATURES
  // ============================================

  /// Whether to enable interactive snooze actions on local notifications.
  /// If true, notifications will show "Snooze" buttons.
  static const bool enableNotificationSnoozeActions = true;

  // ============================================
  // GEMINI AI (Voice Input)
  // ============================================

  /// Gemini API key for AI-powered voice command parsing.
  static const String geminiApiKey = 'AIzaSyCBynLmlfS3b4SgUz3JGPlKs7zJKPptzi0';
}
