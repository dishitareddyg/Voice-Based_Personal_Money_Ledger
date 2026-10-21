import 'json_utils.dart';
import 'transaction_type.dart';

class Loan {
  const Loan({
    required this.id,
    required this.kind,
    required this.personId,
    required this.personName,
    required this.principalAmountInr,
    required this.outstandingAmountInr,
    required this.startDate,
    this.interestRate = 0,
    this.interestType = InterestType.simple,
    this.dueDate,
    this.status = 'open',
    this.description = '',
  });

  final String id;
  final LoanKind kind;
  final String personId;
  final String personName;
  final double principalAmountInr;
  final double outstandingAmountInr;
  final DateTime startDate;
  final double interestRate;
  final InterestType interestType;
  final DateTime? dueDate;
  final String status;
  final String description;

  bool get isOpen => status.toLowerCase() != 'closed';
  bool get isOverdue =>
      isOpen && dueDate != null && dueDate!.isBefore(DateTime.now());

  double get repaidAmount =>
      (principalAmountInr - outstandingAmountInr).clamp(0, principalAmountInr);

  double get progress {
    if (principalAmountInr <= 0) return 0;
    return (repaidAmount / principalAmountInr).clamp(0.0, 1.0);
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    final person = parseMap(json['person']);
    return Loan(
      id: parseString(json['id'] ?? json['loan_id']),
      kind: LoanKind.parse(
        json['kind'] ?? json['loan_type'] ?? json['type'],
      ),
      personId: json['person_id']?.toString() ??
          (person == null ? '' : parseString(person['id'])),
      personName: parseString(
        json['person_name'] ?? (person == null ? null : person['name']),
        fallback: 'Unknown person',
      ),
      principalAmountInr: parseDouble(
        json['principal_amount_inr'] ??
            json['principal_amount'] ??
            json['amount_inr'],
      ),
      outstandingAmountInr: parseDouble(
        json['outstanding_amount_inr'] ??
            json['outstanding_amount'] ??
            json['outstanding'],
      ),
      startDate: parseRequiredDateTime(
        json['start_date'] ?? json['created_at'],
      ),
      interestRate: parseDouble(json['interest_rate']),
      interestType: InterestType.parse(json['interest_type']),
      dueDate: parseDateTime(json['due_date']),
      status: parseString(json['status'], fallback: 'open'),
      description: parseString(json['description'] ?? json['notes']),
    );
  }
}
