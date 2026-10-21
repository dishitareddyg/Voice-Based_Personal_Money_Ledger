import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/features/voice/nlp/voice_command.dart';
import 'package:voice_ledger/features/voice/nlp/voice_nlp_parser.dart';
import 'package:voice_ledger/models/person.dart';
import 'package:voice_ledger/models/transaction_type.dart';

void main() {
  const parser = VoiceNlpParser();
  final now = DateTime(2026, 10, 19, 10, 0);

  group('currency extraction', () {
    test('keeps euro amounts', () {
      final command = parser.parse('I paid 50 euros for lunch', now: now);
      expect(command.amount, 50);
      expect(command.currency, 'EUR');
    });

    test('keeps rupee symbol amounts explicit', () {
      final command = parser.parse('I spent ₹250 on cab', now: now);
      expect(command.amount, 250);
      expect(command.currency, 'INR');
      expect(command.explicitCurrency, isTrue);
      expect(command.categoryName, 'Transport');
    });

    test('keeps pound amounts', () {
      final command = parser.parse('I spent 30 pounds on books', now: now);
      expect(command.amount, 30);
      expect(command.currency, 'GBP');
    });
  });

  group('person extraction', () {
    test('captures a full name after "to"', () {
      final command = parser.parse('I lent 5000 to Priya Sharma', now: now);
      expect(command.personName, 'Priya Sharma');
    });

    test('captures a name after "from"', () {
      final command = parser.parse('I borrowed 2000 from Anil', now: now);
      expect(command.personName, 'Anil');
    });

    test('prefers a known person from memory', () {
      final command = parser.parse(
        'I lent 5000 to Rahul',
        knownPersons: const [Person(id: 'p1', name: 'Rahul')],
        now: now,
      );
      expect(command.personName, 'Rahul');
    });
  });

  group('category extraction', () {
    test('maps a keyword to a category', () {
      final command = parser.parse('I spent 300 on groceries', now: now);
      expect(command.categoryName, 'Groceries');
    });

    test('maps a brand to a category', () {
      final command = parser.parse('I spent 200 on swiggy', now: now);
      expect(command.categoryName, 'Food & Dining');
    });
  });

  group('incomplete and ambiguous commands', () {
    test('flags a missing amount and person', () {
      final command = parser.parse('I lent', now: now);
      expect(command.intent, VoiceIntent.createLending);
      expect(command.missingFields, contains(VoiceField.amount));
      expect(command.missingFields, contains(VoiceField.person));
      expect(command.canSubmit, isFalse);
    });

    test('flags a missing amount for an expense', () {
      final command = parser.parse('I spent on food', now: now);
      expect(command.intent, VoiceIntent.createExpense);
      expect(command.missingFields, contains(VoiceField.amount));
      expect(command.canSubmit, isFalse);
    });

    test('treats an unclear pay sentence as incomplete', () {
      final command = parser.parse('I paid Rahul', now: now);
      expect(command.intent, isNot(VoiceIntent.unknown));
      expect(command.canSubmit, isFalse);
    });
  });

  group('malformed and low confidence input', () {
    test('returns unknown for gibberish', () {
      final command = parser.parse('asdfghjkl qwerty', now: now);
      expect(command.intent, VoiceIntent.unknown);
      expect(command.confidence, 0);
      expect(command.canSubmit, isFalse);
    });

    test('does not submit a bare number', () {
      final command = parser.parse('500', now: now);
      expect(command.intent, VoiceIntent.unknown);
      expect(command.canSubmit, isFalse);
      expect(command.missingFields, contains(VoiceField.intent));
    });

    test('warns about an unusually large amount', () {
      final command =
          parser.parse('I spent 2000000000000 on rent', now: now);
      expect(command.amount, 2000000000000);
      expect(
        command.warnings.any((warning) => warning.contains('unusually large')),
        isTrue,
      );
    });
  });

  group('number words and interest', () {
    test('parses spoken number words', () {
      final command = parser.parse('I spent five hundred on tea', now: now);
      expect(command.amount, 500);
      expect(command.intent, VoiceIntent.createExpense);
    });

    test('parses an interest rate for loans', () {
      final command =
          parser.parse('I lent Rahul 5000 at 12 percent interest', now: now);
      expect(command.intent, VoiceIntent.createLending);
      expect(command.amount, 5000);
      expect(command.interestRate, 12);
      expect(command.interestType, InterestType.simple);
    });

    test('ignores an interest rate for expenses', () {
      final command =
          parser.parse('I spent 500 at 12 percent interest', now: now);
      expect(command.intent, VoiceIntent.createExpense);
      expect(command.interestRate, isNull);
    });
  });
}
