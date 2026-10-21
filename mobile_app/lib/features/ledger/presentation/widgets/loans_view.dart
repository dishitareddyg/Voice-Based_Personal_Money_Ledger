import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatters.dart';
import '../../../../core/utils/inr_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../models/loan.dart';
import '../../../../models/transaction_type.dart';
import '../../../../providers/ledger_providers.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../router/routes.dart';

class LoansView extends ConsumerWidget {
  const LoansView({
    super.key,
    required this.kind,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
  });

  final LoanKind kind;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider(kind));
    final hideBalances = ref.watch(settingsControllerProvider).hideBalances;
    final color = kind == LoanKind.lent
        ? context.financeColors.lending
        : context.financeColors.borrowing;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(loansProvider(kind));
        try {
          await ref.read(loansProvider(kind).future);
        } catch (_) {
          // Errors surface inline.
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: loansAsync.when(
            loading: () => ListView(
              padding: const EdgeInsets.only(top: 60),
              children: const [LoadingView(message: 'Loading loans...')],
            ),
            error: (error, _) => ListView(
              padding: const EdgeInsets.only(top: 60),
              children: [
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(loansProvider(kind)),
                ),
              ],
            ),
            data: (loans) {
              if (loans.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 40),
                  children: [
                    EmptyState(
                      icon: icon,
                      title: emptyTitle,
                      message: emptyMessage,
                      actionLabel: 'Record with voice',
                      onAction: () => context.go(Routes.voice),
                    ),
                  ],
                );
              }

              final active = loans.where((loan) => loan.isOpen).toList();
              final totalOutstanding = active.fold<double>(
                0,
                (sum, loan) => sum + loan.outstandingAmountInr,
              );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
                children: [
                  SurfaceCard(
                    padding: const EdgeInsets.all(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: .16),
                        color.withValues(alpha: .05),
                      ],
                    ),
                    borderColor: color.withValues(alpha: .25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind == LoanKind.lent
                              ? 'Outstanding to receive'
                              : 'Outstanding to return',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: color,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hideBalances
                              ? '₹ ••••'
                              : InrFormatter.format(totalOutstanding),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${active.length} open ${active.length == 1 ? 'loan' : 'loans'} • running totals are recalculated by the server',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SectionHeader(
                    title: 'All ${kind.label.toLowerCase()} loans',
                    subtitle: '${loans.length} total',
                  ),
                  for (final loan in loans) ...[
                    _LoanCard(
                      loan: loan,
                      hideBalances: hideBalances,
                      onRecordRepayment: () => context.go(Routes.voice),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(Routes.repayments),
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: const Text('View repayment history'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.hideBalances,
    required this.onRecordRepayment,
  });

  final Loan loan;
  final bool hideBalances;
  final VoidCallback onRecordRepayment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = loan.kind == LoanKind.lent
        ? context.financeColors.lending
        : context.financeColors.borrowing;
    final statusColor = !loan.isOpen
        ? context.financeColors.neutral
        : loan.isOverdue
            ? scheme.error
            : color;
    final statusLabel = !loan.isOpen
        ? 'Closed'
        : loan.isOverdue
            ? 'Overdue'
            : 'Open';

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(initials: _initials(loan.personName), size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.personName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${loan.kind.label} • since ${AppDateFormatter.shortDate(loan.startDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: statusLabel, color: statusColor, compact: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Principal',
                  value: hideBalances
                      ? '₹ ••••'
                      : InrFormatter.format(loan.principalAmountInr),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Outstanding',
                  value: hideBalances
                      ? '₹ ••••'
                      : InrFormatter.format(loan.outstandingAmountInr),
                  valueColor: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: loan.progress,
              minHeight: 7,
              backgroundColor: scheme.surfaceContainer,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(loan.progress * 100).round()}% repaid'
            '${loan.dueDate != null ? ' • due ${AppDateFormatter.shortDate(loan.dueDate!)}' : ''}'
            '${loan.interestRate > 0 ? ' • ${loan.interestRate.toStringAsFixed(loan.interestRate % 1 == 0 ? 0 : 2)}% ${loan.interestType.label.toLowerCase()}' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRecordRepayment,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Record repayment'),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
