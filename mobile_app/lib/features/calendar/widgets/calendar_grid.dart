import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/transaction_visuals.dart';
import '../../../models/calendar_month.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.data,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDay;
  final CalendarMonth? data;
  final ValueChanged<DateTime> onDaySelected;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstOfMonth.weekday - 1;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: _weekdays
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: .86,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final dayNumber = index - leading + 1;
            final date = DateTime(month.year, month.month, dayNumber);
            final isSelected = AppDateFormatter.isSameDay(date, selectedDay);
            final isToday = AppDateFormatter.isSameDay(date, today);
            final dayData = data?.dayFor(date);
            final types = dayData?.activeTypes ?? const {};

            return _DayCell(
              day: dayNumber,
              isSelected: isSelected,
              isToday: isToday,
              types: types,
              onTap: () => onDaySelected(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.types,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final Set<dynamic> types;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isSelected
        ? scheme.primary
        : isToday
            ? scheme.primaryContainer.withValues(alpha: .5)
            : scheme.surfaceContainerLowest;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight:
                        isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: types.take(3).map((type) {
                  final color = TransactionVisuals.color(context, type);
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.onPrimary.withValues(alpha: .85)
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
  }
}
