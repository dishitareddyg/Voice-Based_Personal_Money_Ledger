import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/features/voice/nlp/amount_parser.dart';
import 'package:voice_ledger/features/voice/nlp/date_phrase_parser.dart';
import 'package:voice_ledger/features/voice/nlp/voice_command.dart';
import 'package:voice_ledger/features/voice/nlp/voice_nlp_parser.dart';
import 'package:voice_ledger/models/transaction_type.dart';

void main() {
  group('AmountParser', () {
    test('finds a plain rupee amount', () {
      final match = AmountParser.parse('I spent 500 on food')!;
      expect(match.amount, 500);
      expect(match.currency, 'INR');
      expect(match.currencyExplicit, isFalse);
    });

    test('understands an explicit rupee word', () {
      final match = AmountParser.parse('spent 2000 rupees on rent')!;
      expect(match.amount, 2000);
      expect(match.currency, 'INR');
    });

    test('detects a foreign currency', () {
      final match = AmountParser.parse('spent 200 dollars on subscription')!;
      expect(match.amount, 200);
      expect(match.currency, 'USD');
    });

    test('applies Indian unit multipliers', () {
      final match = AmountParser.parse('lent 1.5 lakh to Rahul')!;
      expect(match.amount, 150000);
    });
  });

  group('DatePhraseParser', () {
    final now = DateTime(2026, 10, 19, 10, 0);

    test('resolves relative day words', () {
      expect(DatePhraseParser.parse('yesterday', now: now).date,
          DateTime(2026, 10, 18));
      expect(DatePhraseParser.parse('today', now: now).date,
          DateTime(2026, 10, 19));
      expect(
        DatePhraseParser.parse('yesterday', now: now).explicit,
        isTrue,
      );
    });

    test('resolves explicit day-month-year', () {
      final result = DatePhraseParser.parse('on 5 jan 2026', now: now);
      expect(result.date, DateTime(2026, 1, 5));
      expect(result.explicit, isTrue);
    });

    test('parses times of day', () {
      expect(DatePhraseParser.parseTime('at 5 pm')?.time, '17:00');
      expect(DatePhraseParser.parseTime('at 09:30')?.time, '09:30');
    });
  });

  group('VoiceNlpParser', () {
    const parser = VoiceNlpParser();
    final now = DateTime(2026, 10, 19, 10, 0);

    test('interprets an expense', () {
      final command = parser.parse('I spent 500 on food', now: now);
      expect(command.intent, VoiceIntent.createExpense);
      expect(command.amount, 500);
      expect(command.canSubmit, isTrue);
      expect(command.categoryName, 'Food & Dining');
    });

    test('interprets lending with a person', () {
      final command = parser.parse('I lent Rahul 5000', now: now);
      expect(command.intent, VoiceIntent.createLending);
      expect(command.amount, 5000);
      expect(command.personName, 'Rahul');
      expect(command.intent.transactionType, TransactionType.lending);
    });

    test('interprets borrowing with a person', () {
      final command = parser.parse('I borrowed 10000 from Rahul', now: now);
      expect(command.intent, VoiceIntent.createBorrowing);
      expect(command.amount, 10000);
      expect(command.personName, 'Rahul');
    });

    test('interprets a repayment with direction', () {
      final command = parser.parse('Rahul returned 2000', now: now);
      expect(command.intent, VoiceIntent.createRepayment);
      expect(command.amount, 2000);
      expect(command.personName, 'Rahul');
      expect(command.repaymentDirection, RepaymentDirection.received);
    });

    test('interprets income and savings', () {
      final income = parser.parse('I received salary of 40000', now: now);
      expect(income.intent, VoiceIntent.createIncome);
      expect(income.amount, 40000);

      final savings = parser.parse('I saved 5000', now: now);
      expect(savings.intent, VoiceIntent.createSavings);
      expect(savings.amount, 5000);
    });

    test('keeps a foreign currency from speech', () {
      final command =
          parser.parse('I spent 200 dollars on a subscription', now: now);
      expect(command.intent, VoiceIntent.createExpense);
      expect(command.amount, 200);
      expect(command.currency, 'USD');
    });

    test('flags empty speech', () {
      final command = parser.parse('', now: now);
      expect(command.intent, VoiceIntent.unknown);
      expect(command.canSubmit, isFalse);
    });
  });
}
