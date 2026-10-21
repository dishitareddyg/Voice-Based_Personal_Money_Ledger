import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../router/routes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 150),
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    PersonAvatar(initials: user?.initials ?? '?', size: 76),
                    const SizedBox(height: 14),
                    Text(
                      user?.fullName ?? 'Ledger user',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        StatusPill(
                          label:
                              '${user?.role.toUpperCase() ?? 'USER'} account',
                          icon: isAdmin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.person_rounded,
                          color: isAdmin ? scheme.tertiary : scheme.primary,
                        ),
                        if (user != null)
                          StatusPill(
                            label:
                                'Since ${AppDateFormatter.shortDate(user.createdAt)}',
                            icon: Icons.event_available_rounded,
                            color: scheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Your ledger'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.people_alt_rounded,
                      title: 'People',
                      subtitle: 'Names used for lending and borrowing',
                      onTap: () => context.push(Routes.persons),
                    ),
                    _MenuTile(
                      icon: Icons.category_rounded,
                      title: 'Categories',
                      subtitle: 'Organise how entries are grouped',
                      onTap: () => context.push(Routes.categories),
                    ),
                    _MenuTile(
                      icon: Icons.history_rounded,
                      title: 'Transaction history',
                      subtitle: 'Search and review every entry',
                      onTap: () => context.go(Routes.transactions),
                    ),
                    _MenuTile(
                      icon: Icons.tune_rounded,
                      title: 'Settings',
                      subtitle: 'Theme, privacy and voice options',
                      onTap: () => context.push(Routes.settings),
                    ),
                    if (isAdmin)
                      _MenuTile(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Administration',
                        subtitle: 'Whitelisted maintenance actions',
                        onTap: () => context.push(Routes.admin),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'About'),
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_moon_rounded, color: scheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Private by design',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Speech is recognised on your phone. Only the text you confirm is sent over HTTPS '
                      'to your Raspberry Pi. Your ledger lives in a MySQL database you control.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              AppButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.outlined,
                destructive: true,
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Sign out?',
                    message:
                        'You will need to sign in again to reach your ledger.',
                    confirmLabel: 'Sign out',
                    destructive: true,
                  );
                  if (confirmed) {
                    await ref.read(authControllerProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: scheme.primary, size: 21),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
