import 'json_utils.dart';

class Person {
  const Person({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.outstandingLent = 0,
    this.outstandingBorrowed = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final double outstandingLent;
  final double outstandingBorrowed;
  final DateTime? createdAt;

  double get netOutstanding => outstandingLent - outstandingBorrowed;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: parseString(json['id'] ?? json['person_id']),
      name: parseString(json['name'], fallback: 'Unnamed person'),
      phone: json['phone'] == null ? null : parseString(json['phone']),
      email: json['email'] == null ? null : parseString(json['email']),
      notes: json['notes'] == null ? null : parseString(json['notes']),
      outstandingLent: parseDouble(
        json['outstanding_lent'] ?? json['outstandingLent'],
      ),
      outstandingBorrowed: parseDouble(
        json['outstanding_borrowed'] ?? json['outstandingBorrowed'],
      ),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone,
        if (email != null && email!.trim().isNotEmpty) 'email': email,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      };
}
