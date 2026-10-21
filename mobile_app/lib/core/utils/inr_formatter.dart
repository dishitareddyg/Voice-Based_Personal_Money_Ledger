import 'package:intl/intl.dart';

/// Formats money for display only. No financial calculation in the app is
/// authoritative; the Raspberry Pi backend recalculates every balance.
class InrFormatter {
  InrFormatter._();

  static final NumberFormat _full = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _plain = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String format(num value) => _full.format(value);

  static String formatPlain(num value) => _plain.format(value).trim();

  static String compact(num value) => _compact.format(value);

  static String formatOriginal(num value, String currency) {
    final normalized = currency.toUpperCase();
    if (normalized == 'INR') return format(value);
    try {
      return NumberFormat.simpleCurrency(
        locale: 'en_IN',
        name: normalized,
        decimalDigits: 2,
      ).format(value);
    } catch (_) {
      return '${_currencySymbol(normalized)}${formatPlain(value)}';
    }
  }

  static String _currencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'AED ';
      case 'SGD':
        return 'S\$';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'JPY':
        return '¥';
      default:
        return '$currency ';
    }
  }

  /// Parses user input such as `2,000`, `₹1,500.50` or `1.5L`.
  /// Returns null for invalid or non-positive amounts.
  static double? tryParse(String input) {
    final cleaned = input
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('rs.', '', )
        .replaceAll('rs', '')
        .replaceAll('inr', '')
        .trim()
        .toLowerCase();

    if (cleaned.isEmpty) return null;

    var multiplier = 1.0;
    var numberPart = cleaned;
    if (cleaned.endsWith('lakh') || cleaned.endsWith('lac')) {
      multiplier = 100000;
      numberPart = cleaned.replaceAll(RegExp(r'lakh|lac'), '').trim();
    } else if (cleaned.endsWith('crore') || cleaned.endsWith('cr')) {
      multiplier = 10000000;
      numberPart = cleaned.replaceAll(RegExp(r'crore|cr'), '').trim();
    } else if (cleaned.endsWith('k')) {
      multiplier = 1000;
      numberPart = cleaned.substring(0, cleaned.length - 1).trim();
    }

    final value = double.tryParse(numberPart);
    if (value == null || !value.isFinite || value <= 0) return null;
    final result = value * multiplier;
    if (result <= 0) return null;
    return result;
  }
}
