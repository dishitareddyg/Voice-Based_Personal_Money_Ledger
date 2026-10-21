import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ledger_summary.dart';
import '../../../models/transaction_type.dart';
import 'widgets/type_transactions_view.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      body: TypeTransactionsView(
        type: TransactionType.saving,
        statLabel: 'Total savings',
        statSelector: (LedgerSummary summary) => summary.totalSavings,
        icon: Icons.savings_rounded,
        emptyTitle: 'No savings recorded',
        emptyMessage:
            'Set money aside by voice, for example "I saved 5000 towards emergency fund".',
      ),
    );
  }
}
