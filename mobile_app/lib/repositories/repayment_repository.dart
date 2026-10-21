import '../models/repayment.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_type.dart';
import '../services/api_paths.dart';
import 'api_helpers.dart';
import 'api_repository.dart';
import 'transaction_repository.dart';

/// Repayments of money lent or borrowed.
abstract class RepaymentRepository {
  Future<List<Repayment>> fetchRepayments({String? loanId, int limit});
  Future<TransactionResult> createRepayment(TransactionDraft draft);
}

class ApiRepaymentRepository extends ApiRepositoryBase
    implements RepaymentRepository {
  ApiRepaymentRepository(super.dio, this._transactions);

  final TransactionRepository _transactions;

  @override
  Future<List<Repayment>> fetchRepayments({String? loanId, int limit = 50}) {
    return guard(() async {
      final response = await dio.get<dynamic>(
        ApiPaths.repayments,
        queryParameters: {
          'limit': limit,
          'loan_id': ?loanId,
        },
      );
      final raw = asJsonList(response.data, keys: const ['repayments']);
      return raw
          .whereType<Map>()
          .map((item) => Repayment.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<TransactionResult> createRepayment(TransactionDraft draft) {
    return _transactions.createTransaction(
      draft.withType(TransactionType.repayment),
    );
  }
}
