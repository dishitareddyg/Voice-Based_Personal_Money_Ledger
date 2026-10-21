import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import 'app_button.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading your ledger...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 58 : 72,
              height: compact ? 58 : 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 34,
                color: scheme.onPrimaryContainer,
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: compact ? 190 : 220,
                child: AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.tonal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = friendlyErrorMessage(error);
    final isNetwork = error is AppException &&
        (error as AppException).kind == AppErrorKind.network;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: .6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                color: scheme.onErrorContainer,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isNetwork ? 'Cannot reach your ledger' : 'Something went wrong',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 190,
                child: AppButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  variant: AppButtonVariant.tonal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.loadingMessage = 'Loading...',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;
  final String loadingMessage;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading && !value.hasValue) {
      return LoadingView(message: loadingMessage);
    }
    if (value.hasError && !value.hasValue) {
      return ErrorView(error: value.error!, onRetry: onRetry);
    }
    final resolved = value.valueOrNull;
    if (resolved == null) {
      return LoadingView(message: loadingMessage);
    }
    if (isEmpty?.call(resolved) == true) {
      return empty ?? const SizedBox.shrink();
    }
    return data(resolved);
  }
}
