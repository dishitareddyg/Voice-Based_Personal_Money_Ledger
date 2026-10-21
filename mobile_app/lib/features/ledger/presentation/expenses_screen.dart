import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ledger_summary.dart';
import '../../../models/transaction_type.dart';
import 'widgets/type_transactions_view.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: TypeTransactionsView(
        type: TransactionType.expense,
        statLabel: 'Total expenses',
        statSelector: (LedgerSummary summary) => summary.totalExpenses,
        icon: Icons.north_east_rounded,
        emptyTitle: 'No expenses recorded',
        emptyMessage:
            'Track what you spend by voice, for example "I spent 300 on petrol".',
      ),
    );
  }
}
