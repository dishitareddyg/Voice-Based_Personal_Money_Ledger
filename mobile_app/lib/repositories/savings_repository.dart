import '../models/transaction.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_type.dart';
import 'transaction_query.dart';
import 'transaction_repository.dart';

/// Savings-specific view over the transaction ledger.
abstract class SavingsRepository {
  Future<TransactionPage> fetchSavings(TransactionQuery query);
  Future<TransactionResult> createSaving(TransactionDraft draft);
}

class ApiSavingsRepository implements SavingsRepository {
  ApiSavingsRepository(this._transactions);

  final TransactionRepository _transactions;

  @override
  Future<TransactionPage> fetchSavings(TransactionQuery query) {
    return _transactions.fetchTransactions(
      query.copyWith(type: TransactionType.saving),
    );
  }

  @override
  Future<TransactionResult> createSaving(TransactionDraft draft) {
    return _transactions.createTransaction(
      draft.withType(TransactionType.saving),
    );
  }
}
