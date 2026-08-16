/// Attendance: roll-call sessions and their rosters.
///
/// The reference implementation of the module shape — `data/`, `domain/`,
/// `presentation/` — and of the offline write path: marks commit to the cache
/// immediately and drain through the outbox.
library;

export 'src/data/data_sources/attendance_sources.dart';
export 'src/data/models/attendance_dtos.dart';
export 'src/data/repositories/attendance_repository_impl.dart';
export 'src/domain/entities/attendance.dart';
export 'src/domain/repositories/attendance_repository.dart';
export 'src/presentation/notifiers/attendance_notifiers.dart';
export 'src/presentation/screens/attendance_roster_screen.dart';
export 'src/presentation/screens/attendance_sessions_screen.dart';
export 'src/sync/attendance_sync_task.dart';
