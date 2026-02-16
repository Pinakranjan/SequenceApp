import 'app_config.dart';

/// API configuration constants
/// Uses centralized values from AppConfig for easy modification
class ApiConstants {
  ApiConstants._();

  /// Base URL for the OJEE API
  static const String baseUrl = AppConfig.apiBaseUrl;

  /// API authentication token
  static const String apiToken = AppConfig.apiToken;

  /// API Endpoints
  static const String notices = '/noticeitems';
  static const String institutes = '/institutes';
  static const String specialLinks = '/speciallinks';
  static const String latestVersion = '/latestversionios';
  static const String latestNotes = '/latestnotesios';

  /// PDF base URL
  static const String pdfBaseUrl = AppConfig.pdfBaseUrl;

  /// Request timeout duration
  static const Duration connectTimeout = AppConfig.connectTimeout;
  static const Duration receiveTimeout = AppConfig.receiveTimeout;
}
