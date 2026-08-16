import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_network/najath_network.dart';
import 'package:najath_sync/najath_sync.dart';

/// Everything this device has recorded but not yet sent.
///
/// Visible on purpose: a teacher who marked a roll call in a basement needs to
/// be able to check that it is still there, and to see when something has been
/// rejected rather than have it disappear.
class UnsyncedScreen extends ConsumerWidget {
  const UnsyncedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWritesProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unsynced work'),
        actions: [
          IconButton(
            tooltip: 'Try now',
            onPressed: isOnline ? () => ref.read(syncEngineProvider.notifier).run() : null,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const SyncProgressBanner(),
          Expanded(
            child: pending.when(
              loading: () => const ListSkeleton(rows: 3),
              error: (error, _) => ErrorView(error: ApiError.fromException(error)),
              data: (writes) {
                if (writes.isEmpty) {
                  return const EmptyView(
                    message: 'Everything has been sent',
                    icon: Icons.cloud_done_outlined,
                  );
                }
                return ListView.separated(
                  itemCount: writes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _WriteTile(
                    write: writes[index],
                    onDiscard: () => ref.read(outboxStoreProvider).discard(writes[index].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WriteTile extends StatelessWidget {
  const _WriteTile({required this.write, required this.onDiscard});

  final PendingWrite write;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        write.isBlocked ? Icons.error_outline : Icons.schedule,
        color: write.isBlocked ? context.colors.error : null,
      ),
      title: Text(write.label ?? write.module),
      subtitle: Text(
        write.isBlocked
            ? (write.lastError ?? 'Rejected by the server')
            : write.attempts == 0
            ? 'Waiting to send'
            : 'Retrying — ${write.attempts} attempt'
                  '${write.attempts == 1 ? '' : 's'} so far',
        style: context.text.bodySmall?.copyWith(
          color: write.isBlocked ? context.colors.error : context.colors.onSurfaceVariant,
        ),
      ),
      // Only a rejected write can be thrown away: discarding one that is merely
      // waiting would silently lose work the user believes is saved.
      trailing: write.isBlocked
          ? IconButton(
              tooltip: 'Discard',
              onPressed: onDiscard,
              icon: const Icon(Icons.delete_outline),
            )
          : null,
    );
  }
}
