import 'package:dio/dio.dart';

class ApiErrorHandler {
  static String handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection and try again.';
      case DioExceptionType.sendTimeout:
        return 'The request took too long to send. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Please try again later.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Bad request. We couldn\'t process your request.';
          case 401:
            return 'Unauthorized. Please login again.';
          case 403:
            return 'Access denied. You don\'t have permission to view this resource.';
          case 404:
            return 'The requested resource was not found. It might have been moved or deleted.';
          case 500:
            return 'Internal server error. We\'re working on it. Please try again later.';
          case 503:
            return 'Service unavailable. Please try again later.';
          default:
            return 'Request failed with status code: $statusCode. Please try again.';
        }
      case DioExceptionType.cancel:
        return 'Request to server was cancelled.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network settings.';
      case DioExceptionType.unknown:
        if (error.error != null &&
            error.error.toString().contains('SocketException')) {
          return 'No internet connection. Please check your network settings.';
        }
        return 'Something went wrong. Please try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static String handleGenericError(dynamic error) {
    return 'An unexpected error occurred: $error';
  }
}
