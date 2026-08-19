/// Background sync: drains the write outbox FIFO per entity, then runs whatever
/// download tasks the features have registered, paced so the foreground always
/// wins the connection.
library;

export 'src/delta_pull.dart';
export 'src/sync_engine.dart';
export 'src/sync_task.dart';
