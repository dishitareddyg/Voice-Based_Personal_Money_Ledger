import 'json_utils.dart';
import 'transaction.dart';
import 'transaction_type.dart';

class CalendarMonth {
  const CalendarMonth({required this.month, required this.days});

  final DateTime month;
  final List<CalendarDay> days;

  CalendarDay? dayFor(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }

  factory CalendarMonth.fromJson(
    dynamic data, {
    required DateTime requestedMonth,
  }) {
    final map = parseMap(data) ?? const <String, dynamic>{};
    final rawDays = data is List
        ? data
        : parseList(map['days'] ?? map['items'] ?? map['calendar']);

    final days = rawDays.map((raw) {
      if (raw is Map) {
        final entry = Map<String, dynamic>.from(raw);
        final date = parseDateTime(
          entry['date'] ?? entry['transaction_date'] ?? entry['day'],
        );
        if (date != null) {
          return CalendarDay.fromJson(entry, fallbackDate: date);
        }
      }
      return null;
    }).whereType<CalendarDay>().toList(growable: false);

    final monthValue = parseDateTime(map['month']) ??
        (days.isNotEmpty ? DateTime(days.first.date.year, days.first.date.month) : requestedMonth);

    return CalendarMonth(month: monthValue, days: days);
  }
}

class CalendarDay {
  const CalendarDay({
    required this.date,
    this.income = 0,
    this.expense = 0,
    this.savings = 0,
    this.lending = 0,
    this.borrowing = 0,
    this.repayment = 0,
    this.transactionCount = 0,
    this.transactions = const [],
  });

  final DateTime date;
  final double income;
  final double expense;
  final double savings;
  final double lending;
  final double borrowing;
  final double repayment;
  final int transactionCount;
  final List<Transaction> transactions;

  bool get hasActivity =>
      transactionCount > 0 ||
      transactions.isNotEmpty ||
      income > 0 ||
      expense > 0 ||
      savings > 0 ||
      lending > 0 ||
      borrowing > 0 ||
      repayment > 0;

  Set<TransactionType> get activeTypes {
    final result = <TransactionType>{};
    if (income > 0) result.add(TransactionType.income);
    if (expense > 0) result.add(TransactionType.expense);
    if (savings > 0) result.add(TransactionType.saving);
    if (lending > 0) result.add(TransactionType.lending);
    if (borrowing > 0) result.add(TransactionType.borrowing);
    if (repayment > 0) result.add(TransactionType.repayment);
    for (final transaction in transactions) {
      result.add(transaction.type);
    }
    return result;
  }

  double get net => income + borrowing - expense - savings - lending;

  factory CalendarDay.fromJson(
    Map<String, dynamic> json, {
    required DateTime fallbackDate,
  }) {
    final rawTransactions = parseList(json['transactions'] ?? json['items']);
    return CalendarDay(
      date: parseRequiredDateTime(
        json['date'] ?? json['transaction_date'] ?? json['day'],
        fallback: fallbackDate,
      ),
      income: parseDouble(json['income'] ?? json['income_total']),
      expense: parseDouble(json['expense'] ?? json['expense_total']),
      savings: parseDouble(json['savings'] ?? json['savings_total']),
      lending: parseDouble(json['lending'] ?? json['lent_total']),
      borrowing: parseDouble(json['borrowing'] ?? json['borrowed_total']),
      repayment: parseDouble(json['repayment'] ?? json['repayment_total']),
      transactionCount: parseInt(
        json['transaction_count'] ?? json['count'],
        fallback: rawTransactions.length,
      ),
      transactions: rawTransactions
          .whereType<Map>()
          .map((item) => Transaction.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }
}
