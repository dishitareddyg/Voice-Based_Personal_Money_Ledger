import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voice_ledger/features/voice/nlp/voice_nlp_parser.dart';
import 'package:voice_ledger/features/voice/presentation/transaction_review_screen.dart';
import 'package:voice_ledger/models/calendar_month.dart';
import 'package:voice_ledger/models/category.dart';
import 'package:voice_ledger/models/ledger_summary.dart';
import 'package:voice_ledger/models/loan.dart';
import 'package:voice_ledger/models/person.dart';
import 'package:voice_ledger/models/repayment.dart';
import 'package:voice_ledger/models/transaction.dart';
import 'package:voice_ledger/models/transaction_draft.dart';
import 'package:voice_ledger/models/transaction_type.dart';
import 'package:voice_ledger/providers/infrastructure_providers.dart';
import 'package:voice_ledger/providers/ledger_providers.dart';
import 'package:voice_ledger/repositories/ledger_repository.dart';
import 'package:voice_ledger/router/routes.dart';
import 'package:voice_ledger/services/speech_service.dart';

class _FakeSpeech implements SpeechRecognitionService {
  @override
  bool get isListening => false;

  @override
  Future<bool> ensureInitialized({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async =>
      true;

  @override
  Future<bool> start({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(String status) onStatus,
    required void Function(String error) onError,
    void Function(double level)? onSoundLevel,
  }) async =>
      true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class _FakeLedgerRepository implements LedgerRepository {
  TransactionDraft? lastDraft;
  bool voiceCommandUsed = false;

  @override
  Future<TransactionResult> createTransaction(TransactionDraft draft) async {
    return _result(draft);
  }

  @override
  Future<TransactionResult> createVoiceCommand(
    TransactionDraft draft, {
    void Function()? onSent,
  }) async {
    voiceCommandUsed = true;
    onSent?.call();
    return _result(draft);
  }

  TransactionResult _result(TransactionDraft draft) {
    lastDraft = draft;
    return const TransactionResult(
      id: 'tx-1',
      message: 'Transaction saved securely.',
      availableBalance: 12345.5,
      amountInr: 500,
    );
  }

  @override
  Future<LedgerSummary> fetchSummary() => throw UnimplementedError();

  @override
  Future<TransactionPage> fetchTransactions(TransactionQuery query) =>
      throw UnimplementedError();

  @override
  Future<Transaction> fetchTransaction(String id) => throw UnimplementedError();

  @override
  Future<CalendarMonth> fetchCalendar(DateTime month) =>
      throw UnimplementedError();

  @override
  Future<List<Loan>> fetchLoans(LoanKind kind) => throw UnimplementedError();

  @override
  Future<List<Repayment>> fetchRepayments({String? loanId, int limit = 50}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('review screen saves a confirmed voice command', (tester) async {
    final repository = _FakeLedgerRepository();
    const parser = VoiceNlpParser();
    final command = parser.parse('I spent 500 on food');

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              TransactionReviewScreen(command: command),
        ),
        GoRoute(
          path: Routes.dashboard,
          builder: (context, state) =>
              const Scaffold(body: Text('Dashboard placeholder')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(repository),
          speechRecognitionServiceProvider.overrideWithValue(_FakeSpeech()),
          categoriesProvider.overrideWith((ref) => const <Category>[]),
          personsProvider.overrideWith((ref) => const <Person>[]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review transaction'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);

    final confirm = find.text('Confirm & save');
    await tester.scrollUntilVisible(
      confirm,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repository.lastDraft, isNotNull);
    expect(repository.lastDraft!.type, TransactionType.expense);
    expect(repository.lastDraft!.amount, 500);
    expect(find.text('Saved securely'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard placeholder'), findsOneWidget);
  });
}
