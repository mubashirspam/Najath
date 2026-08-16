/// On-device storage.
///
/// A **relational** mirror of what a teacher needs for one working day — real
/// tables, real foreign keys, joins done in SQLite — plus the outbox of writes
/// that have not reached the server and the per-entity delta cursors.
library;

export 'package:drift/drift.dart' show Value;

export 'src/daos/attendance_dao.dart';
export 'src/daos/roster_dao.dart';
export 'src/database.dart';
export 'src/outbox_store.dart';
