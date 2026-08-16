import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';

import '../../domain/entities/attendance.dart';
import '../notifiers/attendance_notifiers.dart';

/// The roll-call roster.
///
/// The whole point of the offline stack is visible here: tapping a status
/// writes the cache and queues the request, so the row updates on the next
/// frame whether or not there is signal, and a "will send" marker distinguishes
/// saved-here from saved-on-the-server.
class AttendanceRosterScreen extends ConsumerWidget {
  const AttendanceRosterScreen({
    required this.sessionId,
    required this.title,
    this.isFinalised = false,
    super.key,
  });

  final String sessionId;
  final String title;
  final bool isFinalised;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(attendanceMarksProvider(sessionId));

    // A finalised session may only be changed by someone who can amend; an
    // open one needs the plain mark permission.
    final canMark = ref.watch(
      canProvider(
        Permission(
          Resources.attendance,
          isFinalised ? 'amend' : 'mark',
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!canMark)
            Material(
              color: context.colors.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFinalised
                            ? 'This session is finalised — only the office can '
                                  'change it.'
                            : 'You can view this roster but not change it.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: marks.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorView(
                error: error is AppException ? error.error : ApiError.fromException(error),
              ),
              data: (roster) {
                if (roster.isEmpty) {
                  return const EmptyView(
                    message: 'No students in this session',
                    icon: Icons.groups_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: roster.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _RosterRow(
                    mark: roster[index],
                    enabled: canMark,
                    onChanged: (status) => ref
                        .read(markStudentActionProvider)
                        .call(
                          sessionId: sessionId,
                          studentId: roster[index].studentId,
                          studentName: roster[index].studentName,
                          status: status,
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

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.mark,
    required this.enabled,
    required this.onChanged,
  });

  final AttendanceMark mark;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mark.studentName, style: context.text.bodyLarge),
                if (mark.isPending)
                  Text(
                    'Will send when online',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<AttendanceStatus>(
            segments: const [
              ButtonSegment(
                value: AttendanceStatus.present,
                icon: Icon(Icons.check),
                tooltip: 'Present',
              ),
              ButtonSegment(
                value: AttendanceStatus.late,
                icon: Icon(Icons.schedule),
                tooltip: 'Late',
              ),
              ButtonSegment(
                value: AttendanceStatus.absent,
                icon: Icon(Icons.close),
                tooltip: 'Absent',
              ),
              ButtonSegment(
                value: AttendanceStatus.excused,
                icon: Icon(Icons.event_busy),
                tooltip: 'Excused',
              ),
            ],
            selected: {mark.status},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: enabled ? (selection) => onChanged(selection.first) : null,
          ),
        ],
      ),
    );
  }
}
