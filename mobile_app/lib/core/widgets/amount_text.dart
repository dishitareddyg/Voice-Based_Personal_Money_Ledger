import 'package:flutter/material.dart';

import '../utils/inr_formatter.dart';

class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    this.color,
    this.hidden = false,
    this.style,
    this.signed = false,
    this.showDecimals = true,
  });

  final num amount;
  final Color? color;
  final bool hidden;
  final TextStyle? style;
  final bool signed;
  final bool showDecimals;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            );
    if (hidden) {
      return Text(
        '₹ ••••••',
        style: resolvedStyle,
        semanticsLabel: 'Amount hidden',
      );
    }
    final prefix = signed && amount > 0 ? '+' : '';
    return Text(
      '$prefix${InrFormatter.format(amount)}',
      style: resolvedStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
