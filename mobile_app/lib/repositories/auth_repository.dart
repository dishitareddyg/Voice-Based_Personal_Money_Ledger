import 'package:dio/dio.dart';

import '../core/errors/app_exception.dart';
import '../models/auth_session.dart';
import '../models/json_utils.dart';
import '../models/user.dart';
import '../services/api_paths.dart';
import '../services/secure_token_storage.dart';
import 'api_helpers.dart';

abstract class AuthRepository {
  Future<AuthSession> login(LoginRequest request);
  Future<AuthSession> register(RegisterRequest request);
  Future<AuthSession?> restoreSession();
  Future<User> fetchProfile();
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiPaths.login,
        data: request.toJson(),
      );
      final session = await _parseSession(response.data);
      await _tokenStorage.saveSession(session);
      return session;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        message: 'The server returned an unexpected sign-in response.',
        kind: AppErrorKind.server,
      );
    }
  }

  @override
  Future<AuthSession> register(RegisterRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiPaths.register,
        data: request.toJson(),
      );
      final session = await _parseSession(response.data);
      await _tokenStorage.saveSession(session);
      return session;
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        message: 'The server returned an unexpected registration response.',
        kind: AppErrorKind.server,
      );
    }
  }

  @override
  Future<AuthSession?> restoreSession() => _tokenStorage.readSession();

  @override
  Future<User> fetchProfile() async {
    try {
      final response = await _dio.get<dynamic>(ApiPaths.me);
      final payload = asJsonMap(response.data);
      final nested = parseMap(payload['user']) ?? payload;
      return User.fromJson(nested);
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<dynamic>(ApiPaths.logout);
    } on DioException {
      // Local sign-out must still succeed if the network is unavailable.
    } finally {
      await _tokenStorage.clearSession();
    }
  }

  Future<AuthSession> _parseSession(dynamic data) async {
    final payload = asJsonMap(data);
    final nested = parseMap(payload['session']) ?? payload;
    final token = parseString(
      nested['access_token'] ??
          nested['accessToken'] ??
          nested['token'] ??
          parseMap(nested['tokens'])?['access_token'],
    );
    final refresh = parseString(
      nested['refresh_token'] ?? nested['refreshToken'],
      fallback: '',
    );

    if (token.isEmpty) {
      throw const AppException(
        message: 'The server did not return an access token.',
        kind: AppErrorKind.server,
      );
    }

    Map<String, dynamic>? userMap = parseMap(nested['user']);
    if (userMap == null && nested['email'] is String) {
      userMap = nested;
    }

    if (userMap == null) {
      try {
        final profile = await _dio.get<dynamic>(
          ApiPaths.me,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        final profilePayload = asJsonMap(profile.data);
        userMap = parseMap(profilePayload['user']) ?? profilePayload;
      } on DioException catch (error) {
        throw AppException.fromDio(error);
      }
    }

    if (userMap['email'] == null) {
      throw const AppException(
        message: 'The server did not return your profile.',
        kind: AppErrorKind.server,
      );
    }

    return AuthSession(
      accessToken: token,
      refreshToken: refresh.isEmpty ? null : refresh,
      user: User.fromJson(userMap),
    );
  }
}
