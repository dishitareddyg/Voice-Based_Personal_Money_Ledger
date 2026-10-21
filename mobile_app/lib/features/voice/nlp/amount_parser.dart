import 'nlp_vocabulary.dart';

class AmountMatch {
  const AmountMatch({
    required this.amount,
    required this.currency,
    required this.currencyExplicit,
    required this.raw,
    required this.start,
    required this.end,
    this.usedNumberWords = false,
  });

  final double amount;
  final String currency;
  final bool currencyExplicit;
  final String raw;
  final int start;
  final int end;
  final bool usedNumberWords;
}

class AmountParser {
  AmountParser._();

  static final RegExp _prefixed = RegExp(
    r'(₹|\$|€|£|rs\.?|inr|usd|eur|gbp|aed|sgd|aud|cad|jpy)\s*'
    r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s*'
    r'(k|thousand|lakhs?|lakh|lacs?|lac|crore|cr)?',
    caseSensitive: false,
  );

  static final RegExp _numeric = RegExp(
    r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s*'
    r'(k|thousand|lakhs?|lakh|lacs?|lac|crore|cr)?\s*'
    r'(rupees?|rs\.?|inr|dollars?|usd|euros?|eur|pounds?|gbp|'
    r'dirhams?|aed|sgd|aud|cad|jpy|yen)?',
    caseSensitive: false,
  );

  static AmountMatch? parse(String maskedText) {
    final prefixed = _prefixed.allMatches(maskedText).toList();
    if (prefixed.isNotEmpty) {
      final match = prefixed.first;
      final result = _fromNumericMatch(
        maskedText,
        match,
        prefixCurrency: match.group(1),
        unit: match.group(3),
        number: match.group(2),
      );
      if (result != null) return result;
    }

    for (final match in _numeric.allMatches(maskedText)) {
      final following = maskedText.substring(match.end).trimLeft();
      if (following.startsWith('%') ||
          following.toLowerCase().startsWith('percent')) {
        continue;
      }
      final result = _fromNumericMatch(
        maskedText,
        match,
        suffixCurrency: match.group(3),
        unit: match.group(2),
        number: match.group(1),
      );
      if (result != null) return result;
    }

    return _parseWords(maskedText);
  }

  static AmountMatch? _fromNumericMatch(
    String text,
    RegExpMatch match, {
    String? prefixCurrency,
    String? suffixCurrency,
    String? unit,
    String? number,
  }) {
    if (number == null) return null;
    var value = double.tryParse(number.replaceAll(',', ''));
    if (value == null || !value.isFinite || value <= 0) return null;
    value *= _unitMultiplier(unit);

    final detectedCurrency = _normalizeCurrency(prefixCurrency ?? suffixCurrency);
    final globalCurrency = _detectCurrencyInText(text);
    final currency = detectedCurrency ?? globalCurrency ?? 'INR';

    return AmountMatch(
      amount: value,
      currency: currency,
      currencyExplicit:
          detectedCurrency != null || globalCurrency != null,
      raw: match.group(0)!.trim(),
      start: match.start,
      end: match.end,
    );
  }

  static double _unitMultiplier(String? unit) {
    switch (unit?.toLowerCase()) {
      case 'k':
      case 'thousand':
        return 1000;
      case 'lakh':
      case 'lakhs':
      case 'lac':
      case 'lacs':
        return 100000;
      case 'crore':
      case 'cr':
        return 10000000;
      default:
        return 1;
    }
  }

  static String? _normalizeCurrency(String? token) {
    if (token == null) return null;
    final normalized = token.toLowerCase().trim();
    return NlpVocabulary.currencyWords[normalized] ??
        NlpVocabulary.currencyWords[normalized.replaceAll('.', '')] ??
        (normalized.length == 3 ? normalized.toUpperCase() : null);
  }

  static String? _detectCurrencyInText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('₹')) return 'INR';
    if (lower.contains(r'$')) return 'USD';
    if (lower.contains('€')) return 'EUR';
    if (lower.contains('£')) return 'GBP';
    if (RegExp(r'\b(?:dollars?|usd)\b').hasMatch(lower)) return 'USD';
    if (RegExp(r'\b(?:euros?|eur)\b').hasMatch(lower)) return 'EUR';
    if (RegExp(r'\b(?:pounds?|gbp)\b').hasMatch(lower)) return 'GBP';
    if (RegExp(r'\b(?:rupees?|rs\.?|inr)\b').hasMatch(lower)) return 'INR';
    if (RegExp(r'\b(?:dirhams?|aed)\b').hasMatch(lower)) return 'AED';
    if (RegExp(r'\bsgd\b').hasMatch(lower)) return 'SGD';
    if (RegExp(r'\baud\b').hasMatch(lower)) return 'AUD';
    if (RegExp(r'\bcad\b').hasMatch(lower)) return 'CAD';
    if (RegExp(r'\b(?:jpy|yen)\b').hasMatch(lower)) return 'JPY';
    return null;
  }

  static AmountMatch? _parseWords(String text) {
    final matches = RegExp(r"[a-z]+(?:[\s-]+[a-z]+)*", caseSensitive: false)
        .allMatches(text.toLowerCase());
    for (final match in matches) {
      final tokens = match
          .group(0)!
          .split(RegExp(r'[\s-]+'))
          .where((token) => token.isNotEmpty)
          .toList();
      final numbers = <String>[];
      var total = 0.0;
      var current = 0.0;
      var sawNumber = false;

      for (final token in tokens) {
        if (token == 'and' && sawNumber) continue;
        final rawValue = NlpVocabulary.numberWords[token];
        if (rawValue == null) {
          if (sawNumber) break;
          numbers.clear();
          total = 0;
          current = 0;
          continue;
        }
        final value = double.parse(rawValue);
        sawNumber = true;
        numbers.add(token);
        if (value == 100) {
          current = (current == 0 ? 1 : current) * 100;
        } else if (value >= 1000) {
          total += (current == 0 ? 1 : current) * value;
          current = 0;
        } else {
          current += value;
        }
      }

      if (!sawNumber || total + current <= 0) {
        continue;
      }

      return AmountMatch(
        amount: total + current,
        currency: _detectCurrencyInText(text) ?? 'INR',
        currencyExplicit: _detectCurrencyInText(text) != null,
        raw: numbers.join(' '),
        start: match.start,
        end: match.start + numbers.join(' ').length,
        usedNumberWords: true,
      );
    }
    return null;
  }
}
