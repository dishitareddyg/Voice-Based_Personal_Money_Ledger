import 'json_utils.dart';
import 'transaction_type.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amountInr,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.currency = 'INR',
    this.originalAmount,
    this.originalCurrency,
    this.exchangeRateToInr,
    this.categoryId,
    this.categoryName,
    this.personId,
    this.personName,
    this.interestRate,
    this.interestType,
    this.loanId,
    this.repaymentDirection,
    this.status = 'completed',
    this.reference,
  });

  final String id;
  final TransactionType type;
  final double amountInr;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  final String currency;
  final double? originalAmount;
  final String? originalCurrency;
  final double? exchangeRateToInr;
  final String? categoryId;
  final String? categoryName;
  final String? personId;
  final String? personName;
  final double? interestRate;
  final InterestType? interestType;
  final String? loanId;
  final RepaymentDirection? repaymentDirection;
  final String status;
  final String? reference;

  bool get isInflow {
    switch (type) {
      case TransactionType.income:
        return true;
      case TransactionType.borrowing:
        return true;
      case TransactionType.repayment:
        return repaymentDirection == RepaymentDirection.received;
      case TransactionType.expense:
      case TransactionType.saving:
      case TransactionType.lending:
        return false;
    }
  }

  double get signedAmount => isInflow ? amountInr : -amountInr;

  String get displayTitle {
    if (description.trim().isNotEmpty) return description.trim();
    if (categoryName != null && categoryName!.trim().isNotEmpty) {
      return categoryName!;
    }
    if (personName != null && personName!.trim().isNotEmpty) {
      return personName!;
    }
    return type.label;
  }

  bool get hasConversion =>
      originalCurrency != null &&
      originalCurrency!.toUpperCase() != 'INR' &&
      originalAmount != null;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final category = parseMap(json['category']);
    final person = parseMap(json['person']);
    final loan = parseMap(json['loan']);

    return Transaction(
      id: parseString(json['id'] ?? json['transaction_id']),
      type: TransactionType.parse(
        json['type'] ?? json['transaction_type'] ?? json['intent'],
      ),
      amountInr: parseDouble(
        json['amount_inr'] ?? json['amountInr'] ?? json['amount'],
      ),
      transactionDate: parseRequiredDateTime(
        json['transaction_date'] ?? json['transactionDate'] ?? json['date'],
      ),
      createdAt: parseRequiredDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
      updatedAt: parseRequiredDateTime(
        json['updated_at'] ?? json['updatedAt'],
        fallback: parseDateTime(json['created_at']) ?? DateTime.now(),
      ),
      description: parseString(json['description'] ?? json['note']),
      currency: parseString(
        json['currency'] ?? json['original_currency'],
        fallback: 'INR',
      ),
      originalAmount: parseNullableDouble(
        json['original_amount'] ?? json['originalAmount'],
      ),
      originalCurrency: json['original_currency'] == null
          ? null
          : parseString(json['original_currency']),
      exchangeRateToInr: parseNullableDouble(
        json['exchange_rate_to_inr'] ?? json['exchangeRateToInr'],
      ),
      categoryId: json['category_id']?.toString() ??
          (category == null ? null : parseString(category['id'])),
      categoryName: json['category_name']?.toString() ??
          (category == null
              ? null
              : parseString(category['name'], fallback: '')),
      personId: json['person_id']?.toString() ??
          (person == null ? null : parseString(person['id'])),
      personName: json['person_name']?.toString() ??
          (person == null
              ? null
              : parseString(person['name'], fallback: '')),
      interestRate: parseNullableDouble(
        json['interest_rate'] ?? json['interestRate'],
      ),
      interestType: json['interest_type'] == null
          ? null
          : InterestType.parse(json['interest_type']),
      loanId: json['loan_id']?.toString() ??
          (loan == null ? null : parseString(loan['id'])),
      repaymentDirection: RepaymentDirection.tryParse(
        json['repayment_direction'] ?? json['direction'],
      ),
      status: parseString(json['status'], fallback: 'completed'),
      reference: json['reference'] == null
          ? null
          : parseString(json['reference']),
    );
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amountInr,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? currency,
    double? originalAmount,
    String? originalCurrency,
    double? exchangeRateToInr,
    String? categoryId,
    String? categoryName,
    String? personId,
    String? personName,
    double? interestRate,
    InterestType? interestType,
    String? loanId,
    RepaymentDirection? repaymentDirection,
    String? status,
    String? reference,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amountInr: amountInr ?? this.amountInr,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      exchangeRateToInr: exchangeRateToInr ?? this.exchangeRateToInr,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      interestRate: interestRate ?? this.interestRate,
      interestType: interestType ?? this.interestType,
      loanId: loanId ?? this.loanId,
      repaymentDirection: repaymentDirection ?? this.repaymentDirection,
      status: status ?? this.status,
      reference: reference ?? this.reference,
    );
  }
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  final List<Transaction> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  factory TransactionPage.empty() => const TransactionPage(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
        hasMore: false,
      );

  factory TransactionPage.fromJson(dynamic data) {
    final map = parseMap(data) ?? const <String, dynamic>{};
    final rawItems = data is List
        ? data
        : parseList(map['items'] ?? map['transactions'] ?? map['results']);
    final pagination = parseMap(map['pagination']) ?? map;
    final page = parseInt(pagination['page'], fallback: 1);
    final pageSize = parseInt(
      pagination['page_size'] ?? pagination['pageSize'],
      fallback: rawItems.length,
    );
    final total = parseInt(pagination['total'], fallback: rawItems.length);
    final hasMore = parseBool(
      pagination['has_more'] ?? pagination['hasMore'],
      fallback: page * pageSize < total,
    );

    return TransactionPage(
      items: rawItems
          .whereType<Map>()
          .map((item) => Transaction.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      page: page,
      pageSize: pageSize,
      total: total,
      hasMore: hasMore,
    );
  }
}
