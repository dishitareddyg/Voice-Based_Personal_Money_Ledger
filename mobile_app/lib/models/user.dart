import 'json_utils.dart';

class User {
  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    this.timezone = 'Asia/Kolkata',
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;
  final String timezone;

  bool get isAdmin => role.toLowerCase() == 'admin';

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? fullName : parts.first;
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: parseString(json['id'] ?? json['user_id']),
      fullName: parseString(
        json['full_name'] ?? json['fullName'] ?? json['name'],
        fallback: 'Ledger user',
      ),
      email: parseString(json['email']),
      role: parseString(json['role'], fallback: 'user'),
      createdAt: parseRequiredDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
      timezone: parseString(
        json['timezone'],
        fallback: 'Asia/Kolkata',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
        'created_at': createdAt.toUtc().toIso8601String(),
        'timezone': timezone,
      };
}
