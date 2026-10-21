import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_ledger/models/transaction_draft.dart';
import 'package:voice_ledger/models/transaction_type.dart';
import 'package:voice_ledger/repositories/transaction_repository.dart';

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'Expense recorded successfully.',
        'idempotent_replay': false,
        'transaction': {
          'id': 42,
          'type': 'expense',
          'amount_inr': '2000.00',
        },
        'amount_inr': '2000.00',
        'available_balance': '3000.00',
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('sends the documented intent payload to /commands', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://pi.local/api/v1'))
      ..httpClientAdapter = adapter;
    final repository = ApiTransactionRepository(dio);
    final draft = TransactionDraft(
      requestId: 'cmd-12345678',
      type: TransactionType.expense,
      amount: 2000,
      currency: 'INR',
      transactionDate: DateTime(2026, 10, 20),
      description: 'Groceries',
      categoryName: 'Groceries',
      voiceText: 'I spent 2000 rupees on groceries',
      parserConfidence: 0.97,
    );

    final result = await repository.createVoiceCommand(draft);

    final options = adapter.lastOptions!;
    final body = options.data as Map<String, dynamic>;
    expect(options.path, '/commands');
    expect(options.headers['Idempotency-Key'], 'cmd-12345678');
    expect(body['intent'], 'CREATE_EXPENSE');
    expect(body.containsKey('type'), isFalse);
    expect(body['original_amount'], 2000);
    expect(body['original_currency'], 'INR');
    expect(body['category'], 'Groceries');
    expect(body['transaction_date'], '2026-10-20');
    expect(body['voice_text'], 'I spent 2000 rupees on groceries');
    expect(result.amountInr, 2000);
    expect(result.availableBalance, 3000);
  });
}
