import 'package:flutter/material.dart';
import 'package:najath_core/najath_core.dart';
import 'package:shimmer/shimmer.dart';

/// Renders a [Failure] the way the product wants it read.
///
/// Offline is phrased as a normal state, not an error — in a boarding academy
/// it is the common case, and a red exclamation mark trains people to ignore
/// warnings.
class FailureView extends StatelessWidget {
  const FailureView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = failure.isOffline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.error_outline,
              size: 44,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              headline(failure),
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (offline) ...[
              const SizedBox(height: 6),
              Text(
                'This will load once you are back online.',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null && failure.isRetryable) ...[
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

  /// Placeholder copy until the ARB files land (P0-APP-09). The mapping lives
  /// here, at the presentation edge — never in the domain layer, which carries
  /// codes only.
  /// Localizable one-line copy for a failure. Public so a snackbar can reuse
  /// the same mapping as the full-page view.
  static String headline(Failure failure) => switch (failure) {
    NetworkFailure() || UnavailableOfflineFailure() => 'Not available offline yet',
    TimeoutFailure() => 'The server took too long to respond',
    UnauthorizedFailure() => 'Your session has ended',
    ForbiddenFailure() => 'You do not have access to this',
    ValidationFailure() => 'Some details need correcting',
    ConflictFailure() => 'This was changed somewhere else',
    NotFoundFailure() => 'Not found',
    ServerFailure() => 'Something went wrong at our end',
    UnknownFailure() => 'Something went wrong',
  };
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
