import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: resolved.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: resolved),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (compact
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.labelMedium)
                ?.copyWith(
              color: resolved,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
