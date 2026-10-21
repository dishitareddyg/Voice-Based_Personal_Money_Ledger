import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/config/app_config.dart';
import 'package:voice_ledger/models/auth_session.dart';
import 'package:voice_ledger/services/api_client.dart';
import 'package:voice_ledger/services/secure_token_storage.dart';

class _FakeTokenStorage implements TokenStorage {
  String? token = 'test-jwt';

  @override
  Future<void> clearSession() async => token = null;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<AuthSession?> readSession() async => null;

  @override
  Future<String?> readSetting(String key) async => null;

  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<void> writeSetting(String key, String value) async {}
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statuses);

  final List<int> statuses;
  int calls = 0;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final index = calls < statuses.length ? calls : statuses.length - 1;
    final status = statuses[index];
    calls++;
    return ResponseBody.fromString(
      '{"ok":true}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _config = AppConfig(
  apiBaseUrl: 'https://pi.local/api/v1',
  environment: 'test',
  defaultCurrency: 'INR',
  defaultTimezone: 'Asia/Kolkata',
  connectTimeout: Duration(seconds: 5),
  receiveTimeout: Duration(seconds: 5),
);

void main() {
  test('attaches the bearer token and a request id', () async {
    final adapter = _FakeAdapter([200]);
    final dio = createApiClient(_config, _FakeTokenStorage());
    dio.httpClientAdapter = adapter;

    await dio.get<dynamic>('/auth/me');

    expect(adapter.lastOptions!.headers['Authorization'], 'Bearer test-jwt');
    final requestId = adapter.lastOptions!.headers['X-Request-ID'];
    expect(requestId, isA<String>());
    expect((requestId as String).isNotEmpty, isTrue);
  });

  test('retries a GET on a transient 503', () async {
    final adapter = _FakeAdapter([503, 503, 200]);
    final dio = createApiClient(_config, _FakeTokenStorage());
    dio.httpClientAdapter = adapter;

    final response = await dio.get<dynamic>('/transactions');

    expect(response.statusCode, 200);
    expect(adapter.calls, 3);
  });

  test('does not retry a POST without an idempotency key', () async {
    final adapter = _FakeAdapter([503]);
    final dio = createApiClient(_config, _FakeTokenStorage());
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.post<dynamic>('/transactions', data: const {}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
  });

  test('retries a POST that carries an idempotency key', () async {
    final adapter = _FakeAdapter([503, 200]);
    final dio = createApiClient(_config, _FakeTokenStorage());
    dio.httpClientAdapter = adapter;

    final response = await dio.post<dynamic>(
      '/transactions',
      data: const {},
      options: Options(headers: {'Idempotency-Key': 'request-1'}),
    );

    expect(response.statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('raises the session-expired callback on an authenticated 401', () async {
    var expired = false;
    final adapter = _FakeAdapter([401]);
    final dio = createApiClient(
      _config,
      _FakeTokenStorage(),
      onUnauthorized: () => expired = true,
    );
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.get<dynamic>('/transactions'),
      throwsA(isA<DioException>()),
    );
    expect(expired, isTrue);
  });

  test('ignores a failed login when raising session-expired', () async {
    var expired = false;
    final adapter = _FakeAdapter([401]);
    final dio = createApiClient(
      _config,
      _FakeTokenStorage(),
      onUnauthorized: () => expired = true,
    );
    dio.httpClientAdapter = adapter;

    await expectLater(
      dio.post<dynamic>('/auth/login', data: const {}),
      throwsA(isA<DioException>()),
    );
    expect(expired, isFalse);
  });
}
