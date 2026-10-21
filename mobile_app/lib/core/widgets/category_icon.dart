import 'package:flutter/material.dart';

import '../utils/color_utils.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.name,
    this.iconKey,
    this.colorHex,
    this.size = 42,
  });

  final String name;
  final String? iconKey;
  final String? colorHex;
  final double size;

  static const Map<String, IconData> _icons = {
    'food': Icons.restaurant_rounded,
    'groceries': Icons.shopping_basket_rounded,
    'rent': Icons.home_rounded,
    'utilities': Icons.bolt_rounded,
    'transport': Icons.directions_car_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'health': Icons.health_and_safety_rounded,
    'education': Icons.school_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'entertainment': Icons.movie_rounded,
    'gifts': Icons.card_giftcard_rounded,
    'salary': Icons.account_balance_wallet_rounded,
    'freelance': Icons.work_rounded,
    'business': Icons.business_center_rounded,
    'investment': Icons.trending_up_rounded,
    'savings': Icons.savings_rounded,
    'insurance': Icons.shield_rounded,
    'taxes': Icons.receipt_long_rounded,
    'loan emi': Icons.event_repeat_rounded,
    'other': Icons.category_rounded,
    'category': Icons.category_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _resolveIcon();
    final color = colorFromHex(
      colorHex ?? '#0E6B5C',
      fallback: Theme.of(context).colorScheme.primary,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }

  IconData _resolveIcon() {
    if (iconKey != null && _icons.containsKey(iconKey)) {
      return _icons[iconKey]!;
    }
    final normalized = name.toLowerCase();
    for (final entry in _icons.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return _icons['category']!;
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.color,
  });

  final String initials;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: .85),
            base.withValues(alpha: .55),
          ],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
