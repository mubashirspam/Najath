import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_attendance/najath_attendance.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_sync/najath_sync.dart';

import 'app.dart';
import 'flavors.dart';

/// The single startup path.
///
/// One entrypoint rather than `main_dev.dart` / `main_prod.dart`: since Flutter
/// 3.19 the platform flavor is readable at runtime as `appFlavor`, so the
/// config comes from `--dart-define-from-file` and the flavor comes from the
/// build — a dev config in a prod build cannot masquerade as production.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == appFlavor,
    orElse: () => Flavor.dev,
  );

  final env = EnvConfig.fromDartDefines(_environmentFor(F.appFlavor));
  Env.current = env;

  // Opened here rather than lazily so the first screen never waits on the
  // database file being created.
  final database = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        envConfigProvider.overrideWithValue(env),
        appDatabaseProvider.overrideWithValue(database),
        // The engine learns about features only through this list, which is
        // what keeps `najath_sync` free of feature imports.
        syncTasksProvider.overrideWithValue(const [AttendanceSyncTask()]),
      ],
      child: const NajathApp(),
    ),
  );
}

Environment _environmentFor(Flavor flavor) => switch (flavor) {
  Flavor.dev => Environment.dev,
  Flavor.staging => Environment.staging,
  Flavor.prod => Environment.prod,
};
