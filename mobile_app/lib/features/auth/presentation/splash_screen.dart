import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../models/auth_session.dart';
import '../../../providers/auth_provider.dart';
import '../../../router/routes.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();
    AuthSession? session;

    try {
      session = await ref
          .read(authControllerProvider.future)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      session = null;
    }

    const minimumSplash = Duration(milliseconds: 1400);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minimumSplash) {
      await Future<void>.delayed(minimumSplash - elapsed);
    }

    if (!mounted) return;
    context.go(session == null ? Routes.login : Routes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface,
                scheme.primaryContainer.withValues(alpha: .42),
                scheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: Transform.scale(
                            scale: 0.92 + value * 0.08,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: const BrandLockup(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 44,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: scheme.primary.withValues(alpha: .8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Opening your private ledger...',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
