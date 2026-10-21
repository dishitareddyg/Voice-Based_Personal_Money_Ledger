import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 76, this.showShadow = true});

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.31),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .28),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.16),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        color: scheme.onPrimary,
        size: size * 0.48,
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.compact = false,
    this.alignment = CrossAxisAlignment.center,
  });

  final bool compact;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: compact ? 46 : 76),
        SizedBox(height: compact ? 12 : 20),
        Text(
          'Voice Ledger',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            'Your money, spoken simply.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}
