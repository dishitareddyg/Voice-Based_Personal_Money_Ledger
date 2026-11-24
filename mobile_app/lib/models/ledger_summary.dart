import 'category.dart';
import 'json_utils.dart';
import 'transaction.dart';

class LedgerSummary {
  const LedgerSummary({
    required this.availableBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalSavings,
    required this.moneyLent,
    required this.moneyBorrowed,
    required this.outstandingLent,
    required this.outstandingBorrowed,
    required this.upcomingRepaymentTotal,
    required this.upcomingRepaymentCount,
    required this.recentTransactions,
    required this.categoryBreakdown,
    required this.upcomingRepayments,
    required this.notes,
    required this.currency,
  });

  final double availableBalance;
  final double totalIncome;
  final double totalExpenses;
  final double totalSavings;
  final double moneyLent;
  final double moneyBorrowed;
  final double outstandingLent;
  final double outstandingBorrowed;
  final double upcomingRepaymentTotal;
  final int upcomingRepaymentCount;
  final List<Transaction> recentTransactions;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<UpcomingRepayment> upcomingRepayments;
  final List<LedgerNote> notes;
  final String currency;

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    final activity = parseMap(json['recent_transactions']) ??
        parseMap(json['recentTransactions']);
    final List<dynamic> recentRaw = json['recent_transactions'] is List
      ? json['recent_transactions'] as List<dynamic>
      : json['recentTransactions'] is List
          ? json['recentTransactions'] as List<dynamic>
          : parseList(activity?['items']);

    return LedgerSummary(
      availableBalance: parseDouble(
        json['available_balance'] ?? json['availableBalance'],
      ),
      totalIncome: parseDouble(json['total_income'] ?? json['totalIncome']),
      totalExpenses:
          parseDouble(json['total_expenses'] ?? json['totalExpenses']),
      totalSavings: parseDouble(json['total_savings'] ?? json['totalSavings']),
      moneyLent: parseDouble(json['money_lent'] ?? json['moneyLent']),
      moneyBorrowed:
          parseDouble(json['money_borrowed'] ?? json['moneyBorrowed']),
      outstandingLent: parseDouble(
        json['outstanding_lent'] ?? json['outstandingLent'],
      ),
      outstandingBorrowed: parseDouble(
        json['outstanding_borrowed'] ?? json['outstandingBorrowed'],
      ),
      upcomingRepaymentTotal: parseDouble(
        json['upcoming_repayment_total'] ??
            json['upcomingRepaymentTotal'] ??
            json['outstanding_repayments'],
      ),
      upcomingRepaymentCount: parseInt(
        json['upcoming_repayment_count'] ?? json['upcomingRepaymentCount'],
      ),
      recentTransactions: recentRaw
          .whereType<Map>()
          .map<Transaction>(
            (item) => 
                Transaction.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      categoryBreakdown: parseList(
        json['category_breakdown'] ?? json['categoryBreakdown'],
      )
          .whereType<Map>()
          .map(
            (item) =>
                CategoryBreakdown.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      upcomingRepayments: parseList(
        json['upcoming_repayments'] ?? json['upcomingRepayments'],
      )
          .whereType<Map>()
          .map(
            (item) =>
                UpcomingRepayment.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      notes: parseList(json['notes'] ?? json['reminders'])
          .whereType<Map>()
          .map((item) => LedgerNote.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      currency: parseString(json['currency'], fallback: 'INR'),
    );
  }
}

class UpcomingRepayment {
  const UpcomingRepayment({
    required this.id,
    required this.personName,
    required this.amount,
    required this.dueDate,
    required this.direction,
    this.loanId,
  });

  final String id;
  final String personName;
  final double amount;
  final DateTime dueDate;
  final String direction;
  final String? loanId;

  bool get isReceivable => direction.toLowerCase() == 'received';

  factory UpcomingRepayment.fromJson(Map<String, dynamic> json) {
    // The API may provide `person` as a string or omit it entirely. Treat it
    // as a map only when it actually is one; dynamic ['name'] indexing on a
    // non-map value throws and fails the whole dashboard summary parse.
    final person = parseMap(json['person']);
    return UpcomingRepayment(
      id: parseString(json['id'] ?? json['repayment_id']),
      personName: parseString(
        json['person_name'] ?? person?['name'],
        fallback: 'Unknown person',
      ),
      amount: parseDouble(json['amount'] ?? json['amount_inr']),
      dueDate: parseRequiredDateTime(
        json['due_date'] ?? json['dueDate'] ?? json['date'],
      ),
      direction: parseString(json['direction'], fallback: 'paid'),
      loanId: json['loan_id']?.toString(),
    );
  }
}

class LedgerNote {
  const LedgerNote({
    required this.id,
    required this.title,
    required this.body,
    this.createdAt,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool pinned;

  factory LedgerNote.fromJson(Map<String, dynamic> json) {
    return LedgerNote(
      id: parseString(json['id']),
      title: parseString(json['title'], fallback: 'Reminder'),
      body: parseString(json['body'] ?? json['message'] ?? json['text']),
      createdAt: parseDateTime(json['created_at']),
      pinned: parseBool(json['pinned']),
    );
  }
}
