import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_config.dart';

/// Service for communicating with the Laravel Auth API.
///
/// Access token, refresh token and user data are kept **in-memory only** so
/// closing the app clears the session and requires re-login.
class AuthService {
  // Change this base URL to your production URL when deploying.
  static const String _baseUrl = 'http://127.0.0.1:9000/api/auth';

  late final Dio _dio;

  // In-memory session — lost when the app process dies.
  static String? _accessToken;
  static String? _refreshToken;
  static String? _deviceUuid;
  static String? _lastSessionEndReason;
  static Map<String, dynamic>? _currentUser;

  static const String _rememberedEmailKey = 'remembered_email';
  static const String _deviceUuidKey = 'device_uuid';

  AuthService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    // Restore header if token already exists from an earlier call in this run.
    if (_accessToken != null) {
      _setAuthHeader(_accessToken!);
    }
  }

  /// Set auth token in Dio headers.
  void _setAuthHeader(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ──────────────────────────────────────────────────
  // Token / Session helpers (in-memory)
  // ──────────────────────────────────────────────────

  /// Get current auth token (in-memory).
  String? getToken() => _accessToken;

  /// Check if user is authenticated.
  bool isAuthenticated() => _accessToken != null && _accessToken!.isNotEmpty;

  /// Consume and clear the latest session end reason captured from API.
  String? consumeSessionEndReason() {
    final reason = _lastSessionEndReason;
    _lastSessionEndReason = null;
    return reason;
  }

  /// Store token and user data in-memory.
  void _saveSession({
    required String accessToken,
    required String? refreshToken,
    required String? deviceUuid,
    required Map<String, dynamic> user,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _deviceUuid = deviceUuid;
    _currentUser = user;
    _setAuthHeader(accessToken);
  }

  /// Get current user data (in-memory).
  Map<String, dynamic>? getStoredUser() => _currentUser;

  /// Clear session.
  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
    _deviceUuid = null;
    _currentUser = null;
    _dio.options.headers.remove('Authorization');
  }

  String _platformLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<String> _ensureDeviceUuid() async {
    if (_deviceUuid != null && _deviceUuid!.isNotEmpty) {
      return _deviceUuid!;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceUuidKey);
    if (existing != null && existing.isNotEmpty) {
      _deviceUuid = existing;
      return existing;
    }

    final generated = const Uuid().v4();
    await prefs.setString(_deviceUuidKey, generated);
    _deviceUuid = generated;
    return generated;
  }

  Future<Map<String, dynamic>> _buildDevicePayload() async {
    final platform = _platformLabel();
    final deviceUuid = await _ensureDeviceUuid();

    return {
      'device_uuid': deviceUuid,
      'platform': platform,
      'device_name': platform,
      'app_version': AppConfig.appVersion,
    };
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      _lastSessionEndReason = 'NO_REFRESH_TOKEN';
      return false;
    }

    final deviceUuid = await _ensureDeviceUuid();

    try {
      final response = await _dio.post(
        '/refresh',
        data: {'refresh_token': _refreshToken, 'device_uuid': deviceUuid},
      );

      final result = response.data as Map<String, dynamic>;
      if (result['success'] != true) {
        final reason = result['reason'] as String?;
        _lastSessionEndReason = reason ?? 'SESSION_INVALIDATED';
        return false;
      }

      final newAccessToken = result['access_token'] as String?;
      final newRefreshToken = result['refresh_token'] as String?;
      final newDeviceUuid = (result['device_uuid'] as String?) ?? deviceUuid;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        return false;
      }

      _saveSession(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        deviceUuid: newDeviceUuid,
        user: _currentUser ?? <String, dynamic>{},
      );

      _lastSessionEndReason = null;

      return true;
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        _lastSessionEndReason =
            (data['reason'] as String?) ?? 'SESSION_INVALIDATED';
      } else {
        _lastSessionEndReason = 'SESSION_INVALIDATED';
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> _authorizedCall(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          try {
            final retryResponse = await request();
            return retryResponse.data as Map<String, dynamic>;
          } on DioException catch (retryError) {
            return _handleError(retryError);
          }
        }
      }
      return _handleError(e);
    }
  }

  // ──────────────────────────────────────────────────
  // Remember Me
  // ──────────────────────────────────────────────────

  Future<void> saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, email);
  }

  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey);
  }

  // ──────────────────────────────────────────────────
  // API Calls
  // ──────────────────────────────────────────────────

  /// Step 1: Validate email and get user preview.
  Future<Map<String, dynamic>> validateEmail(String email) async {
    try {
      final response = await _dio.post(
        '/validate-email',
        data: {'email': email.trim().toLowerCase()},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Step 2: Login with email + password or PIN.
  Future<Map<String, dynamic>> login({
    required String email,
    required String authMethod,
    String? password,
    String? pin,
  }) async {
    try {
      final devicePayload = await _buildDevicePayload();
      final data = <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'auth_method': authMethod,
        ...devicePayload,
      };
      if (authMethod == 'password') {
        data['password'] = password;
      } else {
        data['pin'] = pin;
      }

      final response = await _dio.post('/login', data: data);
      final result = response.data as Map<String, dynamic>;

      final accessToken =
          (result['access_token'] ?? result['token']) as String?;
      final refreshToken = result['refresh_token'] as String?;
      final deviceUuid = result['device_uuid'] as String?;

      if (result['success'] == true && accessToken != null) {
        _saveSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          deviceUuid: deviceUuid,
          user:
              (result['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
      }

      return result;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Register a new user.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String companyCode,
  }) async {
    try {
      final devicePayload = await _buildDevicePayload();
      final response = await _dio.post(
        '/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'password_confirmation': passwordConfirmation,
          'company_code': companyCode.trim().toUpperCase(),
          ...devicePayload,
        },
      );
      final result = response.data as Map<String, dynamic>;

      final accessToken =
          (result['access_token'] ?? result['token']) as String?;
      final refreshToken = result['refresh_token'] as String?;
      final deviceUuid = result['device_uuid'] as String?;

      if (result['success'] == true && accessToken != null) {
        _saveSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          deviceUuid: deviceUuid,
          user:
              (result['user'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
      }

      return result;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Validate business code.
  Future<Map<String, dynamic>> validateBusinessCode(String code) async {
    try {
      final response = await _dio.post(
        '/validate-business-code',
        data: {'company_code': code.trim().toUpperCase()},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Forgot password.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        '/forgot-password',
        data: {'email': email.trim().toLowerCase()},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Logout.
  Future<void> logout() async {
    try {
      final token = getToken();
      if (token != null) {
        _setAuthHeader(token);
        await _authorizedCall(() => _dio.post('/logout'));
      }
    } catch (_) {
      // Ignore errors on logout
    } finally {
      clearSession();
    }
  }

  /// Get current user info.
  Future<Map<String, dynamic>> getUser() async {
    final token = getToken();
    if (token != null) _setAuthHeader(token);

    final result = await _authorizedCall(() => _dio.get('/user'));
    if (result['success'] == true && result['user'] is Map<String, dynamic>) {
      _currentUser = result['user'] as Map<String, dynamic>;
    }
    return result;
  }

  /// Handle Dio errors uniformly.
  Map<String, dynamic> _handleError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      return e.response!.data as Map<String, dynamic>;
    }
    return {
      'success': false,
      'valid': false,
      'message':
          e.response?.statusMessage ?? 'Connection error. Please try again.',
    };
  }
}
