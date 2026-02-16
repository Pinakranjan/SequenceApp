import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for communicating with the Laravel Auth API.
class AuthService {
  // Change this base URL to your production URL when deploying.
  static const String _baseUrl = 'http://127.0.0.1:9000/api/auth';

  late final Dio _dio;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _rememberedEmailKey = 'remembered_email';

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
  }

  /// Set auth token in Dio headers.
  void _setAuthHeader(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ──────────────────────────────────────────────────
  // Token / Session helpers
  // ──────────────────────────────────────────────────

  /// Get stored auth token.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Check if user is authenticated.
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Store token and user data.
  Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Get stored user data.
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Clear session.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
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
      final data = <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'auth_method': authMethod,
      };
      if (authMethod == 'password') {
        data['password'] = password;
      } else {
        data['pin'] = pin;
      }

      final response = await _dio.post('/login', data: data);
      final result = response.data as Map<String, dynamic>;

      if (result['success'] == true && result['token'] != null) {
        await _saveSession(result['token'], result['user']);
        _setAuthHeader(result['token']);
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
      final response = await _dio.post(
        '/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'password_confirmation': passwordConfirmation,
          'company_code': companyCode.trim().toUpperCase(),
        },
      );
      final result = response.data as Map<String, dynamic>;

      if (result['success'] == true && result['token'] != null) {
        await _saveSession(result['token'], result['user']);
        _setAuthHeader(result['token']);
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
      final token = await getToken();
      if (token != null) {
        _setAuthHeader(token);
        await _dio.post('/logout');
      }
    } catch (_) {
      // Ignore errors on logout
    } finally {
      await clearSession();
    }
  }

  /// Get current user info.
  Future<Map<String, dynamic>> getUser() async {
    try {
      final token = await getToken();
      if (token != null) _setAuthHeader(token);
      final response = await _dio.get('/user');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      return _handleError(e);
    }
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
