import 'json_utils.dart';
import 'transaction_type.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.colorHex = '#0E6B5C',
    this.iconKey = 'category',
    this.isDefault = false,
    this.transactionCount = 0,
    this.totalAmount = 0,
  });

  final String id;
  final String name;
  final TransactionType type;
  final String colorHex;
  final String iconKey;
  final bool isDefault;
  final int transactionCount;
  final double totalAmount;

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] ?? json['category_type'];
    return Category(
      id: parseString(json['id'] ?? json['category_id']),
      name: parseString(json['name'], fallback: 'Uncategorised'),
      type: rawType == null
          ? TransactionType.expense
          : TransactionType.parse(rawType),
      colorHex: parseString(json['color_hex'] ?? json['color'], fallback: '#0E6B5C'),
      iconKey: parseString(json['icon'] ?? json['icon_key'], fallback: 'category'),
      isDefault: parseBool(json['is_default'] ?? json['isDefault']),
      transactionCount: parseInt(
        json['transaction_count'] ?? json['transactionCount'],
      ),
      totalAmount: parseDouble(json['total_amount'] ?? json['totalAmount']),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'type': type.apiValue,
        'color_hex': colorHex,
        'icon': iconKey,
      };
}

class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.percentage,
    this.colorHex = '#0E6B5C',
    this.iconKey = 'category',
  });

  final String categoryId;
  final String name;
  final double amount;
  final double percentage;
  final String colorHex;
  final String iconKey;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      categoryId: parseString(json['category_id'] ?? json['categoryId']),
      name: parseString(json['name'] ?? json['category_name'], fallback: 'Other'),
      amount: parseDouble(json['amount'] ?? json['amount_inr'] ?? json['total']),
      percentage: parseDouble(json['percentage'] ?? json['percent']),
      colorHex: parseString(json['color_hex'] ?? json['color'], fallback: '#0E6B5C'),
      iconKey: parseString(json['icon'], fallback: 'category'),
    );
  }
}
