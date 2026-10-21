import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/inr_formatter.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../models/repayment.dart';
import '../../../models/transaction_type.dart';
import '../../../providers/ledger_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../router/routes.dart';

class RepaymentsScreen extends ConsumerWidget {
  const RepaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repaymentsAsync = ref.watch(repaymentsProvider);
    final hideBalances = ref.watch(settingsControllerProvider).hideBalances;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayments'),
        actions: [
          IconButton(
            tooltip: 'Record with voice',
            onPressed: () => context.go(Routes.voice),
            icon: const Icon(Icons.mic_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(repaymentsProvider);
          try {
            await ref.read(repaymentsProvider.future);
          } catch (_) {
            // Errors surface inline.
          }
        },
        child: repaymentsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: const [LoadingView(message: 'Loading repayments...')],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.only(top: 60),
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(repaymentsProvider),
              ),
            ],
          ),
          data: (repayments) {
            if (repayments.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 40),
                children: [
                  EmptyState(
                    icon: Icons.receipt_rounded,
                    title: 'No repayments yet',
                    message:
                        'When money is returned or repaid, say for example "Rahul returned 2000".',
                    actionLabel: 'Record with voice',
                    onAction: () => context.go(Routes.voice),
                  ),
                ],
              );
            }

            final received = repayments
                .where((r) => r.direction == RepaymentDirection.received)
                .toList();
            final paid = repayments
                .where((r) => r.direction == RepaymentDirection.paid)
                .toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
                  children: [
                    _SummaryCard(
                      received: received,
                      paid: paid,
                      hideBalances: hideBalances,
                    ),
                    if (received.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SectionHeader(
                        title: 'Money received',
                        subtitle: '${received.length} entries',
                      ),
                      _RepaymentGroup(repayments: received, hideBalances: hideBalances),
                    ],
                    if (paid.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: 'Money paid',
                        subtitle: '${paid.length} entries',
                      ),
                      _RepaymentGroup(repayments: paid, hideBalances: hideBalances),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.received,
    required this.paid,
    required this.hideBalances,
  });

  final List<Repayment> received;
  final List<Repayment> paid;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final receivedTotal =
        received.fold<double>(0, (sum, item) => sum + item.amountInr);
    final paidTotal = paid.fold<double>(0, (sum, item) => sum + item.amountInr);

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most recent ${received.length + paid.length} entries',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Total(
                  label: 'Received',
                  value: hideBalances
                      ? '₹ ••••'
                      : InrFormatter.format(receivedTotal),
                  color: context.financeColors.repayment,
                ),
              ),
              Expanded(
                child: _Total(
                  label: 'Paid',
                  value: hideBalances ? '₹ ••••' : InrFormatter.format(paidTotal),
                  color: context.financeColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Outstanding loan balances stay authoritative on the server.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

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
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _RepaymentGroup extends StatelessWidget {
  const _RepaymentGroup({required this.repayments, required this.hideBalances});

  final List<Repayment> repayments;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < repayments.length; i++) ...[
            _RepaymentTile(
              repayment: repayments[i],
              hideBalances: hideBalances,
            ),
            if (i != repayments.length - 1)
              Divider(
                height: 1,
                indent: 58,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: .5),
              ),
          ],
        ],
      ),
    );
  }
}

class _RepaymentTile extends StatelessWidget {
  const _RepaymentTile({required this.repayment, required this.hideBalances});

  final Repayment repayment;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final received = repayment.direction == RepaymentDirection.received;
    final color = received
        ? context.financeColors.repayment
        : context.financeColors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      child: Row(
        children: [
          PersonAvatar(initials: _initials(repayment.personName), size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repayment.personName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${repayment.direction.label} • '
                  '${AppDateFormatter.shortDate(repayment.paymentDate)}'
                  '${repayment.notes.isNotEmpty ? ' • ${repayment.notes}' : ''}',
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
          Text(
            hideBalances
                ? '₹ ••••'
                : '${received ? '+' : '−'}${InrFormatter.format(repayment.amountInr)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
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
