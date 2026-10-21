import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/transaction_type.dart';
import 'widgets/loans_view.dart';

class LendingScreen extends ConsumerWidget {
  const LendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lending')),
      body: const LoansView(
        kind: LoanKind.lent,
        icon: Icons.call_made_rounded,
        emptyTitle: 'Nothing lent yet',
        emptyMessage:
            'Record money you gave by voice, for example "I lent Rahul 5000".',
      ),
    );
  }
}
