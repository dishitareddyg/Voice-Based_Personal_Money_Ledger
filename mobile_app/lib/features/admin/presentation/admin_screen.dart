import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../models/admin_action.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/infrastructure_providers.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  AdminAction? _running;

  IconData _icon(String key) {
    switch (key) {
      case 'database':
        return Icons.storage_rounded;
      case 'migration':
        return Icons.schema_rounded;
      case 'backup':
        return Icons.backup_rounded;
      case 'tune':
        return Icons.tune_rounded;
      case 'delete_sweep':
        return Icons.delete_sweep_rounded;
      default:
        return Icons.settings_rounded;
    }
  }

  Future<void> _run(AdminAction action) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.description),
            const SizedBox(height: 16),
            AppTextField(
              controller: passwordController,
              label: 'Confirm your password',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Commands are whitelisted on the server. No raw SQL is ever sent.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: action.isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action.isDestructive ? 'Run anyway' : 'Run'),
          ),
        ],
      ),
    );

    final password = passwordController.text;
    passwordController.dispose();

    if (confirmed != true) return;
    if (password.isEmpty) {
      if (mounted) showErrorMessage(context, 'Password is required.');
      return;
    }

    setState(() => _running = action);
    try {
      final result = await ref.read(adminRepositoryProvider).runAction(
            action,
            password: password,
          );
      if (!mounted) return;
      setState(() => _running = null);
      showSuccessMessage(context, result.message);
      await _showResult(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _running = null);
      showErrorMessage(context, error);
    }
  }

  Future<void> _showResult(AdminActionResult result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: context.financeColors.income,
          size: 38,
        ),
        title: const Text('Action completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            const SizedBox(height: 12),
            Text(
              'Completed ${AppDateFormatter.dateTime(result.completedAt)}',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (result.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final entry in result.details.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${entry.value}',
                          textAlign: TextAlign.right,
                          style: Theme.of(dialogContext)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Administrators only',
          message:
              'This area is limited to administrator accounts on your Raspberry Pi.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 60),
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Only the actions listed below can be run. Each one is '
                        're-validated on the server and requires your password.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Maintenance actions'),
              for (final action in AdminAction.values) ...[
                _ActionCard(
                  action: action,
                  icon: _icon(action.icon),
                  running: _running == action,
                  disabled: _running != null,
                  onRun: () => _run(action),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.icon,
    required this.running,
    required this.disabled,
    required this.onRun,
  });

  final AdminAction action;
  final IconData icon;
  final bool running;
  final bool disabled;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = action.isDestructive ? scheme.error : scheme.primary;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.command,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    label: action.isDestructive ? 'Run anyway' : 'Run action',
                    icon: Icons.play_arrow_rounded,
                    loading: running,
                    expand: false,
                    destructive: action.isDestructive,
                    variant: action.isDestructive
                        ? AppButtonVariant.outlined
                        : AppButtonVariant.filled,
                    onPressed: disabled ? null : onRun,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
