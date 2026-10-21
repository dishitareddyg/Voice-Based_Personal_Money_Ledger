import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/features/voice/nlp/voice_command.dart';
import 'package:voice_ledger/features/voice/nlp/voice_nlp_parser.dart';

void main() {
  const parser = VoiceNlpParser();
  final now = DateTime(2026, 10, 19, 10, 0);

  group('VoiceNlpParser query intents', () {
    test('understands a balance question', () {
      final command = parser.parse('What is my balance?', now: now);
      expect(command.intent, VoiceIntent.queryBalance);
      expect(command.intent.isQuery, isTrue);
      expect(command.intent.transactionType, isNull);
      expect(command.missingFields, isEmpty);
      expect(command.canSubmit, isTrue);
      expect(command.confidence, greaterThanOrEqualTo(0.85));
    });

    test('understands an expense total question', () {
      final command =
          parser.parse('How much did I spend this month?', now: now);
      expect(command.intent, VoiceIntent.queryExpenses);
      expect(command.canSubmit, isTrue);
    });

    test('understands an income total question', () {
      final command = parser.parse('How much did I earn last month?', now: now);
      expect(command.intent, VoiceIntent.queryIncome);
      expect(command.canSubmit, isTrue);
    });

    test('understands a loan question', () {
      final command = parser.parse('Who owes me money?', now: now);
      expect(command.intent, VoiceIntent.queryLoans);
      expect(command.intent.requiresAmount, isFalse);
      expect(command.canSubmit, isTrue);
    });

    test('understands a transaction listing question', () {
      final command = parser.parse('Show my recent transactions', now: now);
      expect(command.intent, VoiceIntent.queryTransactions);
      expect(command.canSubmit, isTrue);
    });

    test('does not treat create sentences as queries', () {
      expect(parser.parse('I spent 500 on food', now: now).intent,
          VoiceIntent.createExpense);
      expect(parser.parse('I received salary of 40000', now: now).intent,
          VoiceIntent.createIncome);
    });
  });

  group('VoiceIntent required fields', () {
    test('queries never require an amount', () {
      for (final intent in VoiceIntent.values.where((i) => i.isQuery)) {
        expect(intent.requiresAmount, isFalse, reason: intent.name);
      }
    });

    test('create intents require an amount', () {
      for (final intent in VoiceIntent.values.where((i) => !i.isQuery)) {
        if (intent == VoiceIntent.unknown) continue;
        expect(intent.requiresAmount, isTrue, reason: intent.name);
      }
    });
  });
}
