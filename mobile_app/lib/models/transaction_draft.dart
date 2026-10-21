import 'transaction_type.dart';

/// The structured command sent to the Raspberry Pi.
///
/// The backend is authoritative: it validates the amount, converts foreign
/// currency with a live rate, checks balances and writes within a single MySQL
/// transaction. `requestId` provides idempotency across network retries.
class TransactionDraft {
  const TransactionDraft({
    required this.requestId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    this.description = '',
    this.categoryId,
    this.categoryName,
    this.personId,
    this.personName,
    this.interestRate,
    this.interestType,
    this.repaymentDirection,
    this.loanId,
    this.voiceText,
    this.parserConfidence,
  });

  final String requestId;
  final TransactionType type;
  final double amount;
  final String currency;
  final DateTime transactionDate;
  final String description;
  final String? categoryId;
  final String? categoryName;
  final String? personId;
  final String? personName;
  final double? interestRate;
  final InterestType? interestType;
  final RepaymentDirection? repaymentDirection;
  final String? loanId;
  final String? voiceText;
  final double? parserConfidence;

  bool get needsConversion => currency.toUpperCase() != 'INR';

  /// Returns a copy with a fixed type. Used by the typed repositories so that,
  /// for example, an expense can never be posted as income.
  TransactionDraft withType(TransactionType newType) {
    return TransactionDraft(
      requestId: requestId,
      type: newType,
      amount: amount,
      currency: currency,
      transactionDate: transactionDate,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      personId: personId,
      personName: personName,
      interestRate: interestRate,
      interestType: interestType,
      repaymentDirection: repaymentDirection,
      loanId: loanId,
      voiceText: voiceText,
      parserConfidence: parserConfidence,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'type': type.apiValue,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'transaction_date': _dateValue,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (categoryId != null) 'category_id': categoryId,
      if (categoryName != null && categoryName!.trim().isNotEmpty)
        'category_name': categoryName,
      if (personId != null) 'person_id': personId,
      if (personName != null && personName!.trim().isNotEmpty)
        'person_name': personName,
      if (interestRate != null) 'interest_rate': interestRate,
      if (interestType != null) 'interest_type': interestType!.apiValue,
      if (repaymentDirection != null)
        'repayment_direction': repaymentDirection!.apiValue,
      if (loanId != null) 'loan_id': loanId,
      if (voiceText != null && voiceText!.trim().isNotEmpty)
        'voice_text': voiceText,
      if (parserConfidence != null) 'parser_confidence': parserConfidence,
    };
  }

  /// The confirmed voice command shape documented in `docs/api-contract.md`.
  /// The server maps [intent] to the authoritative ledger operation.
  Map<String, dynamic> toCommandJson() {
    return {
      'request_id': requestId,
      'intent': type.commandIntent,
      'original_amount': amount,
      'original_currency': currency.toUpperCase(),
      'transaction_date': _dateValue,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (categoryId != null) 'category_id': categoryId,
      if (categoryName != null && categoryName!.trim().isNotEmpty)
        'category': categoryName,
      if (personId != null) 'person_id': personId,
      if (personName != null && personName!.trim().isNotEmpty)
        'person': personName,
      if (interestRate != null) 'interest_rate': interestRate,
      if (interestType != null) 'interest_type': interestType!.apiValue,
      if (repaymentDirection != null)
        'repayment_direction': repaymentDirection!.apiValue,
      if (loanId != null) 'loan_id': loanId,
      if (voiceText != null && voiceText!.trim().isNotEmpty)
        'voice_text': voiceText,
      if (parserConfidence != null) 'parser_confidence': parserConfidence,
    };
  }

  String get _dateValue => '${transactionDate.year.toString().padLeft(4, '0')}-'
      '${transactionDate.month.toString().padLeft(2, '0')}-'
      '${transactionDate.day.toString().padLeft(2, '0')}';
}

class TransactionResult {
  const TransactionResult({
    required this.id,
    required this.message,
    this.availableBalance,
    this.amountInr,
    this.exchangeRate,
    this.isDuplicate = false,
  });

  final String id;
  final String message;
  final double? availableBalance;
  final double? amountInr;
  final double? exchangeRate;
  final bool isDuplicate;

  factory TransactionResult.fromJson(Map<String, dynamic> json) {
    return TransactionResult(
      id: (json['id'] ?? json['transaction_id'] ?? '').toString(),
      message: (json['message'] ?? 'Transaction saved securely.').toString(),
      availableBalance: json['available_balance'] == null
          ? null
          : double.tryParse(json['available_balance'].toString()),
      amountInr: json['amount_inr'] == null
          ? null
          : double.tryParse(json['amount_inr'].toString()),
      exchangeRate: json['exchange_rate_to_inr'] == null
          ? null
          : double.tryParse(json['exchange_rate_to_inr'].toString()),
      isDuplicate: json['idempotent_replay'] == true,
    );
  }
}
