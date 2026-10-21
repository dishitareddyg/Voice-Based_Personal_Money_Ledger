import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (label: 'Home', icon: Icons.space_dashboard_outlined, selected: Icons.space_dashboard_rounded),
    (label: 'Calendar', icon: Icons.calendar_month_outlined, selected: Icons.calendar_month_rounded),
    (label: 'Voice', icon: Icons.mic_none_rounded, selected: Icons.mic_rounded),
    (label: 'History', icon: Icons.receipt_long_outlined, selected: Icons.receipt_long_rounded),
    (label: 'Profile', icon: Icons.person_outline_rounded, selected: Icons.person_rounded),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              final selected = navigationShell.currentIndex == index;
              if (index == 2) {
                return Expanded(
                  child: Center(
                    child: _VoiceNavButton(
                      selected: selected,
                      onTap: () => _onTap(index),
                    ),
                  ),
                );
              }
              return Expanded(
                child: _NavItem(
                  label: destination.label,
                  icon: selected ? destination.selected : destination.icon,
                  selected: selected,
                  onTap: () => _onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer.withValues(alpha: .7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceNavButton extends StatelessWidget {
  const _VoiceNavButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Voice entry',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? [scheme.tertiary, scheme.primary]
                      : [scheme.primary, scheme.primary.withValues(alpha: .8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(
                      alpha: selected ? .45 : .26,
                    ),
                    blurRadius: selected ? 18 : 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                selected ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: scheme.onPrimary,
                size: 26,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Voice',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
