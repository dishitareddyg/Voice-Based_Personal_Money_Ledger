import 'inr_formatter.dart';

class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) return 'Include a letter';
    if (!RegExp(r'\d').hasMatch(text)) return 'Include a number';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Full name is required';
    if (text.length < 2) return 'Enter at least 2 characters';
    if (text.length > 100) return 'Name is too long';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final parsed = InrFormatter.tryParse(value);
    if (parsed == null) return 'Enter a valid amount greater than zero';
    if (parsed > 9999999999999) return 'Amount is too large';
    return null;
  }

  static String? interestRate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final rate = double.tryParse(value.trim());
    if (rate == null) return 'Enter a valid percentage';
    if (rate < 0 || rate > 100) return 'Rate must be between 0 and 100';
    return null;
  }

  static String? simpleEmailOrNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return email(value);
  }
}
