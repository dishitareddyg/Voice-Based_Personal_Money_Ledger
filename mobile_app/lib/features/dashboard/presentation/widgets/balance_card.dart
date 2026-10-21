import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/inr_formatter.dart';
import '../../../../models/ledger_summary.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.summary,
    required this.hidden,
    required this.onToggleHidden,
  });

  final LedgerSummary summary;
  final bool hidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.financeColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0B4F45),
            const Color(0xFF0E6B5C),
            scheme.tertiary.withValues(alpha: .88),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E6B5C).withValues(alpha: .28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -52,
            right: -38,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .07),
              ),
            ),
          ),
          Positioned(
            bottom: -66,
            left: 110,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Available balance',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: .78),
                            letterSpacing: .2,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleHidden,
                    tooltip: hidden ? 'Show balance' : 'Hide balance',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .12),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  hidden ? '₹ ••••••' : InrFormatter.format(summary.availableBalance),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Calculated securely on your Raspberry Pi',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: .62),
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _BalanceMiniStat(
                      label: 'Total income',
                      amount: summary.totalIncome,
                      color: finance.income,
                      hidden: hidden,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: .14),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BalanceMiniStat(
                      label: 'Total expenses',
                      amount: summary.totalExpenses,
                      color: finance.expense,
                      hidden: hidden,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMiniStat extends StatelessWidget {
  const _BalanceMiniStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.hidden,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final bool hidden;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: .7)),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .68),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            hidden ? '₹ ••••' : InrFormatter.format(amount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
