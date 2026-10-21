import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../utils/inr_formatter.dart';

class TransactionVisuals {
  TransactionVisuals._();

  static Color color(
    BuildContext context,
    TransactionType type, {
    RepaymentDirection? direction,
  }) {
    final finance = context.financeColors;
    switch (type) {
      case TransactionType.income:
        return finance.income;
      case TransactionType.expense:
        return finance.expense;
      case TransactionType.saving:
        return finance.savings;
      case TransactionType.lending:
        return finance.lending;
      case TransactionType.borrowing:
        return finance.borrowing;
      case TransactionType.repayment:
        return direction == RepaymentDirection.paid
            ? finance.expense
            : finance.repayment;
    }
  }

  static IconData icon(TransactionType type, {RepaymentDirection? direction}) {
    switch (type) {
      case TransactionType.income:
        return Icons.south_west_rounded;
      case TransactionType.expense:
        return Icons.north_east_rounded;
      case TransactionType.saving:
        return Icons.savings_rounded;
      case TransactionType.lending:
        return Icons.call_made_rounded;
      case TransactionType.borrowing:
        return Icons.call_received_rounded;
      case TransactionType.repayment:
        return direction == RepaymentDirection.paid
            ? Icons.north_east_rounded
            : Icons.south_west_rounded;
    }
  }

  static String signedAmount(BuildContext context, Transaction transaction) {
    final prefix = transaction.isInflow ? '+' : '−';
    return '$prefix${InrFormatter.format(transaction.amountInr)}';
  }

  static Color withAlpha(Color color, double alpha) =>
      color.withValues(alpha: alpha);
}
