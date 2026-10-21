import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/utils/request_id.dart';
import 'api_paths.dart';
import 'secure_token_storage.dart';

/// Builds the single Dio client used for every call to the Raspberry Pi.
///
/// Responsibilities:
/// * attach the bearer token and a per-request `X-Request-ID`,
/// * retry transient failures for safe (idempotent) requests,
/// * surface an expired session through [onUnauthorized],
/// * log only the method, path and status (never bodies or headers).
Dio createApiClient(
  AppConfig config,
  TokenStorage tokenStorage, {
  void Function()? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.connectTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Client-Platform': 'android',
        'X-Client-App': 'voice-ledger',
      },
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers.putIfAbsent('X-Request-ID', generateRequestId);
        handler.next(options);
      },
    ),
  );

  dio.interceptors.add(_RetryInterceptor(dio));

  if (onUnauthorized != null) {
    dio.interceptors.add(_UnauthorizedInterceptor(onUnauthorized));
  }

  if (kDebugMode) {
    dio.interceptors.add(_SafeLogInterceptor());
  }

  return dio;
}

/// Retries transient network failures and retryable server errors. A request is
/// only retried when it is safe to do so: the HTTP verb is idempotent or the
/// caller supplied an `Idempotency-Key` for a create.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  static const String _attemptKey = 'voice_ledger.retry_attempt';
  static const int _maxAttempts = 3;
  static const Set<String> _idempotentMethods = {
    'GET',
    'HEAD',
    'OPTIONS',
    'PUT',
    'DELETE',
  };

  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 1;

    if (!_shouldRetry(err, options, attempt)) {
      handler.next(err);
      return;
    }

    options.extra[_attemptKey] = attempt + 1;
    await Future<void>.delayed(
      Duration(milliseconds: 250 * (1 << (attempt - 1))),
    );

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _shouldRetry(
    DioException err,
    RequestOptions options,
    int attempt,
  ) {
    if (attempt >= _maxAttempts) return false;
    if (err.type == DioExceptionType.cancel ||
        err.type == DioExceptionType.badCertificate) {
      return false;
    }

    final status = err.response?.statusCode;
    final transientStatus =
        status == 502 || status == 503 || status == 504;
    final transientNetworkError =
        err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.sendTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.connectionError ||
            (err.type == DioExceptionType.unknown && err.response == null);

    if (!transientStatus && !transientNetworkError) return false;

    final method = options.method.toUpperCase();
    return _idempotentMethods.contains(method) ||
        options.headers.containsKey('Idempotency-Key');
  }
}

/// Clears the stored session and notifies the app when an authenticated request
/// is rejected with 401. Sign-in and registration failures are ignored because
/// they are not an expired session.
class _UnauthorizedInterceptor extends Interceptor {
  _UnauthorizedInterceptor(this._onUnauthorized);

  final void Function() _onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;
    final isAuthCall = path == ApiPaths.login || path == ApiPaths.register;
    if (err.response?.statusCode == 401 && !isAuthCall) {
      _onUnauthorized();
    }
    handler.next(err);
  }
}

/// Logs only method, path and status. Request bodies and headers are never
/// logged so passwords and JWTs cannot leak into logcat.
class _SafeLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('API -> ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint(
      'API <- ${response.statusCode} ${response.requestOptions.uri.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      'API !! ${err.response?.statusCode ?? 'network'} '
      '${err.requestOptions.uri.path}',
    );
    handler.next(err);
  }
}
