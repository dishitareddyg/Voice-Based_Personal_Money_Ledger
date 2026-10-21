import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/inr_formatter.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../../core/widgets/transaction_visuals.dart';
import '../../../models/calendar_month.dart';
import '../../../models/transaction_type.dart';
import '../../../providers/ledger_providers.dart';
import '../../../router/routes.dart';
import '../widgets/calendar_grid.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
        1,
      );
      if (_selectedDay.month != _focusedMonth.month ||
          _selectedDay.year != _focusedMonth.year) {
        _selectedDay = _focusedMonth;
      }
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarMonthProvider(_focusedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(onPressed: _goToToday, child: const Text('Today')),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(calendarMonthProvider);
          try {
            await ref.read(calendarMonthProvider(_focusedMonth).future);
          } catch (_) {}
        },
        child: calendarAsync.when(
          data: (month) => _buildContent(month),
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 140),
            children: const [LoadingView(message: 'Loading your month...')],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 80, 18, 140),
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(calendarMonthProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CalendarMonth month) {
    final dayData = month.dayFor(_selectedDay);
    final transactions = dayData?.transactions ?? const [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 150),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SurfaceCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                children: [
                  _MonthHeader(
                    month: _focusedMonth,
                    onPrevious: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                  ),
                  const SizedBox(height: 10),
                  CalendarGrid(
                    month: _focusedMonth,
                    selectedDay: _selectedDay,
                    data: month,
                    onDaySelected: (date) =>
                        setState(() => _selectedDay = date),
                  ),
                  const SizedBox(height: 12),
                  _MonthTotals(month: month),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _Legend(
                  color: TransactionVisuals.color(
                    context,
                    TransactionType.income,
                  ),
                  label: 'Income',
                ),
                _Legend(
                  color: TransactionVisuals.color(
                    context,
                    TransactionType.expense,
                  ),
                  label: 'Expense',
                ),
                _Legend(
                  color: TransactionVisuals.color(
                    context,
                    TransactionType.lending,
                  ),
                  label: 'Lending',
                ),
                _Legend(
                  color: TransactionVisuals.color(
                    context,
                    TransactionType.borrowing,
                  ),
                  label: 'Borrowing',
                ),
                _Legend(
                  color: TransactionVisuals.color(
                    context,
                    TransactionType.repayment,
                  ),
                  label: 'Repayment',
                ),
                _Legend(
                  color: TransactionVisuals.color(
                    context,
                    TransactionType.saving,
                  ),
                  label: 'Savings',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: AppDateFormatter.longDate(_selectedDay),
              subtitle: transactions.isEmpty
                  ? 'No activity recorded'
                  : '${transactions.length} transactions',
              actionLabel: 'Voice entry',
              onAction: () => context.go(Routes.voice),
            ),
            if (transactions.isEmpty)
              SurfaceCard(
                padding: const EdgeInsets.all(10),
                child: EmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Nothing on this date',
                  message:
                      'There are no income, expense, lending, borrowing, repayment or savings records for this day.',
                  actionLabel: 'Record with voice',
                  onAction: () => context.go(Routes.voice),
                  compact: true,
                ),
              )
            else
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Column(
                  children: transactions
                      .map((transaction) => TransactionTile(
                            transaction: transaction,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
        ),
        Expanded(
          child: Text(
            AppDateFormatter.monthYear(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

class _MonthTotals extends StatelessWidget {
  const _MonthTotals({required this.month});

  final CalendarMonth month;

  @override
  Widget build(BuildContext context) {
    var income = 0.0;
    var expense = 0.0;
    for (final day in month.days) {
      income += day.income;
      expense += day.expense;
    }
    final finance = context.financeColors;
    return Row(
      children: [
        Expanded(
          child: _TotalChip(
            label: 'Income',
            amount: income,
            color: finance.income,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TotalChip(
            label: 'Expenses',
            amount: expense,
            color: finance.expense,
          ),
        ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            InrFormatter.format(amount),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
