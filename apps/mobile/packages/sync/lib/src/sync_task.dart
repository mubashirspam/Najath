import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_core/najath_core.dart';

/// One unit of background work in the download phase.
///
/// Telios put the whole pipeline inside the engine, which meant the engine
/// imported every feature. Here features register tasks instead, so
/// `najath_sync` depends on nothing above it and a module can be added or
/// removed without touching the orchestrator.
abstract class SyncTask {
  const SyncTask();

  /// Stable id, also the key of its one-time completion marker.
  String get id;

  /// The entity this task pulls. Used as the delta-cursor key, so two tasks
  /// touching the same entity share a cursor.
  String get entity;

  /// Shown in the sync banner while this task runs.
  String get label;

  /// Lower runs first. Downloads other tasks depend on take a lower number;
  /// anything large and optional takes a higher one.
  int get order;

  /// When true, a successful run records a marker and the task is skipped on
  /// every later pass until the cache is cleared. For bulk one-time downloads —
  /// the ayah index — not for anything that changes day to day.
  bool get isOneTime => false;

  /// Does the work. Returns the server time to store as the new cursor, or a
  /// failure. Never throws: the engine cannot distinguish "this module is
  /// broken" from "the network went away" if it has to catch.
  Future<Result<DateTime?>> run(Ref ref, CancelToken cancelToken);
}

/// Tasks the app has registered, in no particular order — the engine sorts.
///
/// Overridden in `bootstrap()` with the concrete list, so the engine has no
/// compile-time knowledge of any feature.
final syncTasksProvider = Provider<List<SyncTask>>((ref) => const []);
