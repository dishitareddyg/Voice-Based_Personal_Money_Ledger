import '../models/loan.dart';
import '../models/transaction_type.dart';
import '../services/api_paths.dart';
import 'api_helpers.dart';
import 'api_repository.dart';

/// Outstanding loans given to, or taken from, other people.
abstract class LoanRepository {
  Future<List<Loan>> fetchLoans(LoanKind kind);
  Future<List<Loan>> fetchLentLoans();
  Future<List<Loan>> fetchBorrowedLoans();
}

class ApiLoanRepository extends ApiRepositoryBase implements LoanRepository {
  ApiLoanRepository(super.dio);

  @override
  Future<List<Loan>> fetchLoans(LoanKind kind) {
    return guard(() async {
      final response = await dio.get<dynamic>(
        ApiPaths.loans,
        queryParameters: {'kind': kind.apiValue},
      );
      final raw = asJsonList(response.data, keys: const ['loans']);
      return raw
          .whereType<Map>()
          .map((item) => Loan.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<List<Loan>> fetchLentLoans() => fetchLoans(LoanKind.lent);

  @override
  Future<List<Loan>> fetchBorrowedLoans() => fetchLoans(LoanKind.borrowed);
}
