import '../models/transaction.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_type.dart';
import 'transaction_query.dart';
import 'transaction_repository.dart';

/// Income-specific view over the transaction ledger.
abstract class IncomeRepository {
  Future<TransactionPage> fetchIncome(TransactionQuery query);
  Future<TransactionResult> createIncome(TransactionDraft draft);
}

class ApiIncomeRepository implements IncomeRepository {
  ApiIncomeRepository(this._transactions);

  final TransactionRepository _transactions;

  @override
  Future<TransactionPage> fetchIncome(TransactionQuery query) {
    return _transactions.fetchTransactions(
      query.copyWith(type: TransactionType.income),
    );
  }

  @override
  Future<TransactionResult> createIncome(TransactionDraft draft) {
    return _transactions.createTransaction(
      draft.withType(TransactionType.income),
    );
  }
}
