import 'package:dio/dio.dart';

enum ApiErrorKind {
  connection,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  malformed,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.server,
  });
  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final body = response?.data;
    final message = body is Map && body['message'] is String
        ? body['message'] as String
        : null;
    final status = response?.statusCode;
    if (status == 401) {
      return ApiException(
        'Your session has expired. Please sign in again.',
        statusCode: status,
        kind: ApiErrorKind.unauthorized,
      );
    }
    if (status == 403) {
      return ApiException(
        message ?? 'You do not have permission to do that.',
        statusCode: status,
        kind: ApiErrorKind.forbidden,
      );
    }
    if (status == 404) {
      return ApiException(
        message ?? 'This item is unavailable.',
        statusCode: status,
        kind: ApiErrorKind.notFound,
      );
    }
    if (status == 422) {
      return ApiException(
        message ?? 'Please check the information and try again.',
        statusCode: status,
        kind: ApiErrorKind.validation,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return const ApiException(
        'Could not reach the marketplace. Check your connection and try again.',
        kind: ApiErrorKind.connection,
      );
    }
    return ApiException(
      message ?? 'Something went wrong. Please try again.',
      statusCode: status,
      kind: ApiErrorKind.server,
    );
  }

  @override
  String toString() => message;
}
