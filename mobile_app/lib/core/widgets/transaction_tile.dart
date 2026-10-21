import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatters.dart';
import '../utils/inr_formatter.dart';
import 'transaction_visuals.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.hideAmount = false,
    this.showDate = true,
    this.compact = false,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final bool hideAmount;
  final bool showDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = TransactionVisuals.color(
      context,
      transaction.type,
      direction: transaction.repaymentDirection,
    );
    final subtitleParts = <String>[
      transaction.type.label,
      if (transaction.personName != null &&
          transaction.personName!.trim().isNotEmpty)
        transaction.personName!,
      if (transaction.categoryName != null &&
          transaction.categoryName!.trim().isNotEmpty)
        transaction.categoryName!,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: compact ? 9 : 11,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 42 : 46,
              height: compact ? 42 : 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                TransactionVisuals.icon(
                  transaction.type,
                  direction: transaction.repaymentDirection,
                ),
                color: color,
                size: compact ? 20 : 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (showDate) AppDateFormatter.shortDate(
                        transaction.transactionDate,
                      ),
                      ...subtitleParts,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hideAmount
                      ? '₹ ••••'
                      : '${transaction.isInflow ? '+' : '−'}${InrFormatter.format(transaction.amountInr)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: transaction.isInflow
                            ? context.financeColors.income
                            : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (transaction.hasConversion) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${transaction.originalCurrency} '
                    '${transaction.originalAmount?.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
