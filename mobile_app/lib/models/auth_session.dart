import 'json_utils.dart';
import 'user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final User user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final nestedUser = parseMap(json['user']);
    final tokens = parseMap(json['tokens']);

    final token = parseString(
      json['access_token'] ??
          json['accessToken'] ??
          json['token'] ??
          tokens?['access_token'] ??
          tokens?['token'],
    );
    final refresh = parseString(
      json['refresh_token'] ??
          json['refreshToken'] ??
          tokens?['refresh_token'] ??
          tokens?['refreshToken'],
      fallback: '',
    );

    final rawUser = nestedUser ?? json;
    if (token.isEmpty || rawUser['email'] == null) {
      throw const FormatException('Invalid authentication response');
    }

    return AuthSession(
      accessToken: token,
      refreshToken: refresh.isEmpty ? null : refresh,
      user: User.fromJson(rawUser),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user': user.toJson(),
      };
}

class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    this.timezone = 'Asia/Kolkata',
  });

  final String fullName;
  final String email;
  final String password;
  final String timezone;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'password': password,
        'timezone': timezone,
      };
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}
