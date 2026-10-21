import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/features/voice/nlp/voice_command.dart';
import 'package:voice_ledger/features/voice/nlp/voice_query_router.dart';
import 'package:voice_ledger/router/routes.dart';

void main() {
  test('maps every query intent to an existing screen', () {
    expect(resolveVoiceQuery(VoiceIntent.queryBalance)?.route, Routes.dashboard);
    expect(resolveVoiceQuery(VoiceIntent.queryExpenses)?.route, Routes.expenses);
    expect(resolveVoiceQuery(VoiceIntent.queryIncome)?.route, Routes.income);
    expect(resolveVoiceQuery(VoiceIntent.queryLoans)?.route, Routes.lending);
    expect(
      resolveVoiceQuery(VoiceIntent.queryTransactions)?.route,
      Routes.transactions,
    );
  });

  test('returns null for create and unknown intents', () {
    const intents = [
      VoiceIntent.createExpense,
      VoiceIntent.createIncome,
      VoiceIntent.createSavings,
      VoiceIntent.createLending,
      VoiceIntent.createBorrowing,
      VoiceIntent.createRepayment,
      VoiceIntent.unknown,
    ];
    for (final intent in intents) {
      expect(resolveVoiceQuery(intent), isNull, reason: intent.name);
    }
  });
}
