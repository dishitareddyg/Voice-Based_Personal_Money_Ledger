import '../../../models/transaction_type.dart';

enum VoiceIntent {
  createExpense,
  createIncome,
  createSavings,
  createLending,
  createBorrowing,
  createRepayment,
  queryBalance,
  queryExpenses,
  queryIncome,
  queryLoans,
  queryTransactions,
  unknown;

  String get label {
    switch (this) {
      case VoiceIntent.createExpense:
        return 'Expense';
      case VoiceIntent.createIncome:
        return 'Income';
      case VoiceIntent.createSavings:
        return 'Savings';
      case VoiceIntent.createLending:
        return 'Lending';
      case VoiceIntent.createBorrowing:
        return 'Borrowing';
      case VoiceIntent.createRepayment:
        return 'Repayment';
      case VoiceIntent.queryBalance:
        return 'Balance';
      case VoiceIntent.queryExpenses:
        return 'Expenses';
      case VoiceIntent.queryIncome:
        return 'Income report';
      case VoiceIntent.queryLoans:
        return 'Loans';
      case VoiceIntent.queryTransactions:
        return 'Transactions';
      case VoiceIntent.unknown:
        return 'Unknown';
    }
  }

  TransactionType? get transactionType {
    switch (this) {
      case VoiceIntent.createExpense:
        return TransactionType.expense;
      case VoiceIntent.createIncome:
        return TransactionType.income;
      case VoiceIntent.createSavings:
        return TransactionType.saving;
      case VoiceIntent.createLending:
        return TransactionType.lending;
      case VoiceIntent.createBorrowing:
        return TransactionType.borrowing;
      case VoiceIntent.createRepayment:
        return TransactionType.repayment;
      case VoiceIntent.queryBalance:
      case VoiceIntent.queryExpenses:
      case VoiceIntent.queryIncome:
      case VoiceIntent.queryLoans:
      case VoiceIntent.queryTransactions:
      case VoiceIntent.unknown:
        return null;
    }
  }

  /// A read-only question about the ledger. Queries never create a record and
  /// therefore do not require an amount or a person.
  bool get isQuery =>
      this == VoiceIntent.queryBalance ||
      this == VoiceIntent.queryExpenses ||
      this == VoiceIntent.queryIncome ||
      this == VoiceIntent.queryLoans ||
      this == VoiceIntent.queryTransactions;

  bool get requiresAmount => !isQuery && this != VoiceIntent.unknown;

  bool get requiresPerson =>
      this == VoiceIntent.createLending ||
      this == VoiceIntent.createBorrowing ||
      this == VoiceIntent.createRepayment;
}

enum VoiceField {
  intent,
  amount,
  person,
  repaymentDirection;

  String get label {
    switch (this) {
      case VoiceField.intent:
        return 'the action (spent, lent, borrowed, received, saved)';
      case VoiceField.amount:
        return 'an amount';
      case VoiceField.person:
        return 'a person';
      case VoiceField.repaymentDirection:
        return 'who paid whom';
    }
  }
}

class ParsedVoiceCommand {
  const ParsedVoiceCommand({
    required this.originalText,
    required this.intent,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    required this.confidence,
    required this.missingFields,
    required this.warnings,
    this.personName,
    this.categoryName,
    this.description = '',
    this.transactionTime,
    this.interestRate,
    this.interestType,
    this.repaymentDirection,
    this.explicitDate = false,
    this.explicitCurrency = false,
  });

  final String originalText;
  final VoiceIntent intent;
  final double? amount;
  final String currency;
  final DateTime transactionDate;
  final double confidence;
  final List<VoiceField> missingFields;
  final List<String> warnings;
  final String? personName;
  final String? categoryName;
  final String description;
  final String? transactionTime;
  final double? interestRate;
  final InterestType? interestType;
  final RepaymentDirection? repaymentDirection;
  final bool explicitDate;
  final bool explicitCurrency;

  bool get canSubmit => intent != VoiceIntent.unknown && missingFields.isEmpty;

  bool get isQuery => intent.isQuery;

  bool get needsReview => confidence < 0.75 || warnings.isNotEmpty;

  String get confidenceLabel {
    if (confidence >= 0.85) return 'High confidence';
    if (confidence >= 0.7) return 'Review suggested';
    return 'Low confidence';
  }

  ParsedVoiceCommand copyWith({
    double? amount,
    String? currency,
    DateTime? transactionDate,
    String? personName,
    String? categoryName,
    String? description,
    double? interestRate,
    InterestType? interestType,
    RepaymentDirection? repaymentDirection,
  }) {
    return ParsedVoiceCommand(
      originalText: originalText,
      intent: intent,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      transactionDate: transactionDate ?? this.transactionDate,
      confidence: confidence,
      missingFields: missingFields,
      warnings: warnings,
      personName: personName ?? this.personName,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      transactionTime: transactionTime,
      interestRate: interestRate ?? this.interestRate,
      interestType: interestType ?? this.interestType,
      repaymentDirection: repaymentDirection ?? this.repaymentDirection,
      explicitDate: explicitDate,
      explicitCurrency: explicitCurrency,
    );
  }
}
