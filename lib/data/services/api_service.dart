import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/api_error_handler.dart';

/// API Service for making HTTP requests
class ApiService {
  late final Dio _dio;

  static const int _maxStringLogLength = 800;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': ApiConstants.apiToken,
        },
      ),
    );

    // Add lightweight logging interceptor for debugging.
    // Avoid dumping huge JSON responses (can slow the app + disconnect tooling).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('API: *** Request ***');
          debugPrint('API: ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('API: *** Response ***');
          debugPrint(
            'API: ${response.statusCode} ${response.requestOptions.uri}',
          );
          debugPrint('API: ${_summarizeResponseBody(response.data)}');
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('API: *** Error ***');
          debugPrint(
            'API: ${error.requestOptions.method} ${error.requestOptions.uri}',
          );
          debugPrint('API: ${error.type}');
          if (error.message != null) {
            debugPrint(
              'API: ${_truncate(error.message!, _maxStringLogLength)}',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  static String _summarizeResponseBody(dynamic data) {
    if (data == null) {
      return 'body: <null>';
    }

    if (data is Map) {
      final keys = data.keys.take(12).toList();
      final hasMoreKeys = data.keys.length > keys.length;
      final stat = data['stat'];
      final content = data['content'];

      final buffer = StringBuffer();
      buffer.write(
        'body: Map(keys=${keys.join(',')}${hasMoreKeys ? ',…' : ''}',
      );
      if (stat != null) {
        buffer.write(', stat=$stat');
      }
      if (content is Map) {
        buffer.write(', content={');
        final contentKeys = content.keys.take(8).toList();
        for (final key in contentKeys) {
          final value = content[key];
          buffer.write('$key:');
          if (value is List) {
            buffer.write('List(${value.length})');
          } else if (value is Map) {
            buffer.write('Map(${value.length})');
          } else {
            buffer.write(value.runtimeType);
          }
          buffer.write(', ');
        }
        if (content.keys.length > contentKeys.length) {
          buffer.write('…');
        }
        buffer.write('}');
      }
      buffer.write(')');
      return buffer.toString();
    }

    if (data is List) {
      return 'body: List(length=${data.length})';
    }

    if (data is String) {
      return 'body: "${_truncate(data, _maxStringLogLength)}"';
    }

    return 'body: ${_truncate(data.toString(), _maxStringLogLength)}';
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}…(truncated)';
  }

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Check for API-level success status
        if (data is Map<String, dynamic>) {
          final stat = data['stat'];
          if (stat == 'SUCCESS') {
            final content = data['content'];
            if (fromJson != null && content != null) {
              return ApiResponse.success(fromJson(content));
            }
            return ApiResponse.success(content as T);
          } else {
            return ApiResponse.error(data['message'] ?? 'Unknown error');
          }
        }

        if (fromJson != null) {
          return ApiResponse.success(fromJson(data));
        }
        return ApiResponse.success(data as T);
      }

      return ApiResponse.error(
        'Request failed with status: ${response.statusCode}',
      );
    } on DioException catch (e) {
      return ApiResponse.error(_handleDioError(e));
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  /// Handle Dio errors and return user-friendly messages
  String _handleDioError(DioException error) {
    return ApiErrorHandler.handleDioError(error);
  }
}

/// Generic API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResponse._({this.data, this.error, required this.isSuccess});

  factory ApiResponse.success(T data) {
    return ApiResponse._(data: data, isSuccess: true);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(error: message, isSuccess: false);
  }
}
