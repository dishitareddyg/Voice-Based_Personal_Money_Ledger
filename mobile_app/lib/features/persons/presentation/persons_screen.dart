import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/inr_formatter.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../models/person.dart';
import '../../../providers/infrastructure_providers.dart';
import '../../../providers/ledger_providers.dart';
import '../../../providers/settings_provider.dart';

class PersonsScreen extends ConsumerStatefulWidget {
  const PersonsScreen({super.key});

  @override
  ConsumerState<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends ConsumerState<PersonsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor({Person? person}) async {
    final nameController = TextEditingController(text: person?.name ?? '');
    final phoneController = TextEditingController(text: person?.phone ?? '');
    final emailController = TextEditingController(text: person?.email ?? '');
    final notesController = TextEditingController(text: person?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(person == null ? 'Add person' : 'Edit person'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Name',
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: phoneController,
                    label: 'Phone (optional)',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailController,
                    label: 'Email (optional)',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: notesController,
                    label: 'Notes (optional)',
                    maxLines: 2,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final repository =
                            ref.read(personRepositoryProvider);
                        if (person == null) {
                          await repository.createPerson(
                            name: nameController.text.trim(),
                            phone: phoneController.text,
                            email: emailController.text,
                            notes: notesController.text,
                          );
                        } else {
                          await repository.updatePerson(
                            Person(
                              id: person.id,
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              email: emailController.text.trim(),
                              notes: notesController.text.trim(),
                            ),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (caught) {
                        setDialogState(() {
                          saving = false;
                          error = caught.toString();
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();

    if (saved == true) {
      ref.invalidate(personsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) {
        showSuccessMessage(
          context,
          person == null ? 'Person added.' : 'Person updated.',
        );
      }
    }
  }

  Future<void> _delete(Person person) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${person.name}?',
      message:
          'This only removes the person from your directory. Existing transactions stay in your ledger.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(personRepositoryProvider).deletePerson(person.id);
      ref.invalidate(personsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) showSuccessMessage(context, 'Person removed.');
    } catch (error) {
      if (mounted) showErrorMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personsAsync = ref.watch(personsProvider);
    final hideBalances = ref.watch(settingsControllerProvider).hideBalances;

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search people',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(
                child: personsAsync.when(
                  loading: () => const LoadingView(message: 'Loading people...'),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(personsProvider),
                  ),
                  data: (persons) {
                    final filtered = _query.isEmpty
                        ? persons
                        : persons
                            .where(
                              (person) =>
                                  person.name.toLowerCase().contains(_query),
                            )
                            .toList();
                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: persons.isEmpty
                            ? 'No people yet'
                            : 'No matching people',
                        message: persons.isEmpty
                            ? 'Add the people you lend to or borrow from. You can also mention them by name in a voice entry.'
                            : 'Try another name.',
                        actionLabel: persons.isEmpty ? 'Add person' : null,
                        onAction: persons.isEmpty ? () => _openEditor() : null,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        return _PersonCard(
                          person: person,
                          hideBalances: hideBalances,
                          onEdit: () => _openEditor(person: person),
                          onDelete: () => _delete(person),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.hideBalances,
    required this.onEdit,
    required this.onDelete,
  });

  final Person person;
  final bool hideBalances;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.financeColors;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: onEdit,
      child: Column(
        children: [
          Row(
            children: [
              PersonAvatar(initials: person.initials, size: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if ((person.phone ?? '').isNotEmpty ||
                        (person.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        [person.phone, person.email]
                            .where((value) =>
                                value != null && value.trim().isNotEmpty)
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Balance(
                  label: 'To receive',
                  amount: person.outstandingLent,
                  color: finance.lending,
                  hideBalances: hideBalances,
                ),
              ),
              Expanded(
                child: _Balance(
                  label: 'To return',
                  amount: person.outstandingBorrowed,
                  color: finance.borrowing,
                  hideBalances: hideBalances,
                ),
              ),
              Expanded(
                child: _Balance(
                  label: 'Net',
                  amount: person.netOutstanding,
                  color: person.netOutstanding >= 0
                      ? finance.income
                      : finance.expense,
                  hideBalances: hideBalances,
                  signed: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.label,
    required this.amount,
    required this.color,
    required this.hideBalances,
    this.signed = false,
  });

  final String label;
  final double amount;
  final Color color;
  final bool hideBalances;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          hideBalances
              ? '₹ ••••'
              : '${signed && amount > 0 ? '+' : ''}${InrFormatter.format(amount)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}
