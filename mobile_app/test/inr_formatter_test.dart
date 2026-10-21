import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/core/utils/inr_formatter.dart';

void main() {
  group('InrFormatter.format', () {
    test('formats rupees with Indian grouping and two decimals', () {
      expect(InrFormatter.format(2000), '₹2,000.00');
      expect(InrFormatter.format(150000), '₹1,50,000.00');
      expect(InrFormatter.format(1500.5), '₹1,500.50');
    });
  });

  group('InrFormatter.formatOriginal', () {
    test('keeps INR formatting', () {
      expect(InrFormatter.formatOriginal(500, 'INR'), '₹500.00');
    });

    test('uses a currency symbol for foreign amounts', () {
      expect(InrFormatter.formatOriginal(200, 'USD'), contains('200'));
      expect(InrFormatter.formatOriginal(200, 'USD'), contains(r'$'));
    });
  });

  group('InrFormatter.tryParse', () {
    test('parses plain and grouped numbers', () {
      expect(InrFormatter.tryParse('2000'), 2000);
      expect(InrFormatter.tryParse('2,000'), 2000);
      expect(InrFormatter.tryParse('₹1,500.50'), 1500.50);
    });

    test('understands Indian units', () {
      expect(InrFormatter.tryParse('2k'), 2000);
      expect(InrFormatter.tryParse('1.5 lakh'), 150000);
      expect(InrFormatter.tryParse('2 crore'), 20000000);
    });

    test('rejects invalid and non-positive input', () {
      expect(InrFormatter.tryParse(''), isNull);
      expect(InrFormatter.tryParse('0'), isNull);
      expect(InrFormatter.tryParse('abc'), isNull);
    });
  });
}
