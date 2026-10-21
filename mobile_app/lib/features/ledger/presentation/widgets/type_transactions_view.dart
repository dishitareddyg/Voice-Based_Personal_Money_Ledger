import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/inr_formatter.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/transaction_tile.dart';
import '../../../../core/widgets/transaction_visuals.dart';
import '../../../../models/ledger_summary.dart';
import '../../../../models/transaction_type.dart';
import '../../../../providers/ledger_providers.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../router/routes.dart';

class TypeTransactionsView extends ConsumerWidget {
  const TypeTransactionsView({
    super.key,
    required this.type,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.icon,
    this.statLabel,
    this.statSelector,
  });

  final TransactionType type;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;
  final String? statLabel;
  final double Function(LedgerSummary summary)? statSelector;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(typeTransactionsProvider(type));
    final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
    final hideBalances = ref.watch(settingsControllerProvider).hideBalances;
    final color = TransactionVisuals.color(context, type);

    Future<void> refresh() async {
      ref.invalidate(typeTransactionsProvider(type));
      ref.invalidate(dashboardSummaryProvider);
      try {
        await Future.wait([
          ref.read(typeTransactionsProvider(type).future),
          ref.read(dashboardSummaryProvider.future),
        ]);
      } catch (_) {
        // Errors are surfaced inside the view.
      }
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
            children: [
              if (statSelector != null && statLabel != null && summary != null)
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
                        statLabel!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: color,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hideBalances
                            ? '₹ ••••'
                            : InrFormatter.format(statSelector!(summary)),
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confirmed by your Raspberry Pi across all recorded entries.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              listAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: LoadingView(),
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(typeTransactionsProvider(type)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: EmptyState(
                        icon: icon,
                        title: emptyTitle,
                        message: emptyMessage,
                        actionLabel: 'Record with voice',
                        onAction: () => context.go(Routes.voice),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Recent ${type.label.toLowerCase()}',
                        subtitle: '${items.length} loaded',
                      ),
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              TransactionTile(
                                transaction: items[i],
                                hideAmount: hideBalances,
                              ),
                              if (i != items.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 60,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: .5),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => context.go(Routes.transactions),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('Open full history'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
