import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_month.dart';
import '../models/category.dart';
import '../models/ledger_summary.dart';
import '../models/loan.dart';
import '../models/person.dart';
import '../models/repayment.dart';
import '../models/transaction.dart';
import '../models/transaction_type.dart';
import '../repositories/transaction_query.dart';
import 'infrastructure_providers.dart';

final dashboardSummaryProvider =
    FutureProvider.autoDispose<LedgerSummary>((ref) async {
  try {
    return await ref.watch(dashboardRepositoryProvider).fetchSummary();
  } catch (error, stackTrace) {
    // Temporary diagnostic. Do not log the financial response body.
    debugPrint(
      '[Dashboard] fetchSummary failed: ${error.runtimeType}: $error',
    );
    debugPrintStack(stackTrace: stackTrace, label: '[Dashboard] stack trace');
    rethrow;
  }
});

final dashboardCalendarProvider =
    FutureProvider.autoDispose<CalendarMonth>((ref) async {
  final now = DateTime.now();
  return ref
      .watch(dashboardRepositoryProvider)
      .fetchCalendar(DateTime(now.year, now.month));
});

final calendarMonthProvider =
    FutureProvider.autoDispose.family<CalendarMonth, DateTime>((ref, month) {
  final normalized = DateTime(month.year, month.month, 1);
  return ref.watch(dashboardRepositoryProvider).fetchCalendar(normalized);
});

class TransactionFeed {
  const TransactionFeed({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Transaction> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;

  TransactionFeed copyWith({
    List<Transaction>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return TransactionFeed(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

class TransactionFeedController
    extends AutoDisposeAsyncNotifier<TransactionFeed> {
  TransactionQuery _query = const TransactionQuery();

  @override
  Future<TransactionFeed> build() async {
    final page = await ref
        .watch(transactionRepositoryProvider)
        .fetchTransactions(_query.copyWith(page: 1));
    return TransactionFeed(
      items: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  Future<void> setType(TransactionType? type) async {
    _query = _query.copyWith(
      type: type,
      clearType: type == null,
      page: 1,
    );
    await _reload();
  }

  Future<void> setSearch(String value) async {
    _query = _query.copyWith(search: value, page: 1);
    await _reload();
  }

  Future<void> refresh() async {
    _query = _query.copyWith(page: 1);
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isLoadingMore: false));
    }
    state = await AsyncValue.guard(_fetchFirstPage);
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchFirstPage);
  }

  Future<TransactionFeed> _fetchFirstPage() async {
    final page = await ref
        .read(transactionRepositoryProvider)
        .fetchTransactions(_query.copyWith(page: 1));
    return TransactionFeed(
      items: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );

    try {
      final next = await ref
          .read(transactionRepositoryProvider)
          .fetchTransactions(_query.copyWith(page: current.page + 1));
      final seen = current.items.map((item) => item.id).toSet();
      final merged = [
        ...current.items,
        ...next.items.where((item) => !seen.contains(item.id)),
      ];
      state = AsyncData(
        current.copyWith(
          items: merged,
          total: next.total,
          page: next.page,
          hasMore: next.hasMore,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: 'Could not load more transactions. Tap to retry.',
        ),
      );
    }
  }
}

final transactionFeedControllerProvider =
    AutoDisposeAsyncNotifierProvider<TransactionFeedController, TransactionFeed>(
  TransactionFeedController.new,
);

final typeTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, TransactionType>((ref, type) async {
  final page = await ref.watch(transactionRepositoryProvider).fetchTransactions(
        TransactionQuery(type: type, pageSize: 50),
      );
  return page.items;
});

final personsProvider = FutureProvider.autoDispose<List<Person>>((ref) async {
  return ref.watch(personRepositoryProvider).fetchPersons();
});

final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).fetchCategories();
});

final loansProvider =
    FutureProvider.autoDispose.family<List<Loan>, LoanKind>((ref, kind) {
  return ref.watch(loanRepositoryProvider).fetchLoans(kind);
});

final repaymentsProvider =
    FutureProvider.autoDispose<List<Repayment>>((ref) async {
  return ref.watch(repaymentRepositoryProvider).fetchRepayments();
});

extension LedgerInvalidation on WidgetRef {
  void invalidateLedgerData() {
    invalidate(dashboardSummaryProvider);
    invalidate(dashboardCalendarProvider);
    invalidate(calendarMonthProvider);
    invalidate(transactionFeedControllerProvider);
    invalidate(typeTransactionsProvider);
    invalidate(personsProvider);
    invalidate(categoriesProvider);
    invalidate(loansProvider);
    invalidate(repaymentsProvider);
  }
}
