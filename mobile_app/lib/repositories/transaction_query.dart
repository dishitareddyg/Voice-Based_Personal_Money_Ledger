import '../models/transaction_type.dart';

/// Filters applied when listing transactions. Sent to the Raspberry Pi as query
/// parameters; the server remains the authority on what is returned.
class TransactionQuery {
  const TransactionQuery({
    this.page = 1,
    this.pageSize = 25,
    this.type,
    this.search,
    this.from,
    this.to,
    this.personId,
    this.categoryId,
  });

  final int page;
  final int pageSize;
  final TransactionType? type;
  final String? search;
  final DateTime? from;
  final DateTime? to;
  final String? personId;
  final String? categoryId;

  TransactionQuery copyWith({
    int? page,
    int? pageSize,
    TransactionType? type,
    bool clearType = false,
    String? search,
    DateTime? from,
    DateTime? to,
    String? personId,
    String? categoryId,
  }) {
    return TransactionQuery(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      type: clearType ? null : (type ?? this.type),
      search: search ?? this.search,
      from: from ?? this.from,
      to: to ?? this.to,
      personId: personId ?? this.personId,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'page_size': pageSize,
        if (type != null) 'type': type!.apiValue,
        if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
        if (from != null) 'from': _formatDate(from!),
        if (to != null) 'to': _formatDate(to!),
        if (personId != null) 'person_id': personId,
        if (categoryId != null) 'category_id': categoryId,
      };

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
