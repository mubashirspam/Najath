import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';

import '../../domain/entities/attendance.dart';
import '../providers/attendance_providers.dart';

/// The roll-call roster — the whole offline stack, visible.
///
/// Everyone defaults to present, so a class of forty with three absentees is
/// three taps. Each tap writes SQLite and queues the request, so the row
/// updates on the next frame whether or not there is signal, and a "will send"
/// marker distinguishes saved-here from saved-on-the-server.
class AttendanceRosterScreen extends ConsumerWidget {
  const AttendanceRosterScreen({
    required this.batchId,
    required this.date,
    required this.title,
    this.session = AttendanceSession.fullDay,
    super.key,
  });

  final String batchId;
  final String date;
  final String title;
  final AttendanceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = RosterKey(batchId: batchId, date: date, session: session);
    final roster = ref.watch(rosterProvider(key));
    final tally = ref.watch(rosterTallyProvider(key));

    // A teacher marks their own batches; correcting a finalised session needs
    // `attendance:update`, which the office holds.
    final canMark = ref.watch(
      canProvider(const Permission(Resources.attendance, 'create')),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!canMark) const _ReadOnlyNotice(),
          Expanded(
            child: roster.when(
              loading: () => const ListSkeleton(),
              error: (error, stack) => FailureView(
                failure: error is Failure ? error : Failure.unknown(error, stack),
                onRetry: () => ref.invalidate(rosterProvider(key)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return EmptyView(
                    message: context.l10n.attendanceNoStudents,
                    icon: Icons.groups_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _RosterRowTile(
                    entry: entries[index],
                    enabled: canMark,
                    onChanged: (status) => ref
                        .read(markAttendanceProvider)
                        .call(
                          key: key,
                          enrollmentId: entries[index].enrollmentId,
                          status: status,
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomSheet: roster.hasValue ? _TallyFooter(tally: tally) : null,
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.visibility_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.attendanceReadOnly,
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterRowTile extends StatelessWidget {
  const _RosterRowTile({
    required this.entry,
    required this.enabled,
    required this.onChanged,
  });

  final AttendanceEntry entry;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              entry.rollNo ?? '',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.studentName, style: context.text.bodyLarge),
                if (entry.isPending)
                  Text(
                    context.l10n.attendanceWillSend,
                    style: context.text.labelSmall?.copyWith(
                      color: HufzTokens.warning,
                    ),
                  )
                else if (!entry.isMarked)
                  Text(
                    context.l10n.attendanceNotMarked,
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AttendanceToggle<AttendanceStatus>(
            value: entry.status,
            options: AttendanceStatus.markable,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TallyFooter extends StatelessWidget {
  const _TallyFooter({required this.tally});

  final RosterTally tally;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Count(
                label: context.l10n.attendancePresent,
                value: tally.present,
                color: HufzTokens.present,
              ),
              _Count(
                label: context.l10n.attendanceAbsent,
                value: tally.absent,
                color: HufzTokens.absent,
              ),
              _Count(
                label: context.l10n.attendanceLate,
                value: tally.late,
                color: HufzTokens.late,
              ),
              const Spacer(),
              Text(
                context.l10n.attendanceMarkedOfTotal(tally.marked, tally.total),
                style: context.text.labelLarge?.copyWith(
                  color: tally.isComplete ? HufzTokens.present : context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: context.text.titleMedium?.copyWith(color: color)),
          Text(label, style: context.text.labelSmall),
        ],
      ),
    );
  }
}
