import 'package:dio/dio.dart';

import '../models/calendar_month.dart';
import '../models/ledger_summary.dart';
import '../models/loan.dart';
import '../models/repayment.dart';
import '../models/transaction.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_type.dart';
import 'dashboard_repository.dart';
import 'loan_repository.dart';
import 'repayment_repository.dart';
import 'transaction_query.dart';
import 'transaction_repository.dart';

export 'transaction_query.dart';

/// Aggregate ledger gateway. It keeps the original single-object API used by
/// several screens while delegating to the focused repositories underneath, so
/// each domain has one implementation of its HTTP calls.
abstract class LedgerRepository {
  Future<LedgerSummary> fetchSummary();
  Future<TransactionPage> fetchTransactions(TransactionQuery query);
  Future<Transaction> fetchTransaction(String id);
  Future<TransactionResult> createTransaction(TransactionDraft draft);
  Future<TransactionResult> createVoiceCommand(
    TransactionDraft draft, {
    void Function()? onSent,
  });
  Future<CalendarMonth> fetchCalendar(DateTime month);
  Future<List<Loan>> fetchLoans(LoanKind kind);
  Future<List<Repayment>> fetchRepayments({String? loanId, int limit = 50});
}

class ApiLedgerRepository implements LedgerRepository {
  ApiLedgerRepository(Dio dio)
      : _dashboard = ApiDashboardRepository(dio),
        _transactions = ApiTransactionRepository(dio),
        _loans = ApiLoanRepository(dio),
        _repayments = ApiRepaymentRepository(dio, ApiTransactionRepository(dio));

  final DashboardRepository _dashboard;
  final TransactionRepository _transactions;
  final LoanRepository _loans;
  final RepaymentRepository _repayments;

  @override
  Future<LedgerSummary> fetchSummary() => _dashboard.fetchSummary();

  @override
  Future<TransactionPage> fetchTransactions(TransactionQuery query) =>
      _transactions.fetchTransactions(query);

  @override
  Future<Transaction> fetchTransaction(String id) =>
      _transactions.fetchTransaction(id);

  @override
  Future<TransactionResult> createTransaction(TransactionDraft draft) =>
      _transactions.createTransaction(draft);

  @override
  Future<TransactionResult> createVoiceCommand(
    TransactionDraft draft, {
    void Function()? onSent,
  }) =>
      _transactions.createVoiceCommand(draft, onSent: onSent);

  @override
  Future<CalendarMonth> fetchCalendar(DateTime month) =>
      _dashboard.fetchCalendar(month);

  @override
  Future<List<Loan>> fetchLoans(LoanKind kind) => _loans.fetchLoans(kind);

  @override
  Future<List<Repayment>> fetchRepayments({String? loanId, int limit = 50}) =>
      _repayments.fetchRepayments(loanId: loanId, limit: limit);
}
