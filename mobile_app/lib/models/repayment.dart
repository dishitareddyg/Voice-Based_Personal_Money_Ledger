import 'json_utils.dart';
import 'transaction_type.dart';

class Repayment {
  const Repayment({
    required this.id,
    required this.loanId,
    required this.personName,
    required this.amountInr,
    required this.paymentDate,
    required this.direction,
    this.notes = '',
    this.status = 'completed',
  });

  final String id;
  final String loanId;
  final String personName;
  final double amountInr;
  final DateTime paymentDate;
  final RepaymentDirection direction;
  final String notes;
  final String status;

  factory Repayment.fromJson(Map<String, dynamic> json) {
    final person = parseMap(json['person']);
    final loan = parseMap(json['loan']);
    return Repayment(
      id: parseString(json['id'] ?? json['repayment_id']),
      loanId: parseString(json['loan_id'] ?? (loan == null ? null : loan['id'])),
      personName: parseString(
        json['person_name'] ?? (person == null ? null : person['name']),
        fallback: 'Unknown person',
      ),
      amountInr: parseDouble(json['amount_inr'] ?? json['amount']),
      paymentDate: parseRequiredDateTime(
        json['payment_date'] ?? json['date'] ?? json['transaction_date'],
      ),
      direction: RepaymentDirection.tryParse(json['direction']) ??
          RepaymentDirection.received,
      notes: parseString(json['notes'] ?? json['description']),
      status: parseString(json['status'], fallback: 'completed'),
    );
  }
}
