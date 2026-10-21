import 'package:dio/dio.dart';

import '../models/json_utils.dart';
import '../models/transaction.dart';
import '../models/transaction_draft.dart';
import '../services/api_paths.dart';
import 'api_helpers.dart';
import 'api_repository.dart';
import 'transaction_query.dart';

/// Reads and writes the transaction ledger. This is the generic gateway; typed
/// repositories (expense, income, ...) build on top of it.
abstract class TransactionRepository {
  Future<TransactionPage> fetchTransactions(TransactionQuery query);
  Future<Transaction> fetchTransaction(String id);
  Future<TransactionResult> createTransaction(TransactionDraft draft);
  Future<TransactionResult> createVoiceCommand(
    TransactionDraft draft, {
    void Function()? onSent,
  });
}

class ApiTransactionRepository extends ApiRepositoryBase
    implements TransactionRepository {
  ApiTransactionRepository(super.dio);

  @override
  Future<TransactionPage> fetchTransactions(TransactionQuery query) {
    return guard(() async {
      final response = await dio.get<dynamic>(
        ApiPaths.transactions,
        queryParameters: query.toQueryParameters(),
      );
      return TransactionPage.fromJson(unwrapEnvelope(response.data));
    });
  }

  @override
  Future<Transaction> fetchTransaction(String id) {
    return guard(() async {
      final response = await dio.get<dynamic>(ApiPaths.transaction(id));
      final payload = asJsonMap(response.data);
      final transaction = parseMap(payload['transaction']) ?? payload;
      return Transaction.fromJson(transaction);
    });
  }

  @override
  Future<TransactionResult> createTransaction(TransactionDraft draft) {
    return _post(
      ApiPaths.transactions,
      draft.toJson(),
      requestId: draft.requestId,
    );
  }

  @override
  Future<TransactionResult> createVoiceCommand(
    TransactionDraft draft, {
    void Function()? onSent,
  }) {
    return _post(
      ApiPaths.voiceCommands,
      draft.toCommandJson(),
      requestId: draft.requestId,
      onSent: onSent,
    );
  }

  Future<TransactionResult> _post(
    String path,
    Map<String, dynamic> body, {
    required String requestId,
    void Function()? onSent,
  }) {
    return guard(() async {
      var notifiedSent = false;
      final response = await dio.post<dynamic>(
        path,
        data: body,
        options: Options(headers: {'Idempotency-Key': requestId}),
        onSendProgress: (sent, total) {
          if (notifiedSent || total <= 0 || sent < total) return;
          notifiedSent = true;
          onSent?.call();
        },
      );
      final payload = asJsonMap(response.data);
      final transaction = parseMap(payload['transaction']) ??
          parseMap(payload['result']) ??
          payload;

      return TransactionResult(
        id: parseString(
          transaction['id'] ?? transaction['transaction_id'],
        ),
        message: parseString(
          payload['message'],
          fallback: 'Transaction saved securely.',
        ),
        availableBalance: parseNullableDouble(
          payload['available_balance'] ?? transaction['available_balance'],
        ),
        amountInr: parseNullableDouble(
          payload['amount_inr'] ?? transaction['amount_inr'],
        ),
        exchangeRate: parseNullableDouble(
          payload['exchange_rate_to_inr'] ??
              transaction['exchange_rate_to_inr'],
        ),
        isDuplicate: parseBool(
          payload['idempotent_replay'] ?? payload['duplicate'],
        ),
      );
    });
  }
}
