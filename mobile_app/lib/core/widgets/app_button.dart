import 'package:flutter/material.dart';

enum AppButtonVariant { filled, tonal, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.variant = AppButtonVariant.filled,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final AppButtonVariant variant;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveOnPressed = loading ? null : onPressed;

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: scheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    final style = destructive
        ? ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(scheme.error),
            foregroundColor: WidgetStatePropertyAll(scheme.onError),
          )
        : null;

    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
      AppButtonVariant.tonal => FilledButton.tonal(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: destructive
              ? OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                )
              : null,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: destructive
              ? TextButton.styleFrom(foregroundColor: scheme.error)
              : null,
          child: child,
        ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
