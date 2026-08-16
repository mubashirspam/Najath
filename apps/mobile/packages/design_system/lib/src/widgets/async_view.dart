import 'package:flutter/material.dart';
import 'package:najath_core/najath_core.dart';
import 'package:shimmer/shimmer.dart';

/// Renders the three states of an `AsyncValue` consistently across features.
///
/// Without this every screen invents its own spinner and error card, and an
/// offline miss ends up looking like a crash.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.emptyMessage,
    this.isEmpty,
    super.key,
  });

  final AsyncSnapshotLike<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final String? emptyMessage;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading) {
      return loading ?? const ListSkeleton();
    }
    if (value.error != null) {
      return ErrorView(error: value.error!, onRetry: onRetry);
    }
    final result = value.data as T;
    if (isEmpty?.call(result) ?? false) {
      return EmptyView(message: emptyMessage ?? 'Nothing here yet');
    }
    return data(result);
  }
}

/// Minimal view model so this widget does not depend on a specific async type.
class AsyncSnapshotLike<T> {
  const AsyncSnapshotLike({this.data, this.error, this.isLoading = false});

  final T? data;
  final ApiError? error;
  final bool isLoading;
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final ApiError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isOffline = error.isNetworkError || error.isOffline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.cloud_off_outlined : Icons.error_outline,
              size: 44,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              error.message,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (isOffline) ...[
              const SizedBox(height: 6),
              Text(
                'This will load once you are back online.',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 44,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows while a list loads. Sized like the real content so the
/// layout does not jump when data arrives.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.rows = 6, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withValues(alpha: 0.4),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 64,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
