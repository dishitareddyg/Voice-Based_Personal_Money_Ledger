import 'package:flutter/material.dart';

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PageBottomSpacing extends StatelessWidget {
  const PageBottomSpacing({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
