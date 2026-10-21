import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

abstract class TokenStorage {
  Future<AuthSession?> readSession();
  Future<void> saveSession(AuthSession session);
  Future<void> clearSession();
  Future<String?> readAccessToken();
  Future<String?> readSetting(String key);
  Future<void> writeSetting(String key, String value);
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _sessionKey = 'voice_ledger.auth_session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clearSession();
        return null;
      }
      return AuthSession.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> saveSession(AuthSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clearSession() => _storage.delete(key: _sessionKey);

  @override
  Future<String?> readAccessToken() async {
    final session = await readSession();
    return session?.accessToken;
  }

  @override
  Future<String?> readSetting(String key) => _storage.read(key: key);

  @override
  Future<void> writeSetting(String key, String value) =>
      _storage.write(key: key, value: value);
}
