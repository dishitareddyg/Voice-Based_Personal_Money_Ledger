import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/infrastructure_providers.dart';
import '../../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final config = ref.watch(appConfigProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 60),
            children: [
              const SectionHeader(title: 'Appearance'),
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_rounded),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_rounded),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_rounded),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) =>
                          notifier.setThemeMode(selection.first),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Privacy'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SwitchListTile(
                  value: settings.hideBalances,
                  onChanged: notifier.setHideBalances,
                  title: const Text('Hide balances'),
                  subtitle: const Text(
                    'Mask amounts on screen for privacy in public',
                  ),
                  secondary: const Icon(Icons.visibility_off_rounded),
                ),
              ),
              const SectionHeader(title: 'Voice'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: settings.showVoiceExamples,
                      onChanged: notifier.setShowVoiceExamples,
                      title: const Text('Show example phrases'),
                      subtitle: const Text(
                        'Display sample sentences on the voice screen',
                      ),
                      secondary: const Icon(Icons.tips_and_updates_rounded),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.hapticsEnabled,
                      onChanged: notifier.setHapticsEnabled,
                      title: const Text('Haptic feedback'),
                      subtitle: const Text(
                        'Vibrate when listening starts and stops',
                      ),
                      secondary: const Icon(Icons.vibration_rounded),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Reminders'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SwitchListTile(
                  value: settings.repaymentReminders,
                  onChanged: notifier.setRepaymentReminders,
                  title: const Text('Repayment reminders'),
                  subtitle: const Text(
                    'Highlight loans that are due or overdue',
                  ),
                  secondary: const Icon(Icons.notifications_active_rounded),
                ),
              ),
              const SectionHeader(title: 'Account'),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: const Text('Signed in as'),
                      subtitle: Text(user?.email ?? 'Unknown'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: const Text('Raspberry Pi server'),
                      subtitle: Text(config.apiBaseUrl),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Environment'),
                      subtitle: Text(
                        '${AppConfig.appName} • ${config.environment}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Balances, currency conversion and loan outstanding are always '
                        'recalculated on your Raspberry Pi. This app only displays what the '
                        'server confirms.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Sign out?',
                      message: 'You will need to sign in again.',
                      confirmLabel: 'Sign out',
                      destructive: true,
                    );
                    if (confirmed) {
                      await ref.read(authControllerProvider.notifier).logout();
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
