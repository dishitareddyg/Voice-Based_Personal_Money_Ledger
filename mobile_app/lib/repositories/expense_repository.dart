import '../models/transaction.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_type.dart';
import 'transaction_query.dart';
import 'transaction_repository.dart';

/// Expense-specific view over the transaction ledger. The type is fixed so the
/// expense screens cannot accidentally read or write another category.
abstract class ExpenseRepository {
  Future<TransactionPage> fetchExpenses(TransactionQuery query);
  Future<TransactionResult> createExpense(TransactionDraft draft);
}

class ApiExpenseRepository implements ExpenseRepository {
  ApiExpenseRepository(this._transactions);

  final TransactionRepository _transactions;

  @override
  Future<TransactionPage> fetchExpenses(TransactionQuery query) {
    return _transactions.fetchTransactions(
      query.copyWith(type: TransactionType.expense),
    );
  }

  @override
  Future<TransactionResult> createExpense(TransactionDraft draft) {
    return _transactions.createTransaction(
      draft.withType(TransactionType.expense),
    );
  }
}
