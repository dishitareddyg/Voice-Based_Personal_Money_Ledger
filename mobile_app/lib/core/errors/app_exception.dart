import 'package:dio/dio.dart';

enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  server,
  speech,
  cancelled,
  unknown,
}

/// A user-presentable error. Backend payload details are intentionally kept
/// out of the primary message so that implementation details never leak into
/// the UI.
class AppException implements Exception {
  const AppException({
    required this.message,
    required this.kind,
    this.statusCode,
    this.details,
  });

  final String message;
  final AppErrorKind kind;
  final int? statusCode;
  final Map<String, dynamic>? details;

  bool get isUnauthorized => kind == AppErrorKind.unauthorized;

  @override
  String toString() => message;

  factory AppException.fromDio(DioException error) {
    final status = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppException(
        message: 'The server took too long to respond. Please try again.',
        kind: AppErrorKind.timeout,
      );
    }

    if (error.type == DioExceptionType.cancel) {
      return const AppException(
        message: 'The request was cancelled.',
        kind: AppErrorKind.cancelled,
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown && error.response == null) {
      return const AppException(
        message:
            'Could not reach your Raspberry Pi ledger. Check Wi-Fi and the server.',
        kind: AppErrorKind.network,
      );
    }

    final message = _extractMessage(error.response?.data);
    final kind = _kindForStatus(status);

    return AppException(
      message: message ?? _fallbackMessage(kind),
      kind: kind,
      statusCode: status,
      details: _asMap(error.response?.data),
    );
  }

  static AppErrorKind _kindForStatus(int? status) {
    switch (status) {
      case 400:
      case 422:
        return AppErrorKind.validation;
      case 401:
        return AppErrorKind.unauthorized;
      case 403:
        return AppErrorKind.forbidden;
      case 404:
        return AppErrorKind.notFound;
      case 409:
        return AppErrorKind.conflict;
      case null:
        return AppErrorKind.unknown;
      default:
        if (status >= 500) return AppErrorKind.server;
        return AppErrorKind.unknown;
    }
  }

  static String _fallbackMessage(AppErrorKind kind) {
    switch (kind) {
      case AppErrorKind.unauthorized:
        return 'Your session has expired. Please sign in again.';
      case AppErrorKind.forbidden:
        return 'You do not have permission to perform this action.';
      case AppErrorKind.notFound:
        return 'The requested record could not be found.';
      case AppErrorKind.validation:
        return 'Some details are invalid. Please review and try again.';
      case AppErrorKind.conflict:
        return 'This action conflicts with an existing record.';
      case AppErrorKind.server:
        return 'The ledger server encountered an error. Please retry.';
      case AppErrorKind.speech:
        return 'Voice recognition is unavailable on this device.';
      case AppErrorKind.network:
        return 'No network connection to the ledger server.';
      case AppErrorKind.timeout:
        return 'The request timed out.';
      case AppErrorKind.cancelled:
        return 'The request was cancelled.';
      case AppErrorKind.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static String? _extractMessage(dynamic data) {
    final map = _asMap(data);
    if (map == null) return null;

    final direct = map['message'] ?? map['detail'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    if (direct is List) {
      final messages = direct
          .whereType<Map>()
          .map((entry) => entry['msg'])
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList();
      if (messages.isNotEmpty) return messages.join(' ');
    }

    final error = map['error'];
    if (error is String && error.trim().isNotEmpty) return error;
    if (error is Map) {
      final nested = error['message'] ?? error['detail'];
      if (nested is String && nested.trim().isNotEmpty) return nested;
    }
    return null;
  }
}

String friendlyErrorMessage(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
