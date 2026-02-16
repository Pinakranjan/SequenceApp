import 'package:flutter/material.dart';
import 'app_config.dart';

/// App color palette - OJEE branding colors
/// Primary colors are sourced from AppConfig for easy modification
class AppColors {
  AppColors._();

  // Primary Colors (from AppConfig)
  static const Color primaryGreen = Color(AppConfig.themePrimaryColorValue);
  static const Color primaryGreenLight = Color(
    AppConfig.primaryColorLightValue,
  );
  static const Color primaryGreenDark = Color(AppConfig.primaryColorDarkValue);

  // Accent Colors (from AppConfig)
  static const Color goldAccent = Color(AppConfig.accentColorValue);
  static const Color goldAccentLight = Color(AppConfig.accentColorLightValue);

  // Header Gradient Colors (from AppConfig)
  static const Color headerGradientStart = Color(
    AppConfig.headerGradientStartColorValue,
  );
  static const Color headerGradientEnd = Color(
    AppConfig.headerGradientEndColorValue,
  );

  // Layout Colors
  static const Color appBarColor = Color(AppConfig.appBarColorValue);

  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color dividerLight = Color(0xFFE0E0E0);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2A2A2A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  static const Color dividerDark = Color(0xFF3A3A3A);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Notice Type Colors
  static const Color pdfColor = Color(0xFFDC2626);
  static const Color linkColor = Color(0xFF2563EB);
  static const Color textColor = Color(0xFF059669);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [headerGradientStart, headerGradientEnd],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [headerGradientStart, headerGradientEnd],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldAccent, goldAccentLight],
  );
}
