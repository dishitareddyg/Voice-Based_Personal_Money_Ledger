import 'package:flutter/material.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.gradient,
    this.borderColor,
    this.backgroundColor,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: gradient == null
          ? (backgroundColor ?? scheme.surfaceContainerLowest)
          : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: borderColor == null
          ? Border.all(color: scheme.outlineVariant.withValues(alpha: .5))
          : Border.all(color: borderColor!),
    );

    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: decoration,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
