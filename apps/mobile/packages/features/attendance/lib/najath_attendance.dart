/// Attendance: department-scoped roll call, offline-first.
///
/// The reference implementation of the module shape — `data/`, `domain/`,
/// `presentation/` — and of the offline write path: a mark commits to the local
/// mirror immediately and drains through the outbox.
library;

export 'src/data/dto/attendance_dto.dart';
export 'src/data/repositories/attendance_repository_impl.dart';
export 'src/domain/entities/attendance.dart';
export 'src/domain/repositories/attendance_repository.dart';
export 'src/presentation/providers/attendance_providers.dart';
export 'src/presentation/screens/attendance_roster_screen.dart';
export 'src/sync/attendance_sync_task.dart';
