import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';

import '../../domain/entities/attendance.dart';
import '../notifiers/attendance_notifiers.dart';

/// Sessions list — the attendance module's entry point.
class AttendanceSessionsScreen extends ConsumerWidget {
  const AttendanceSessionsScreen({this.onOpenSession, super.key});

  final void Function(AttendanceSession session)? onOpenSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(attendanceSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: sessions.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorView(
                error: error is AppException ? error.error : ApiError.fromException(error),
                onRetry: () => ref.read(attendanceSessionsProvider.notifier).refresh(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyView(
                    message: 'No attendance sessions yet',
                    icon: Icons.event_available_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(attendanceSessionsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _SessionCard(
                      session: items[index],
                      onTap: onOpenSession == null ? null : () => onOpenSession!(items[index]),
                    ),
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.onTap});

  final AttendanceSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.className,
                      style: context.text.titleMedium,
                    ),
                  ),
                  if (session.isFinalised)
                    const Chip(
                      label: Text('Finalised'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat.yMMMEd().format(session.date)} · '
                '${session.period}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: session.completion,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Text(
                '${session.markedCount} of ${session.studentCount} marked',
                style: context.text.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
