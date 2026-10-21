import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatters.dart';
import '../../../../core/widgets/transaction_visuals.dart';
import '../../../../models/calendar_month.dart';
import '../../../../models/transaction_type.dart';

class DashboardDateStrip extends StatelessWidget {
  const DashboardDateStrip({
    super.key,
    this.month,
    this.onDayTap,
  });

  final CalendarMonth? month;
  final ValueChanged<DateTime>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => monday.add(Duration(days: index)));

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final date = days[index];
          final isToday = AppDateFormatter.isSameDay(date, today);
          final dayData = month?.dayFor(date);
          final types = dayData?.activeTypes ?? const <TransactionType>{};

          return GestureDetector(
            onTap: onDayTap == null ? null : () => onDayTap!(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 61,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isToday
                    ? scheme.primary
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isToday
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: .5),
                ),
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: .25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppDateFormatter.weekday(date).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isToday
                              ? scheme.onPrimary.withValues(alpha: .75)
                              : scheme.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: .4,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDateFormatter.day(date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isToday ? scheme.onPrimary : scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: types.take(3).map((type) {
                        final color = TransactionVisuals.color(context, type);
                        return Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? scheme.onPrimary.withValues(alpha: .9)
                                : color,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CalendarLegendDot extends StatelessWidget {
  const CalendarLegendDot({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.financeColors.neutral,
              ),
        ),
      ],
    );
  }
}
