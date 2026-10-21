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
import '../../../core/widgets/transaction_tile.dart';
import '../../../models/calendar_month.dart';
import '../../../models/category.dart';
import '../../../models/ledger_summary.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/ledger_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../router/routes.dart';
import 'widgets/balance_card.dart';
import 'widgets/dashboard_date_strip.dart';
import 'widgets/metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardCalendarProvider);
    try {
      await Future.wait([
        ref.read(dashboardSummaryProvider.future),
        ref.read(dashboardCalendarProvider.future),
      ]);
    } catch (_) {
      // Error surfaces through the providers.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final calendar = ref.watch(dashboardCalendarProvider).valueOrNull;
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppDateFormatter.greeting(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              user?.firstName ?? 'Your ledger',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.tune_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => context.go(Routes.profile),
              child: PersonAvatar(
                initials: user?.initials ?? '?',
                size: 40,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: summaryAsync.when(
          data: (summary) => _DashboardBody(
            summary: summary,
            calendar: calendar,
            hidden: settings.hideBalances,
            onToggleHidden: () => ref
                .read(settingsControllerProvider.notifier)
                .setHideBalances(!settings.hideBalances),
          ),
          loading: () => const _DashboardSkeleton(),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 90, 18, 140),
            children: [
              ErrorView(
                error: error,
                onRetry: () {
                  ref.invalidate(dashboardSummaryProvider);
                  ref.invalidate(dashboardCalendarProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.summary,
    required this.calendar,
    required this.hidden,
    required this.onToggleHidden,
  });

  final LedgerSummary summary;
  final CalendarMonth? calendar;
  final bool hidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 150),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            BalanceCard(
              summary: summary,
              hidden: hidden,
              onToggleHidden: onToggleHidden,
            ),
            const SizedBox(height: 20),
            const _QuickActionsRow(),
            const SizedBox(height: 18),
            const _VoiceCallToAction(),
            const SizedBox(height: 22),
            _StatsGrid(summary: summary, hidden: hidden),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'This week',
              actionLabel: 'Calendar',
              onAction: () => context.go(Routes.calendar),
            ),
            DashboardDateStrip(
              month: calendar,
              onDayTap: (_) => context.go(Routes.calendar),
            ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Spending by category',
              actionLabel: 'Categories',
              onAction: () => context.push(Routes.categories),
            ),
            _CategoryBreakdown(items: summary.categoryBreakdown),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Upcoming repayments',
              actionLabel: 'Manage',
              onAction: () => context.push(Routes.repayments),
            ),
            _UpcomingRepaymentsCard(
              repayments: summary.upcomingRepayments,
            ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Notes & reminders',
              actionLabel: 'Settings',
              onAction: () => context.push(Routes.settings),
            ),
            _NotesCard(notes: summary.notes),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Recent transactions',
              actionLabel: 'View all',
              onAction: () => context.go(Routes.transactions),
            ),
            _RecentTransactions(
              transactions: summary.recentTransactions,
              hidden: hidden,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  static const _actions = [
    (label: 'Expense', icon: Icons.north_east_rounded, route: Routes.expenses),
    (label: 'Income', icon: Icons.south_west_rounded, route: Routes.income),
    (label: 'Savings', icon: Icons.savings_rounded, route: Routes.savings),
    (label: 'Lend', icon: Icons.call_made_rounded, route: Routes.lending),
    (label: 'Borrow', icon: Icons.call_received_rounded, route: Routes.borrowing),
    (label: 'Repay', icon: Icons.sync_alt_rounded, route: Routes.repayments),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = _actions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push(action.route),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  child: Icon(action.icon, color: scheme.primary, size: 23),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VoiceCallToAction extends StatelessWidget {
  const _VoiceCallToAction();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      onTap: () => context.go(Routes.voice),
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer.withValues(alpha: .85),
          scheme.tertiaryContainer.withValues(alpha: .7),
        ],
      ),
      borderColor: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Just say it',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '“I spent 2,000 rupees on groceries yesterday”',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Review before saving',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .3),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              Icons.mic_rounded,
              color: scheme.onPrimary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary, required this.hidden});

  final LedgerSummary summary;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final finance = context.financeColors;
    final cards = [
      MetricCard(
        label: 'Total income',
        amount: summary.totalIncome,
        icon: Icons.south_west_rounded,
        color: finance.income,
        hidden: hidden,
        onTap: () => context.push(Routes.income),
      ),
      MetricCard(
        label: 'Total expenses',
        amount: summary.totalExpenses,
        icon: Icons.north_east_rounded,
        color: finance.expense,
        hidden: hidden,
        onTap: () => context.push(Routes.expenses),
      ),
      MetricCard(
        label: 'Total savings',
        amount: summary.totalSavings,
        icon: Icons.savings_rounded,
        color: finance.savings,
        hidden: hidden,
        onTap: () => context.push(Routes.savings),
      ),
      MetricCard(
        label: 'Money lent',
        amount: summary.moneyLent,
        subtitle: 'Outstanding ${InrFormatter.compact(summary.outstandingLent)}',
        icon: Icons.call_made_rounded,
        color: finance.lending,
        hidden: hidden,
        onTap: () => context.push(Routes.lending),
      ),
      MetricCard(
        label: 'Money borrowed',
        amount: summary.moneyBorrowed,
        subtitle:
            'Outstanding ${InrFormatter.compact(summary.outstandingBorrowed)}',
        icon: Icons.call_received_rounded,
        color: finance.borrowing,
        hidden: hidden,
        onTap: () => context.push(Routes.borrowing),
      ),
      MetricCard(
        label: 'Upcoming repayments',
        amount: summary.upcomingRepaymentTotal,
        subtitle: '${summary.upcomingRepaymentCount} scheduled',
        icon: Icons.event_repeat_rounded,
        color: finance.repayment,
        hidden: hidden,
        onTap: () => context.push(Routes.repayments),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 1 : 2;
        final spacing = 12.0;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.items});

  final List<CategoryBreakdown> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Category totals will appear here after you record expenses, income or savings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: items.take(5).map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                CategoryIcon(
                  name: item.name,
                  iconKey: item.iconKey,
                  colorHex: item.colorHex,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            InrFormatter.format(item.amount),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (item.percentage / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              scheme.outlineVariant.withValues(alpha: .35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UpcomingRepaymentsCard extends StatelessWidget {
  const _UpcomingRepaymentsCard({required this.repayments});

  final List<UpcomingRepayment> repayments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.financeColors;
    if (repayments.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          'No upcoming repayments are recorded. Loans and their due dates will show up here.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        children: repayments.take(4).map((repayment) {
          final color =
              repayment.isReceivable ? finance.income : finance.borrowing;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                repayment.isReceivable
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: color,
                size: 21,
              ),
            ),
            title: Text(
              repayment.personName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${repayment.isReceivable ? 'Receivable' : 'Payable'} • due '
              '${AppDateFormatter.shortDate(repayment.dueDate)}',
            ),
            trailing: Text(
              InrFormatter.format(repayment.amount),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final List<LedgerNote> notes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (notes.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notes and reminders you add will appear here.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notes.take(3).map((note) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  note.pinned
                      ? Icons.push_pin_rounded
                      : Icons.sticky_note_2_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        note.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.transactions,
    required this.hidden,
  });

  final List<Transaction> transactions;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: EmptyState(
          icon: Icons.mic_none_rounded,
          title: 'No transactions yet',
          message:
              'Tap the microphone and say something like “I spent 500 on food”.',
          actionLabel: 'Record with voice',
          onAction: () => context.go(Routes.voice),
          compact: true,
        ),
      );
    }
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        children: transactions
            .take(6)
            .map(
              (transaction) => TransactionTile(
                transaction: transaction,
                hideAmount: hidden,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget block(double height, {double radius = 22}) => Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 150),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        block(196, radius: 28),
        const SizedBox(height: 20),
        block(84, radius: 18),
        const SizedBox(height: 18),
        block(104, radius: 22),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: block(132)),
            const SizedBox(width: 12),
            Expanded(child: block(132)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: block(132)),
            const SizedBox(width: 12),
            Expanded(child: block(132)),
          ],
        ),
      ],
    );
  }
}
