import '../../../router/routes.dart';
import 'voice_command.dart';

/// Where a read-only voice question should take the user.
class VoiceQueryTarget {
  const VoiceQueryTarget({
    required this.route,
    required this.label,
    required this.message,
  });

  final String route;
  final String label;
  final String message;
}

/// Maps a query intent to one of the existing ledger screens. Returns null for
/// create intents so the caller keeps the normal review flow.
VoiceQueryTarget? resolveVoiceQuery(VoiceIntent intent) {
  switch (intent) {
    case VoiceIntent.queryBalance:
      return const VoiceQueryTarget(
        route: Routes.dashboard,
        label: 'dashboard',
        message: 'Opening your dashboard balance.',
      );
    case VoiceIntent.queryExpenses:
      return const VoiceQueryTarget(
        route: Routes.expenses,
        label: 'expenses',
        message: 'Opening your expenses.',
      );
    case VoiceIntent.queryIncome:
      return const VoiceQueryTarget(
        route: Routes.income,
        label: 'income',
        message: 'Opening your income.',
      );
    case VoiceIntent.queryLoans:
      return const VoiceQueryTarget(
        route: Routes.lending,
        label: 'loans',
        message: 'Opening your loans.',
      );
    case VoiceIntent.queryTransactions:
      return const VoiceQueryTarget(
        route: Routes.transactions,
        label: 'transactions',
        message: 'Opening your transactions.',
      );
    case VoiceIntent.createExpense:
    case VoiceIntent.createIncome:
    case VoiceIntent.createSavings:
    case VoiceIntent.createLending:
    case VoiceIntent.createBorrowing:
    case VoiceIntent.createRepayment:
    case VoiceIntent.unknown:
      return null;
  }
}
