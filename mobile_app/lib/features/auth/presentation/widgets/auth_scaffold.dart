import 'package:flutter/material.dart';

import '../../../../core/widgets/app_logo.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surfaceContainerLow,
              scheme.primaryContainer.withValues(alpha: .26),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -80,
              child: _Orb(
                size: 260,
                color: scheme.tertiary.withValues(alpha: .13),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -90,
              child: _Orb(
                size: 300,
                color: scheme.primary.withValues(alpha: .1),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 26,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 52,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 450),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const BrandLockup(),
                              const SizedBox(height: 30),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  24,
                                  22,
                                  22,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: .5),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: .06),
                                      blurRadius: 30,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 22),
                                    child,
                                  ],
                                ),
                              ),
                              if (footer != null) ...[
                                const SizedBox(height: 16),
                                footer!,
                              ],
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Secured by HTTPS • hosted on your Raspberry Pi',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
