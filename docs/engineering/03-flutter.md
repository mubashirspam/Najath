# Flutter rules

`apps/mobile/**`. One binary, three experiences (teacher, parent, warden),
resolved by role at runtime.

## 1. Layering

```
PRESENTATION   Screens · Widgets · Riverpod notifiers · Route guards
               Depends on domain only. Never sees a DTO or a drift row.
──────────────────────────────────────────────────────────────────────
DOMAIN         Entities (freezed) · Repository interfaces · UseCases
               Value objects (AyahRef, PageRange, HifzGrade)
               Pure Dart. Zero flutter, zero dio, zero drift imports.
──────────────────────────────────────────────────────────────────────
DATA           RepositoryImpl · RemoteDataSource · LocalDataSource (DAO)
               Mappers · DTOs. Owns the offline-vs-remote decision.
```

The domain layer having zero Flutter imports is checkable and gets checked: a
`import 'package:flutter/` inside `domain/` fails review. It is what lets the
hifz derivation rules be unit-tested at speed and reused anywhere.

**A feature package must not import another feature package.** Cross-feature
needs go through `najath_core` contracts or a coordinator in `app/`. If
`najath_exams` needs a student name, it does not import `najath_academics` — the
name is on the entity it already has, or it goes through core.

### Feature package layout

```
features/hifz/lib/
├── najath_hifz.dart                 barrel — the only public API
└── src/
    ├── domain/
    │   ├── entities/                hifz_log.dart · ayah_ref.dart · hifz_grade.dart
    │   ├── repositories/            hifz_repository.dart  (abstract)
    │   └── usecases/                log_daily_hifz.dart · get_batch_roster_for_today.dart
    ├── data/
    │   ├── dto/                     hifz_log_dto.dart
    │   ├── datasources/             hifz_remote_datasource.dart · hifz_local_datasource.dart
    │   ├── mappers/                 hifz_mapper.dart
    │   └── repositories/            hifz_repository_impl.dart
    └── presentation/
        ├── providers/               hifz_roster_provider.dart · hifz_log_form_controller.dart
        ├── screens/
        └── widgets/
```

Export only from the barrel. Anything under `src/` that another package needs is
either exported deliberately or does not belong there.

## 2. State management

Riverpod 2.x with `@riverpod` codegen. Three shapes, and only three:

```dart
// 1. Repository provider — the DI seam, overridden in tests
@riverpod
HifzRepository hifzRepository(Ref ref) => HifzRepositoryImpl(
      remote: ref.watch(hifzRemoteDataSourceProvider),
      local: ref.watch(hifzLocalDataSourceProvider),
      outbox: ref.watch(outboxProvider),
      connectivity: ref.watch(connectivityProvider),
    );

// 2. Read model — a STREAM FROM THE LOCAL DB, so the UI is offline-correct
//    by construction
@riverpod
Stream<List<HifzLogEntry>> batchRosterToday(Ref ref, String batchId) =>
    ref.watch(hifzRepositoryProvider).watchRoster(batchId, date: IstDate.today());

// 3. Write controller — freezed union state, never throws to the widget layer
@riverpod
class HifzLogController extends _$HifzLogController {
  @override
  HifzLogState build() => const HifzLogState.idle();

  Future<void> submit(HifzLogDraft draft) async {
    state = const HifzLogState.submitting();
    final result = await ref.read(logDailyHifzProvider)(draft);
    state = result.fold(HifzLogState.failure, HifzLogState.success);
  }
}
```

**Rules.**

- **The UI watches the local DB, never a network future.** Network results land
  in drift; drift pushes to the UI. One data path, so the offline and online
  code paths cannot diverge in behaviour.
- No provider is declared in a widget file.
- No `setState` outside a trivial animation controller.
- Every async surface is an `AsyncValue` and every screen handles
  `loading`/`error`/`data`. **No `.value!`, no `.requireValue` in a build
  method.**
- Ward-scoped providers are `family`-keyed on `studentId`, always. That is what
  stops one child's cached data appearing under a sibling when the guardian
  switches wards.

## 3. Errors

```dart
sealed class Failure with _$Failure {
  const factory Failure.network()                        = NetworkFailure;
  const factory Failure.timeout()                        = TimeoutFailure;
  const factory Failure.unauthorized()                   = UnauthorizedFailure;
  const factory Failure.forbidden(String reason)         = ForbiddenFailure;
  const factory Failure.validation(Map<String, String>)  = ValidationFailure;
  const factory Failure.conflict(ConflictPayload p)      = ConflictFailure;
  const factory Failure.notFound()                       = NotFoundFailure;
  const factory Failure.server(String code)              = ServerFailure;
  const factory Failure.unknown(Object e, StackTrace s)  = UnknownFailure;
}

typedef Result<T> = Either<Failure, T>;
```

- The **data layer** converts `DioException` and server error codes into
  `Failure`. Nothing above the data layer catches a raw exception.
- The domain layer carries no English strings. A `Failure` holds a code; the
  presentation layer maps it through `FailureMessageMapper` to a localized ARB
  string.
- `bootstrap.dart` wraps the app in `runZonedGuarded` and funnels uncaught
  errors to Crashlytics and Sentry.

## 4. Offline and sync

Two control tables plus a relational mirror of what a teacher needs for one
working day.

```dart
class SyncOutbox extends Table {
  TextColumn     get id => text()();                 // uuid v7, client-generated
  TextColumn     get entity => text()();             // 'hifz_log' | 'attendance' | …
  TextColumn     get operation => text()();          // create | update | void
  TextColumn     get payload => text()();            // json
  TextColumn     get idempotencyKey => text()();
  IntColumn      get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn     get lastError => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}

class SyncCursor extends Table {
  TextColumn     get entity => text()();
  DateTimeColumn get lastPulledAt => dateTime()();
  @override Set<Column> get primaryKey => {entity};
}
```

The mirror is **relational** — real tables with real foreign keys
(student → batch → hifz log), not a key-value blob store. Drift was chosen over
Hive precisely because these queries are joins.

| Rule                 | Detail                                                                                       |
| -------------------- | -------------------------------------------------------------------------------------------- |
| IDs                  | Client generates UUID v7. Server accepts. No temp-ID remapping.                              |
| Idempotency          | `sha256(entity + clientId + naturalKey)`. Server dedupes 7 days.                             |
| Ordering             | FIFO per entity. Cross-entity order not guaranteed, except attendance before remark.         |
| Pull                 | `?updatedSince=<cursor>` per entity, on resume and every 15 min in foreground.               |
| Conflict             | Server wins for master data. For teacher-authored logs a 409 returns both, teacher resolves. |
| Retention            | Local academic data older than 60 days pruned on launch; history fetched on demand.          |
| Auth expiry mid-sync | Outbox pauses, refresh runs, sync resumes. **Never drop the queue on a 401.**                |
| Visibility           | Persistent `N pending` chip; tapping opens the outbox inspector (also the support tool).     |

**The non-negotiable test:** a teacher logs a full day for three batches with the
network disabled, kills the app, reopens it, the network returns → zero data
loss, zero duplicates. If a change touches sync, this test runs.

## 5. Design system

`packages/design_system` owns every token. **No feature package declares a raw
`Color` or `TextStyle`.**

```dart
class HufzTokens {
  static const primary     = Color(0xFF0F5132);
  static const primarySoft = Color(0xFFE7F1EC);
  static const accent      = Color(0xFFC9A227);
  static const surface     = Color(0xFFFBFBF9);
  static const danger      = Color(0xFFB3261E);

  // Hifz semantics — the same colour means the same thing in every chart,
  // chip and calendar in the product.
  static const sabaq  = Color(0xFF0F5132);
  static const sabqi  = Color(0xFF2F7FBF);
  static const manzil = Color(0xFF7A4FBF);
  static const doura  = Color(0xFFC9A227);

  static const spacing = [4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0];
  static const radius  = (sm: 8.0, md: 12.0, lg: 20.0, pill: 999.0);
}
```

Shared widgets: `HufzScaffold`, `HufzAppBar`, `StudentTile`, `AttendanceToggle`,
`AyahRangePicker`, `ErrorCounterStepper`, `HifzGradeSelector`, `ProgressRing`,
`EmptyState`, `OfflineBanner`, `ArabicText`, `SyncStatusChip`.

**Typography.** Inter (Latin) · Manjari or NotoSansMalayalam (Malayalam) ·
KFGQPC Uthmanic Script HAFS (Quranic).

`ArabicText` is the only widget that renders Quranic content. It forces
`TextDirection.rtl`, caps font scaling at 1.3× so diacritics stay legible, and
never applies `letterSpacing` — letter spacing breaks Arabic ligatures. Rendering
an ayah with a plain `Text` is a bug.

## 6. Localization

`en`, `ml` for UI; `ar` for content. ARB files, `flutter_localizations`.

- No user-visible string literal in a widget. Ever.
- Grade labels and hifz vocabulary are localized **with a descriptor** —
  `NOT_READY` renders as "needs to repeat", not as a failure word.
- Malayalam is a first-class locale from day one, not a later pass. A screen
  that only reads well in English is unfinished.

## 7. Performance budget

| Metric                            | Target                              |
| --------------------------------- | ----------------------------------- |
| Cold start to first frame         | < 1.8 s on a 2019 mid-range Android |
| Batch roster (40 students) scroll | 60 fps, no jank frames              |
| Hifz log save (offline)           | < 100 ms perceived                  |
| Full-day outbox flush (200 ops)   | < 20 s on 3G                        |
| APK size (arm64, split)           | < 30 MB                             |

Enforced by: `ListView.builder` everywhere, `const` constructors,
`RepaintBoundary` on charts, `cached_network_image`, deferred loading of the
report/PDF modules.

## 8. Testing

| Layer                             | Tooling                       | Target          |
| --------------------------------- | ----------------------------- | --------------- |
| Domain use cases + value objects  | `flutter_test`                | 90%             |
| Repository impls (offline branch) | `mocktail` + in-memory drift  | 85%             |
| Sync engine (replay, conflict)    | deterministic fake clock      | 90%             |
| Critical screens                  | golden tests                  | key screens     |
| E2E (login, offline mark, sync)   | `patrol` on Firebase Test Lab | happy + offline |

Value objects — `AyahRef`, `PageRange`, `HifzGrade` — are where the Quran
arithmetic lives and are tested exhaustively against the bundled ayah index.
Getting "An-Nisa 12 → 18 is 7 ayah, 1.2 pages, 18 lines" wrong is invisible in
review and obvious to an Ustadh.
