import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ledger_summary.dart';
import '../../../models/transaction_type.dart';
import 'widgets/type_transactions_view.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: TypeTransactionsView(
        type: TransactionType.income,
        statLabel: 'Total income',
        statSelector: (LedgerSummary summary) => summary.totalIncome,
        icon: Icons.south_west_rounded,
        emptyTitle: 'No income recorded',
        emptyMessage:
            'Add salary or other credits by voice, for example "I received salary of 40000".',
      ),
    );
  }
}
