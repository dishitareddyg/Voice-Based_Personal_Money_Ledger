import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../../core/widgets/transaction_visuals.dart';
import '../../../models/transaction_type.dart';
import '../../../providers/ledger_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../router/routes.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  TransactionType? _type;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.85) {
      ref.read(transactionFeedControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(transactionFeedControllerProvider.notifier).setSearch(value);
    });
  }

  Future<void> _selectType(TransactionType? type) async {
    setState(() => _type = type);
    await ref.read(transactionFeedControllerProvider.notifier).setType(type);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(transactionFeedControllerProvider);
    final hideBalances = ref.watch(settingsControllerProvider).hideBalances;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Record with voice',
            onPressed: () => context.go(Routes.voice),
            icon: const Icon(Icons.mic_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by description, person or category',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _type == null,
                      onSelected: () => _selectType(null),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    for (final type in TransactionType.values)
                      _FilterChip(
                        label: type.label,
                        selected: _type == type,
                        onSelected: () =>
                            _selectType(_type == type ? null : type),
                        color: TransactionVisuals.color(context, type),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(transactionFeedControllerProvider.notifier)
                      .refresh(),
                  child: feedAsync.when(
                    loading: () => ListView(
                      padding: const EdgeInsets.only(top: 60),
                      children: const [
                        LoadingView(message: 'Loading transactions...'),
                      ],
                    ),
                    error: (error, _) => ListView(
                      padding: const EdgeInsets.only(top: 60),
                      children: [
                        ErrorView(
                          error: error,
                          onRetry: () => ref
                              .read(transactionFeedControllerProvider.notifier)
                              .refresh(),
                        ),
                      ],
                    ),
                    data: (feed) {
                      if (feed.items.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.only(top: 40),
                          children: [
                            EmptyState(
                              icon: Icons.receipt_long_rounded,
                              title: _searchController.text.isEmpty
                                  ? 'No transactions yet'
                                  : 'No matches found',
                              message: _searchController.text.isEmpty
                                  ? 'Record your first entry with voice or from the dashboard.'
                                  : 'Try a different search word or clear the filters.',
                              actionLabel: 'Record with voice',
                              onAction: () => context.go(Routes.voice),
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
                        itemCount: feed.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return SectionHeader(
                              title: '${feed.total} entries',
                              subtitle: _type?.label ?? 'All activity',
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            );
                          }
                          final transaction = feed.items[index - 1];
                          final isLast = index == feed.items.length;
                          return Column(
                            children: [
                              TransactionTile(
                                transaction: transaction,
                                hideAmount: hideBalances,
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  indent: 60,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: .5),
                                ),
                              if (isLast && feed.loadMoreError != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: AppButton(
                                    label: 'Retry loading more',
                                    icon: Icons.refresh_rounded,
                                    variant: AppButtonVariant.tonal,
                                    expand: false,
                                    onPressed: () => ref
                                        .read(
                                          transactionFeedControllerProvider
                                              .notifier,
                                        )
                                        .loadMore(),
                                  ),
                                )
                              else if (isLast && feed.hasMore)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    ),
                                  ),
                                )
                              else if (isLast)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    'That is everything.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: color.withValues(alpha: .16),
        labelStyle: TextStyle(
          color: selected ? color : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
