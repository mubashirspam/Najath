import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';
import 'package:najath_sync/najath_sync.dart';

import '../theme/app_colors.dart';

/// Shown while the device has no transport.
///
/// Deliberately calm: offline is a normal state in a boarding academy, not an
/// error, and the app keeps working. It says what still works rather than
/// warning.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();

    final pending = ref.watch(pendingWritesProvider).value ?? const [];
    final queued = pending.where((w) => !w.isBlocked).length;

    return Material(
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                queued == 0
                    ? 'Offline — showing saved data'
                    : 'Offline — $queued change${queued == 1 ? '' : 's'} will '
                          'send when you reconnect',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live progress of the background sync pass.
class SyncProgressBanner extends ConsumerWidget {
  const SyncProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(syncEngineProvider);
    if (progress.phase == SyncPhase.idle) return const SizedBox.shrink();

    final isDone = progress.phase == SyncPhase.done;

    return Material(
      color: isDone
          ? AppColors.success.withValues(alpha: 0.12)
          : context.colors.primaryContainer.withValues(alpha: 0.5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.cloud_done_outlined : Icons.sync,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _message(progress),
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress.total > 0)
                  Text(
                    '${progress.done}/${progress.total}',
                    style: context.text.labelSmall,
                  ),
              ],
            ),
          ),
          if (progress.isActive)
            LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 2,
            ),
        ],
      ),
    );
  }

  String _message(SyncProgress progress) => switch (progress.phase) {
    SyncPhase.uploading =>
      progress.label == null ? 'Sending your changes…' : 'Sending ${progress.label}…',
    SyncPhase.downloading => progress.label == null ? 'Updating…' : 'Updating ${progress.label}…',
    SyncPhase.done => 'Everything is up to date',
    SyncPhase.failed => 'Sync could not finish',
    SyncPhase.idle => '',
  };
}

/// Shown when the app is running on registry defaults because it has never
/// managed to fetch the access policy — so a missing screen reads as "not
/// loaded yet" rather than "taken away".
class FallbackPolicyNotice extends StatelessWidget {
  const FallbackPolicyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.info.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Showing default access — connect once to load your academy '
                'settings.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
