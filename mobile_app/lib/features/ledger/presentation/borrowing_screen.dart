import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/transaction_type.dart';
import 'widgets/loans_view.dart';

class BorrowingScreen extends ConsumerWidget {
  const BorrowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borrowing')),
      body: const LoansView(
        kind: LoanKind.borrowed,
        icon: Icons.call_received_rounded,
        emptyTitle: 'Nothing borrowed yet',
        emptyMessage:
            'Record money you received by voice, for example "I borrowed 10000 from Rahul".',
      ),
    );
  }
}
