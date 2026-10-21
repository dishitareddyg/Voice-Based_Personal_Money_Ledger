import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/inr_formatter.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/transaction_visuals.dart';
import '../../../models/category.dart';
import '../../../models/transaction_type.dart';
import '../../../providers/infrastructure_providers.dart';
import '../../../providers/ledger_providers.dart';
import '../../../providers/settings_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  TransactionType? _filter;

  Future<void> _openEditor() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedType = _filter ?? TransactionType.expense;
    var saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add category'),
          content: Form(
            key: formKey,
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
                DropdownButtonFormField<TransactionType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: TransactionType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedType = value);
                  },
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
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(false),
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
                        await ref.read(categoryRepositoryProvider).createCategory(
                              name: nameController.text.trim(),
                              type: selectedType,
                            );
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

    if (saved == true) {
      ref.invalidate(categoriesProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) showSuccessMessage(context, 'Category added.');
    }
  }

  Future<void> _delete(Category category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${category.name}?',
      message:
          'Categories in use may be kept by the server. Existing transactions are never deleted automatically.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
      ref.invalidate(categoriesProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) showSuccessMessage(context, 'Category deleted.');
    } catch (error) {
      if (mounted) showErrorMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final hideBalances = ref.watch(settingsControllerProvider).hideBalances;

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _Chip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    for (final type in TransactionType.values)
                      _Chip(
                        label: type.label,
                        selected: _filter == type,
                        onTap: () => setState(
                          () => _filter = _filter == type ? null : type,
                        ),
                        color: TransactionVisuals.color(context, type),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const LoadingView(message: 'Loading categories...'),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                  data: (categories) {
                    final filtered = _filter == null
                        ? categories
                        : categories
                            .where((category) => category.type == _filter)
                            .toList();
                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: Icons.category_outlined,
                        title: 'No categories here',
                        message:
                            'Create categories to organise your entries, or just speak naturally and the parser will suggest one.',
                        actionLabel: 'Add category',
                        onAction: _openEditor,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final category = filtered[index];
                        final color =
                            TransactionVisuals.color(context, category.type);
                        return SurfaceCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CategoryIcon(
                                name: category.name,
                                iconKey: category.iconKey,
                                colorHex: category.colorHex,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${category.type.label}'
                                      '${category.isDefault ? ' • Default' : ''}'
                                      '${category.transactionCount > 0 ? ' • ${category.transactionCount} entries' : ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (category.totalAmount > 0)
                                Text(
                                  hideBalances
                                      ? '₹ ••••'
                                      : InrFormatter.format(category.totalAmount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () => _delete(category),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withValues(alpha: .16),
        labelStyle: TextStyle(
          color: selected ? color : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
