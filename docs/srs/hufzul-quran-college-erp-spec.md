# Hufzul Quran College — ERP Platform

## Technical Project Specification & Architecture Reference

|                   |                                                                       |
| ----------------- | --------------------------------------------------------------------- |
| **Document**      | Project Specification v1.0                                            |
| **Product**       | Hufzul Quran College ERP                                              |
| **Clients**       | Admin (Web) · Teacher (Mobile) · Parent (Mobile)                      |
| **Mobile Stack**  | Flutter 3.24+ / Dart 3.5+                                             |
| **Backend Stack** | Next.js 15 (App Router) · Neon Postgres · Drizzle ORM · Better Auth   |
| **Status**        | Pre-development reference — to be converted into sprint-level tickets |

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Scope, Clients & Roles](#2-scope-clients--roles)
3. [RBAC Matrix](#3-rbac-matrix)
4. [Technology Stack](#4-technology-stack)
5. [System Architecture](#5-system-architecture)
6. [Repository Structure](#6-repository-structure)
7. [Flutter Application Architecture](#7-flutter-application-architecture)
8. [Backend Architecture & API Conventions](#8-backend-architecture--api-conventions)
9. [Domain Model & Database Schema](#9-domain-model--database-schema)
10. [Module Specifications](#10-module-specifications)
11. [Reporting & Analytics](#11-reporting--analytics)
12. [Non-Functional Requirements](#12-non-functional-requirements)
13. [Delivery Phases](#13-delivery-phases)
14. [Open Questions for Client](#14-open-questions-for-client)
15. [Appendix](#15-appendix)

---

## 1. Project Overview

### 1.1 Context

Hufzul Quran College operates three academic departments under one institution:

1. **Department of Hifz & Doura** — Quran memorization, tracked daily per student via Sabaq / Sabqi / Manzil / Doura.
2. **Department of Islamic Studies** — conventional class + subject + timetable model.
3. **Department of General Education** — conventional class + subject + timetable model.

A student is enrolled in **one or more departments simultaneously** (typical: Hifz in the morning, General Education in the afternoon). This is the single most important structural fact in the system and it drives the schema: attendance, timetable, assessment and progress reporting are all **department-scoped**, never global.

### 1.2 Product Goal

Replace the current paper register workflow with:

- A **teacher-first mobile app** that works offline in classrooms/halaqa with poor connectivity, where the daily Hifz log takes < 20 seconds per student.
- A **parent mobile app** that gives guardians visibility into presence, conduct, leave, hostel and institutional communication.
- A **student mobile app** that gives the student ownership of their own academic and memorization performance.
- An **admin web console** for master data, staff, exams, hostel, canteen, finance-adjacent records and reporting.

### 1.3 Design Principles

| Principle                                         | Implication                                                                                                                                                             |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Offline-first for teachers**                    | Every write from the Teacher app is queued locally and synced; the app is fully usable in airplane mode for a full day.                                                 |
| **Append-only academic ledger**                   | Hifz logs, attendance marks and mark entries are never hard-deleted. Corrections create a new revision row with `supersedes_id`. Gives a full audit trail for disputes. |
| **Department-scoped everything**                  | No API returns "the student's attendance" — it returns attendance for a `(student, department, date range)` tuple.                                                      |
| **Single Flutter binary, role-driven shell**      | One app, three experiences. See §7.2 for rationale.                                                                                                                     |
| **Server is the source of truth for computation** | Percentages, grades, ranks, progress deltas are computed server-side. Clients render, never calculate.                                                                  |
| **Bilingual from day one**                        | English + Malayalam UI, Arabic content rendering (Surah names, ayah text) with correct RTL and Uthmani font.                                                            |

---

## 2. Scope, Clients & Roles

### 2.1 Clients

| Client            | Platform                        | Primary Users                                                                        | Tech                   |
| ----------------- | ------------------------------- | ------------------------------------------------------------------------------------ | ---------------------- |
| **Admin Console** | Web (desktop-first, responsive) | Principal, Office Admin, Department Head, Hostel Warden, Canteen Manager, Accountant | Next.js 15 + shadcn/ui |
| **Teacher App**   | Android + iOS                   | Hifz teachers (Ustadh), subject teachers, class teachers                             | Flutter                |
| **Parent App**    | Android + iOS                   | Guardians (may have multiple wards)                                                  | Flutter                |

There is **no student-facing app**. Students do not receive logins; guardians are the sole channel for student-facing information. See §2.3.

The two mobile experiences ship as **one Flutter application** with a role-resolved shell. See §7.2.

### 2.2 Role Definitions

```
SUPER_ADMIN      Full system access, tenant settings, role assignment, data export
ADMIN            Office administration — admissions, master data, reports
DEPT_HEAD        Scoped to one department — academics, staff assignment, approvals
TEACHER          Assigned batches/classes only — attendance, hifz log, marks, remarks
HOSTEL_WARDEN    Hostel module + hostel attendance + hostel leave (gate pass)
CANTEEN_MANAGER  Canteen module only
ACCOUNTANT       Read-only academic; full canteen billing / fee-adjacent records
PARENT           Own wards only — full academic, hifz, conduct, leave, communication
```

**Role assignment is many-to-many.** A `DEPT_HEAD` is usually also a `TEACHER`. A `TEACHER` may also be a `PARENT` of a student in the same college. The auth model must support a user holding multiple roles and switching context in the mobile app without logging out.

### 2.3 Parent Visibility — Policy Decision

Per client direction, **there is no separate Student role or student app.** The guardian is the single consumer of all student-facing information, and the Parent app therefore carries the **full** academic and memorization dataset — not a summary view.

| Data                                                                                   | Parent App                                                    |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Daily Hifz log (Sabaq/Sabqi/Manzil line-level, ranges, error counts, teacher grade)    | ✅ Full detail                                                |
| Hifz progress — juz map, pages memorized, quality index, doura status, projected khatm | ✅ Full detail                                                |
| Subject-wise marks, grade, class average, rank                                         | ✅ Full detail (post-publish)                                 |
| Attendance detail (period-wise, late marks, percentage)                                | ✅ Full detail                                                |
| Timetable, homework, syllabus progress                                                 | ✅ Full detail                                                |
| Leave records                                                                          | ✅ View + request on behalf of ward                           |
| Teacher remarks & conduct notes                                                        | ✅ All remarks, including those flagged `share_with_guardian` |
| Published Progress Report PDF                                                          | ✅                                                            |
| Hostel status, gate pass, roll-call history                                            | ✅                                                            |
| Canteen menu, meal record, wallet ledger                                               | ✅                                                            |
| Announcements & circulars                                                              | ✅                                                            |

**Consequences of dropping the student role — read these before building:**

1. `students.user_id` is **not** provisioned. A student has no `users` row and no credentials. The `user_id` column is retained as nullable for a possible future alumni/student portal but must never be populated in Phase 1–4.
2. Every "own record" scope in the RBAC engine resolves through `student_guardians`, never through `students.user_id`. There is exactly one path to student data for a non-staff user: guardianship.
3. Notifications that would have gone to a student (result published, hifz milestone, homework due) are routed to **all guardians with `is_primary = true`**, and optionally to secondary guardians per a per-student notification preference.
4. The `visible_to` array on activities and remarks collapses to `{PARENT}` — the `STUDENT` value is removed from the enum.
5. Rank and class-average visibility becomes a single institution setting `showRankToParents` (default `false`), since parents are now the only audience.

> **Implementation note:** the setting `parent_performance_visibility: 'summary' | 'full' | 'report_card_only'` is retained in the settings table and defaults to **`'full'`**. Keep the switch — an institution that later restricts what guardians see should not require a code change — but the shipped default and all Phase 1 UI assume `'full'`. Visibility is enforced **server-side in the query layer**, not by hiding widgets in Flutter.

---

## 3. RBAC Matrix

Legend: **C** create · **R** read · **U** update · **D** delete/void · **A** approve · **—** no access

| Module                          | SUPER_ADMIN | ADMIN | DEPT_HEAD   | TEACHER                        | WARDEN        | PARENT      |
| ------------------------------- | ----------- | ----- | ----------- | ------------------------------ | ------------- | ----------- |
| Users & Roles                   | CRUD        | CR    | R           | —                              | —             | —           |
| Students (master)               | CRUD        | CRUD  | R           | R (assigned)                   | R (residents) | R (ward)    |
| Staff (master)                  | CRUD        | CRUD  | R U (dept)  | R (self)                       | —             | —           |
| Departments / Batches / Classes | CRUD        | CRUD  | RU (own)    | R                              | —             | —           |
| Timetable                       | CRUD        | CRUD  | CRUD (own)  | R                              | —             | R           |
| Attendance                      | CRUD        | CRUD  | RU (own)    | CRU (assigned, same-day)       | CRU (hostel)  | R (ward)    |
| Hifz Daily Log                  | R D         | R     | RU (own)    | CRU (assigned)                 | —             | R (summary) |
| Doura Records                   | R D         | R     | CRU (own)   | CRU (assigned)                 | —             | R (summary) |
| Exams & Question Papers         | CRUD        | CRUD  | CRUD (own)  | CRU (assigned subject)         | —             | —           |
| Marks Entry                     | R           | R     | RUA (own)   | CRU (own subject, pre-publish) | —             | —           |
| Result Publish                  | A           | A     | A (own)     | —                              | —             | R           |
| Progress Report                 | CRUD        | CR    | CRA (own)   | C (draft, remarks)             | —             | R           |
| Daily Activities                | R           | R     | R           | CRU (assigned)                 | CRU (hostel)  | R           |
| Leave                           | CRUDA       | CRUDA | A (dept)    | CA (own class) + C (self)      | A (hostel)    | C (ward)    |
| Hostel                          | CRUD        | CRUD  | R           | R                              | CRUD          | R (ward)    |
| Canteen                         | CRUD        | CRUD  | —           | —                              | R             | R + ledger  |
| Announcements                   | CRUD        | CRUD  | CRUD (dept) | C (class)                      | C (hostel)    | R           |
| Reports & Export                | All         | All   | Dept        | Own classes                    | Hostel        | Ward        |

---

## 4. Technology Stack

### 4.1 Mobile — Flutter

| Concern               | Choice                                          | Why                                                                                                                                                                                         |
| --------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Framework             | Flutter 3.24+ / Dart 3.5+                       | Single codebase, three role experiences                                                                                                                                                     |
| State management      | **Riverpod 2.x** (`@riverpod` codegen)          | Compile-safe DI, easy override in tests, no `BuildContext` coupling for background sync. BLoC is acceptable if the team standard demands it — keep the layer boundary identical either way. |
| Immutability / unions | `freezed` + `json_serializable`                 | Sealed state classes, exhaustive `when` on sync/failure states                                                                                                                              |
| Routing               | `go_router`                                     | Declarative, deep-link ready for push notifications (`/hifz/log/:studentId`)                                                                                                                |
| Networking            | `dio` + `retrofit` + interceptors               | Retry, refresh-token, request signing, offline queue interception                                                                                                                           |
| Local DB              | **`drift`** (SQLite)                            | Relational offline mirror + typed queries + migrations. Chosen over Isar/Hive because the offline data is genuinely relational (student → batch → hifz log).                                |
| Secure storage        | `flutter_secure_storage`                        | Refresh token, device key                                                                                                                                                                   |
| KV / prefs            | `shared_preferences`                            | Non-sensitive UI prefs                                                                                                                                                                      |
| Connectivity          | `connectivity_plus` + reachability ping         | Trigger sync on network regain                                                                                                                                                              |
| Background sync       | `workmanager` (Android) / BGTaskScheduler (iOS) | Flush outbox when app is backgrounded                                                                                                                                                       |
| Push                  | `firebase_messaging` + local notifications      | Attendance alerts, leave approvals, result publish                                                                                                                                          |
| Charts                | `fl_chart`                                      | Hifz progress curve, attendance rings                                                                                                                                                       |
| PDF view/share        | `syncfusion_flutter_pdfviewer` / `printing`     | Progress report card                                                                                                                                                                        |
| Localization          | `flutter_localizations` + ARB                   | `en`, `ml`, `ar` (content)                                                                                                                                                                  |
| Arabic typography     | Bundled **KFGQPC Uthmanic Script HAFS**         | Correct ayah rendering                                                                                                                                                                      |
| Analytics / crash     | Firebase Analytics + Crashlytics + Sentry       |                                                                                                                                                                                             |
| Env / flavors         | `--dart-define-from-file` + 3 flavors           | `dev`, `staging`, `prod`                                                                                                                                                                    |
| Testing               | `flutter_test`, `mocktail`, `patrol`            | Unit, widget, integration                                                                                                                                                                   |

### 4.2 Backend

| Concern             | Choice                                                                     |
| ------------------- | -------------------------------------------------------------------------- |
| Runtime / framework | Next.js 15 App Router — Route Handlers under `/api/v1`                     |
| Language            | TypeScript (strict)                                                        |
| Database            | Neon Postgres (serverless, branch-per-PR)                                  |
| ORM                 | Drizzle ORM + `drizzle-kit` migrations                                     |
| Auth                | Better Auth — session cookies for web, **bearer JWT + refresh for mobile** |
| Validation          | Zod schemas shared via `packages/contracts`                                |
| API docs            | `zod-to-openapi` → OpenAPI 3.1 → Dart client via `openapi-generator`       |
| File storage        | Cloudflare R2 (S3-compatible) with presigned uploads                       |
| Background jobs     | Trigger.dev v3 — report generation, nightly rollups, push fan-out          |
| PDF generation      | React-PDF (server) for report cards & question papers                      |
| Caching             | Neon read replica + `unstable_cache` for master data                       |
| Messaging           | FCM (push) + WhatsApp Cloud API (circulars, optional)                      |
| Admin UI            | shadcn/ui + TanStack Table + Recharts                                      |
| Hosting             | Vercel (web/API) + Neon + R2                                               |
| Observability       | Axiom / Better Stack logs, Sentry, Vercel Analytics                        |

### 4.3 Tooling

- **pnpm workspaces + Turborepo** for the web/API side
- **Melos** for the Flutter multi-package workspace
- **GitHub Actions**: lint → test → build → Fastlane (Play Internal / TestFlight)
- **Conventional commits** + semantic release for app version codes

---

## 5. System Architecture

### 5.1 High-Level

```text
       ┌──────────────┐       ┌──────────────┐       ┌──────────────────┐
       │ Teacher App  │       │  Parent App  │       │  Admin Console   │
       │  (Flutter)   │       │  (Flutter)   │       │   (Next.js)      │
       └──────┬───────┘       └──────┬───────┘       └────────┬─────────┘
              │  REST/JSON + JWT     │                        │ RSC + Server Actions
              └──────────┬───────────┘                        │
                         ▼                                     ▼
          ┌─────────────────────────────────────────────────────────┐
          │           API Layer  ·  Next.js Route Handlers           │
          │  /api/v1/*   Zod validation → RBAC guard → Service       │
          └───────────────┬──────────────────────┬──────────────────┘
                          ▼                      ▼
              ┌───────────────────────┐  ┌────────────────────┐
              │   Domain Services     │  │  Better Auth       │
              │  hifz, attendance,    │  │  sessions, JWT,    │
              │  exam, hostel, leave  │  │  org/roles         │
              └──────────┬────────────┘  └─────────┬──────────┘
                         ▼                          ▼
              ┌────────────────────────────────────────────────┐
              │      Drizzle ORM  →  Neon Postgres             │
              └────────────────────────────────────────────────┘
                         │                    │
                         ▼                    ▼
                ┌─────────────────┐  ┌──────────────────┐
                │ Cloudflare R2   │  │  Trigger.dev     │
                │ docs, photos,   │  │  rollups, PDFs,  │
                │ report PDFs     │  │  push fan-out    │
                └─────────────────┘  └──────────────────┘
```

### 5.2 Request Pipeline (server)

```
Request
  → Rate limiter (per IP + per user)
  → Auth resolver (session cookie | bearer JWT)
  → Tenant/academic-year context injection
  → Zod input parse
  → RBAC policy guard  (role × resource × scope)
  → Service layer (pure, testable, Drizzle-injected)
  → Response envelope + audit log write
```

Every mutating endpoint accepts an **`Idempotency-Key`** header. This is not optional — it is what makes offline replay from the Flutter outbox safe.

### 5.3 Data Flow — Offline Write (Teacher app)

```
Teacher marks Sabaq for 18 students, no network
  → write to drift `hifz_daily_log` (local, status: PENDING)
  → append to drift `sync_outbox` (op, payload, idempotency_key, attempt)
  → UI reads local table immediately → instant feedback
Network returns
  → SyncEngine drains outbox FIFO, grouped by entity
  → POST /api/v1/hifz/logs/batch  with Idempotency-Key
  → 200 → mark rows SYNCED, store server id + version
  → 409 conflict → surface a resolution card (server value vs local value)
  → 5xx / timeout → exponential backoff, max 5 attempts, then manual retry banner
```

---

## 6. Repository Structure

### 6.1 Monorepo Root

```text
hufzul-erp/
├── apps/
│   ├── web/                    # Next.js 15 — admin console + /api/v1
│   └── mobile/                 # Flutter workspace (melos)
├── packages/
│   ├── db/                     # Drizzle schema, migrations, seed
│   ├── contracts/              # Zod schemas + generated OpenAPI
│   ├── core/                   # domain services, pure business rules
│   ├── auth/                   # Better Auth config, RBAC policies
│   ├── jobs/                   # Trigger.dev task definitions
│   └── ui/                     # shared React components
├── docs/
│   ├── srs/                    # this document + module SRS
│   ├── adr/                    # architecture decision records
│   └── api/                    # openapi.yaml
├── turbo.json
└── pnpm-workspace.yaml
```

### 6.2 Flutter Workspace

```text
apps/mobile/
├── melos.yaml
├── app/                              # the shipped application
│   ├── lib/
│   │   ├── main_dev.dart
│   │   ├── main_staging.dart
│   │   ├── main_prod.dart
│   │   ├── bootstrap.dart            # DI, error zone, hydration
│   │   └── app.dart                  # MaterialApp.router + role shell
│   └── pubspec.yaml
├── packages/
│   ├── core/                         # Result, failures, extensions, typedefs
│   ├── design_system/                # tokens, theme, Hufz* widgets, Arabic text
│   ├── network/                      # dio client, interceptors, api exceptions
│   ├── local_db/                     # drift database, DAOs, migrations
│   ├── sync/                         # outbox, sync engine, conflict policy
│   ├── auth/                         # login, session, role context switching
│   └── features/
│       ├── attendance/
│       ├── hifz/
│       ├── academics/
│       ├── exams/
│       ├── progress/
│       ├── leave/
│       ├── hostel/
│       ├── canteen/
│       ├── activities/
│       ├── announcements/
│       └── profile/
└── tool/                             # codegen, l10n, icon scripts
```

Each feature package is a self-contained Clean Architecture slice and **must not import another feature package**. Cross-feature needs go through `core` contracts or a coordinator in `app/`.

---

## 7. Flutter Application Architecture

### 7.1 Layering (Clean Architecture)

```text
┌─────────────────────────────────────────────────────────────┐
│ PRESENTATION                                                │
│   Screens · Widgets · Riverpod Notifiers · Route guards      │
│   Depends on: Domain only. Never sees a DTO or a Drift row.  │
├─────────────────────────────────────────────────────────────┤
│ DOMAIN                                                       │
│   Entities (freezed) · Repository interfaces · UseCases      │
│   Value objects (AyahRef, PageRange, HifzGrade)              │
│   Pure Dart. Zero Flutter, zero dio, zero drift imports.     │
├─────────────────────────────────────────────────────────────┤
│ DATA                                                         │
│   RepositoryImpl · RemoteDataSource (retrofit)               │
│   LocalDataSource (drift DAO) · Mappers · DTOs               │
│   Owns the offline-vs-remote decision.                       │
└─────────────────────────────────────────────────────────────┘
```

**Feature package internal layout:**

```text
features/hifz/
├── lib/
│   ├── hifz.dart                          # barrel — only public API
│   └── src/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── hifz_log.dart
│       │   │   ├── ayah_ref.dart
│       │   │   └── hifz_grade.dart
│       │   ├── repositories/hifz_repository.dart
│       │   └── usecases/
│       │       ├── log_daily_hifz.dart
│       │       ├── get_batch_roster_for_today.dart
│       │       └── get_student_hifz_progress.dart
│       ├── data/
│       │   ├── dto/hifz_log_dto.dart
│       │   ├── datasources/
│       │   │   ├── hifz_remote_datasource.dart
│       │   │   └── hifz_local_datasource.dart
│       │   ├── mappers/hifz_mapper.dart
│       │   └── repositories/hifz_repository_impl.dart
│       └── presentation/
│           ├── providers/
│           │   ├── hifz_roster_provider.dart
│           │   └── hifz_log_form_controller.dart
│           ├── screens/
│           │   ├── hifz_roster_screen.dart
│           │   ├── hifz_quick_log_screen.dart
│           │   └── hifz_progress_screen.dart
│           └── widgets/
│               ├── ayah_range_picker.dart
│               ├── error_counter_stepper.dart
│               └── hifz_grade_selector.dart
└── test/
```

### 7.2 Single App vs Separate Apps — Decision

**Decision: one Flutter application, one Play/App Store listing, role-resolved shell.**

Rationale:

- A meaningful number of users hold **two roles** — a teacher who is also a parent of a student in the same college, a hostel warden who also teaches a batch. Separate binaries means separate logins and duplicate notification streams for the same human.
- 70%+ of the code is shared regardless (auth, design system, sync, offline DB, announcements, profile, leave, timetable).
- Store review, release engineering, crash triage and Firebase project cost all double.
- The role difference is navigation + permission, not architecture.

Implementation: after login, the server returns `roles: []` and `activeContexts: []`. `go_router`'s `redirect` resolves the shell:

```dart
final shellProvider = Provider<AppShell>((ref) {
  final session = ref.watch(sessionProvider).requireValue;
  return switch (session.activeRole) {
    AppRole.teacher => AppShell.teacher,   // Today · Batches · Log · Reports · Profile
    AppRole.parent  => AppShell.parent,    // Wards · Hifz · Academics · Leave · Notices
    AppRole.warden  => AppShell.hostel,
  };
});
```

A **role switcher** lives in the profile sheet. Switching role rebuilds the router, clears feature-scoped providers, and re-scopes the local DB queries — it does **not** re-authenticate.

> If the client contractually insists on separately branded Teacher and Parent listings, ship the same codebase under two flavors with a compile-time `kEnabledRole` constant. Do not fork.

### 7.3 State Management Conventions

```dart
// 1. Repository provider — DI seam, overridden in tests
@riverpod
HifzRepository hifzRepository(HifzRepositoryRef ref) => HifzRepositoryImpl(
      remote: ref.watch(hifzRemoteDataSourceProvider),
      local: ref.watch(hifzLocalDataSourceProvider),
      outbox: ref.watch(outboxProvider),
      connectivity: ref.watch(connectivityProvider),
    );

// 2. Read model — streams from LOCAL db so UI is offline-correct by construction
@riverpod
Stream<List<HifzLogEntry>> batchRosterToday(Ref ref, String batchId) {
  return ref.watch(hifzRepositoryProvider).watchRoster(batchId, date: DateTime.now());
}

// 3. Write controller — freezed union state, never throws to the widget layer
@riverpod
class HifzLogController extends _$HifzLogController {
  @override
  HifzLogState build() => const HifzLogState.idle();

  Future<void> submit(HifzLogDraft draft) async {
    state = const HifzLogState.submitting();
    final result = await ref.read(logDailyHifzProvider)(draft);
    state = result.fold(
      (f) => HifzLogState.failure(f),
      (log) => HifzLogState.success(log),
    );
  }
}
```

**Rules:**

- UI **always** watches the local DB stream, never a raw network future. Network results land in the DB; the DB pushes to the UI. One data path.
- No `setState` outside of trivial animation controllers.
- No provider is declared inside a widget file.
- Every async provider surface exposes `AsyncValue` and every screen handles `loading` / `error` / `data` explicitly — no `.value!`.

### 7.4 Error Handling

```dart
sealed class Failure with _$Failure {
  const factory Failure.network()                       = NetworkFailure;
  const factory Failure.timeout()                       = TimeoutFailure;
  const factory Failure.unauthorized()                  = UnauthorizedFailure;
  const factory Failure.forbidden(String reason)        = ForbiddenFailure;
  const factory Failure.validation(Map<String,String>)  = ValidationFailure;
  const factory Failure.conflict(ConflictPayload p)     = ConflictFailure;
  const factory Failure.notFound()                      = NotFoundFailure;
  const factory Failure.server(String code)             = ServerFailure;
  const factory Failure.unknown(Object e, StackTrace s) = UnknownFailure;
}

typedef Result<T> = Either<Failure, T>;
```

- Data layer converts `DioException` → `Failure`. Nothing above the data layer catches raw exceptions.
- `runZonedGuarded` in `bootstrap.dart` funnels uncaught errors to Crashlytics + Sentry.
- User-facing messages are localized in the presentation layer via a `FailureMessageMapper` — the domain layer never carries English strings.

### 7.5 Offline & Sync Engine

**Local schema mirrors the server tables that a teacher needs for one working day**, plus two control tables:

```dart
// drift
class SyncOutbox extends Table {
  TextColumn get id => text()();                          // uuid v7, client-generated
  TextColumn get entity => text()();                      // 'hifz_log' | 'attendance' | ...
  TextColumn get operation => text()();                   // create | update | void
  TextColumn get payload => text()();                     // json
  TextColumn get idempotencyKey => text()();
  IntColumn  get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}

class SyncCursor extends Table {
  TextColumn get entity => text()();
  DateTimeColumn get lastPulledAt => dateTime()();
  @override Set<Column> get primaryKey => {entity};
}
```

**Sync rules:**

| Rule                 | Detail                                                                                                                                                                |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ID generation        | Client generates **UUID v7** for every record. Server accepts client IDs. No temp-id remapping.                                                                       |
| Idempotency          | `idempotencyKey = sha256(entity + clientId + naturalKey)`. Server dedupes for 7 days.                                                                                 |
| Ordering             | Outbox drains FIFO per entity; cross-entity order is not guaranteed except attendance-before-remark.                                                                  |
| Pull                 | Delta pull with `?updatedSince=<cursor>` per entity on app resume + every 15 min in foreground.                                                                       |
| Conflict             | Server row wins for master data (students, batches, timetable). For teacher-authored logs, a `409` returns both versions and the teacher resolves in a conflict card. |
| Retention            | Local academic data older than 60 days is pruned on launch; historic views fetch on demand.                                                                           |
| Auth expiry mid-sync | Outbox pauses, refresh runs, sync resumes. Never drops the queue on 401.                                                                                              |
| Visibility           | A persistent chip shows `N pending`. Tapping it opens the outbox inspector (also a support tool).                                                                     |

### 7.6 Design System

`packages/design_system` owns all tokens. No feature declares a raw `Color` or `TextStyle`.

```dart
class HufzTokens {
  // Palette — deep green / gold, appropriate for an Islamic institution
  static const primary      = Color(0xFF0F5132);
  static const primarySoft  = Color(0xFFE7F1EC);
  static const accent       = Color(0xFFC9A227);
  static const surface      = Color(0xFFFBFBF9);
  static const danger       = Color(0xFFB3261E);

  // Hifz semantic colors — used consistently in every chart, chip and calendar
  static const sabaq   = Color(0xFF0F5132);
  static const sabqi   = Color(0xFF2F7FBF);
  static const manzil  = Color(0xFF7A4FBF);
  static const doura   = Color(0xFFC9A227);

  static const spacing = [4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0];
  static const radius  = (sm: 8.0, md: 12.0, lg: 20.0, pill: 999.0);
}
```

Shared components: `HufzScaffold`, `HufzAppBar`, `StudentTile`, `AttendanceToggle`, `AyahRangePicker`, `ErrorCounterStepper`, `HifzGradeSelector`, `ProgressRing`, `EmptyState`, `OfflineBanner`, `ArabicText`, `SyncStatusChip`.

**Typography:** `Inter` (Latin) · `Manjari` or `NotoSansMalayalam` (Malayalam) · `KFGQPC Uthmanic Script HAFS` (Quranic). `ArabicText` widget forces `TextDirection.rtl`, disables font scaling above 1.3× to protect diacritic rendering, and never applies `letterSpacing`.

### 7.7 Navigation Map

```dart
// Teacher
/today                              // schedule + pending actions
/batches
/batches/:batchId/attendance
/batches/:batchId/hifz              // ← the core screen
/batches/:batchId/hifz/:studentId
/classes/:classId/marks/:examId
/leave/approvals
/students/:studentId
/reports

// Parent  (ward-scoped — every route carries the selected ward)
/wards                                        // ward switcher, badge per ward
/wards/:studentId                             // overview: today, alerts, quick stats
/wards/:studentId/attendance
/wards/:studentId/hifz                        // juz map, streak, progress curve
/wards/:studentId/hifz/history                // day-by-day log detail
/wards/:studentId/hifz/doura
/wards/:studentId/academics/timetable
/wards/:studentId/academics/subjects/:subjectId
/wards/:studentId/homework
/wards/:studentId/results
/wards/:studentId/results/:examId
/wards/:studentId/activities
/wards/:studentId/leave
/wards/:studentId/hostel
/wards/:studentId/canteen
/wards/:studentId/reports                     // published PDFs
/notices
```

The selected ward is held in a `selectedWardProvider` persisted to secure prefs; all ward-scoped providers are `family`-keyed on `studentId` so switching wards never leaks cached data across children.

Push notification payloads carry a `route` field consumed by `go_router` for deep linking.

### 7.8 Performance Budget

| Metric                                 | Target                              |
| -------------------------------------- | ----------------------------------- |
| Cold start to first frame              | < 1.8 s on a 2019 mid-range Android |
| Batch roster (40 students) list scroll | 60 fps, no jank frames              |
| Hifz log save (offline)                | < 100 ms perceived                  |
| Full-day outbox flush (200 ops)        | < 20 s on 3G                        |
| APK size (arm64, split)                | < 30 MB                             |

Enforced via: `ListView.builder` everywhere, `const` constructors, `RepaintBoundary` on chart widgets, image caching with `cached_network_image`, deferred loading of report/PDF modules.

### 7.9 Testing Strategy

| Layer                                      | Tooling                       | Coverage target      |
| ------------------------------------------ | ----------------------------- | -------------------- |
| Domain use cases + value objects           | `flutter_test`                | 90%                  |
| Repository impls (offline branch logic)    | `mocktail` + in-memory drift  | 85%                  |
| Sync engine (replay, conflict, backoff)    | deterministic fake clock      | 90%                  |
| Widget — critical screens                  | `flutter_test` golden tests   | key screens          |
| E2E — login, mark attendance offline, sync | `patrol` on Firebase Test Lab | happy + offline path |

**Non-negotiable test:** "teacher logs a full day for 3 batches with the network disabled, kills the app, reopens, network returns → zero data loss, zero duplicates."

---

## 8. Backend Architecture & API Conventions

### 8.1 Layout

```text
apps/web/src/
├── app/
│   ├── (console)/               # admin UI, RSC
│   └── api/v1/
│       ├── auth/[...all]/route.ts
│       ├── students/route.ts
│       ├── attendance/route.ts
│       ├── attendance/batch/route.ts
│       ├── hifz/logs/route.ts
│       ├── hifz/logs/batch/route.ts
│       ├── hifz/progress/[studentId]/route.ts
│       ├── doura/route.ts
│       ├── exams/…  leave/…  hostel/…  canteen/…
│       └── sync/pull/route.ts
├── server/
│   ├── services/                # pure domain services
│   ├── policies/                # RBAC guards
│   ├── middleware/
│   └── mappers/
```

### 8.2 Response Envelope

```jsonc
// success
{ "data": { }, "meta": { "page": 1, "pageSize": 50, "total": 812, "serverTime": "2026-01-01T04:30:00Z" } }

// error
{ "error": { "code": "HIFZ_RANGE_OVERLAP", "message": "Sabaq range overlaps an existing log for this date.",
             "field": "fromAyah", "details": { "conflictingLogId": "018f…" } } }
```

Error codes are a closed enum in `packages/contracts` and are mapped to localized strings in Flutter — the server never sends user-facing Malayalam.

### 8.3 Conventions

- **Versioned** at `/api/v1`. Breaking changes → `/v2`; mobile clients pin a version and a `min_supported_app_version` check runs on `/session`.
- **Pagination**: cursor-based (`?cursor=&limit=`) for feeds, offset for admin tables.
- **Time**: all timestamps UTC ISO-8601; all _dates_ (attendance date, hifz date) are `DATE` in `Asia/Kolkata` — never derive a date from a UTC timestamp client-side.
- **Batch endpoints** exist for every high-volume teacher write (`/attendance/batch`, `/hifz/logs/batch`) accepting up to 100 items with per-item result status.
- **Delta pull**: `GET /api/v1/sync/pull?entities=students,batches,timetable&since=<iso>` returns changed rows + tombstones + new cursor.
- **Audit**: every mutation writes `audit_log(actor_id, entity, entity_id, action, before, after, ip, at)`.

### 8.4 Auth

- Better Auth with the **bearer + JWT** plugin for mobile: access token 15 min, refresh token 60 days, rotating with reuse detection.
- Device registration on login → `devices(user_id, fcm_token, platform, app_version, last_seen)`.
- Parents authenticate by **phone + OTP** (guardians frequently share/forget email). Teachers and admins use email + password with optional OTP. Students use admission number + PIN issued by the office, forced to change on first login.
- Session response includes `roles`, `scopes` (batch/class/department IDs), `institutionSettings` — this is what drives the Flutter shell and the local RBAC hints.

---

## 9. Domain Model & Database Schema

### 9.1 Core Entities

```text
Institution
 └── AcademicYear
      ├── Department (HIFZ_DOURA | ISLAMIC_STUDIES | GENERAL_EDUCATION)
      │    ├── Batch          (Hifz halaqa — small, teacher-owned)
      │    └── ClassSection   (conventional class + section)
      ├── Student ──< Enrollment >── Department/Batch/ClassSection
      ├── Guardian ──< StudentGuardian >── Student
      └── Staff ──< StaffAssignment >── Batch/ClassSection/Subject
```

A student has **one `Enrollment` row per department per academic year**. `Enrollment` is the join that every academic record points at — not `student_id` alone.

`Student` is a **data subject, not a system user** — there is no `users` row for a student. All non-staff access flows `users → guardians → student_guardians → students`, which makes `student_guardians` a security-critical table: an incorrect row exposes one family's child data to another family. It requires an admin-only write path, full audit, and a periodic reconciliation report.

### 9.2 Schema (abridged DDL)

```sql
-- ─────────── Identity & People ───────────
CREATE TABLE users (
  id              UUID PRIMARY KEY,
  email           TEXT UNIQUE,
  phone           TEXT UNIQUE,
  password_hash   TEXT,
  full_name       TEXT NOT NULL,
  avatar_url      TEXT,
  locale          TEXT DEFAULT 'en',
  status          TEXT NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE user_roles (
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL,            -- SUPER_ADMIN | ADMIN | DEPT_HEAD | TEACHER | …
  scope_type  TEXT,                     -- DEPARTMENT | BATCH | CLASS | HOSTEL | NULL
  scope_id    UUID,
  PRIMARY KEY (user_id, role, scope_type, scope_id)
);

CREATE TABLE students (
  id                UUID PRIMARY KEY,
  admission_no      TEXT UNIQUE NOT NULL,
  user_id           UUID REFERENCES users(id),      -- ALWAYS NULL in v1: students have no login
  full_name         TEXT NOT NULL,
  full_name_ml      TEXT,
  dob               DATE,
  gender            TEXT,
  blood_group       TEXT,
  photo_url         TEXT,
  admission_date    DATE NOT NULL,
  residency         TEXT NOT NULL,                  -- HOSTELLER | DAY_SCHOLAR
  address           JSONB,
  status            TEXT NOT NULL DEFAULT 'active', -- active|alumni|transferred|dropped
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE guardians (
  id           UUID PRIMARY KEY,
  user_id      UUID REFERENCES users(id),
  full_name    TEXT NOT NULL,
  phone        TEXT NOT NULL,
  occupation   TEXT,
  address      JSONB
);

CREATE TABLE student_guardians (
  student_id   UUID REFERENCES students(id) ON DELETE CASCADE,
  guardian_id  UUID REFERENCES guardians(id) ON DELETE CASCADE,
  relation     TEXT NOT NULL,          -- father|mother|brother|uncle|other
  is_primary   BOOLEAN DEFAULT false,
  can_approve_leave BOOLEAN DEFAULT true,
  PRIMARY KEY (student_id, guardian_id)
);

CREATE TABLE staff (
  id             UUID PRIMARY KEY,
  user_id        UUID REFERENCES users(id) NOT NULL,
  employee_no    TEXT UNIQUE NOT NULL,
  designation    TEXT,
  qualification  TEXT,
  joining_date   DATE,
  status         TEXT DEFAULT 'active'
);

-- ─────────── Academic Structure ───────────
CREATE TABLE academic_years (
  id         UUID PRIMARY KEY,
  name       TEXT NOT NULL,           -- '1447 AH / 2026-27'
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  is_current BOOLEAN DEFAULT false
);

CREATE TABLE departments (
  id      UUID PRIMARY KEY,
  code    TEXT UNIQUE NOT NULL,       -- HIFZ | ISLAMIC | GENERAL
  name    TEXT NOT NULL,
  kind    TEXT NOT NULL               -- HIFZ_DOURA | SUBJECT_BASED
);

CREATE TABLE batches (                -- Hifz halaqa
  id               UUID PRIMARY KEY,
  department_id    UUID REFERENCES departments(id),
  academic_year_id UUID REFERENCES academic_years(id),
  name             TEXT NOT NULL,     -- 'Batch 01'
  level            TEXT,              -- NAZIRA | HIFZ | DOURA
  incharge_staff_id UUID REFERENCES staff(id),
  capacity         INT
);

CREATE TABLE class_sections (
  id               UUID PRIMARY KEY,
  department_id    UUID REFERENCES departments(id),
  academic_year_id UUID REFERENCES academic_years(id),
  class_name       TEXT NOT NULL,     -- 'Class 5'
  section          TEXT,              -- 'A'
  class_teacher_id UUID REFERENCES staff(id)
);

CREATE TABLE subjects (
  id             UUID PRIMARY KEY,
  department_id  UUID REFERENCES departments(id),
  code           TEXT NOT NULL,
  name           TEXT NOT NULL,
  max_marks      INT DEFAULT 100,
  pass_marks     INT DEFAULT 35,
  is_gradable    BOOLEAN DEFAULT true
);

CREATE TABLE enrollments (
  id                UUID PRIMARY KEY,
  student_id        UUID REFERENCES students(id),
  academic_year_id  UUID REFERENCES academic_years(id),
  department_id     UUID REFERENCES departments(id),
  batch_id          UUID REFERENCES batches(id),
  class_section_id  UUID REFERENCES class_sections(id),
  roll_no           TEXT,
  status            TEXT DEFAULT 'active',
  UNIQUE (student_id, academic_year_id, department_id)
);

CREATE TABLE staff_assignments (
  id               UUID PRIMARY KEY,
  staff_id         UUID REFERENCES staff(id),
  academic_year_id UUID REFERENCES academic_years(id),
  department_id    UUID REFERENCES departments(id),
  batch_id         UUID REFERENCES batches(id),
  class_section_id UUID REFERENCES class_sections(id),
  subject_id       UUID REFERENCES subjects(id),
  role             TEXT NOT NULL      -- INCHARGE | SUBJECT_TEACHER | ASSISTANT
);

CREATE TABLE timetable_slots (
  id               UUID PRIMARY KEY,
  academic_year_id UUID REFERENCES academic_years(id),
  department_id    UUID REFERENCES departments(id),
  class_section_id UUID REFERENCES class_sections(id),
  batch_id         UUID REFERENCES batches(id),
  day_of_week      SMALLINT NOT NULL,   -- 0=Sun … 6=Sat
  period_no        SMALLINT,
  subject_id       UUID REFERENCES subjects(id),
  staff_id         UUID REFERENCES staff(id),
  start_time       TIME NOT NULL,
  end_time         TIME NOT NULL,
  room             TEXT,
  effective_from   DATE NOT NULL,
  effective_to     DATE
);
```

```sql
-- ─────────── Attendance ───────────
CREATE TABLE attendance_records (
  id               UUID PRIMARY KEY,          -- client-generated uuid v7
  enrollment_id    UUID REFERENCES enrollments(id) NOT NULL,
  attendance_date  DATE NOT NULL,
  session          TEXT NOT NULL,             -- FULL_DAY | FORENOON | AFTERNOON | PERIOD
  timetable_slot_id UUID REFERENCES timetable_slots(id),
  status           TEXT NOT NULL,             -- PRESENT | ABSENT | LATE | LEAVE | HALF_DAY | EXCUSED
  minutes_late     INT,
  remark           TEXT,
  marked_by        UUID REFERENCES staff(id),
  marked_at        TIMESTAMPTZ NOT NULL,
  source           TEXT DEFAULT 'app',        -- app | web | import | biometric
  supersedes_id    UUID REFERENCES attendance_records(id),
  is_current       BOOLEAN DEFAULT true,
  UNIQUE (enrollment_id, attendance_date, session, timetable_slot_id) WHERE is_current
);

CREATE INDEX ON attendance_records (attendance_date, enrollment_id) WHERE is_current;

-- ─────────── Hifz & Doura ───────────
CREATE TABLE hifz_daily_logs (
  id               UUID PRIMARY KEY,          -- client-generated uuid v7
  enrollment_id    UUID REFERENCES enrollments(id) NOT NULL,
  batch_id         UUID REFERENCES batches(id) NOT NULL,
  log_date         DATE NOT NULL,
  activity         TEXT NOT NULL,             -- SABAQ | SABQI | MANZIL | DOURA | NAZIRA | TAJWEED
  from_surah       SMALLINT NOT NULL,         -- 1..114
  from_ayah        SMALLINT NOT NULL,
  to_surah         SMALLINT NOT NULL,
  to_ayah          SMALLINT NOT NULL,
  from_page        SMALLINT,                  -- Madani mushaf 1..604 (derived, denormalized)
  to_page          SMALLINT,
  lines_count      SMALLINT,                  -- sutoor, 15 lines/page
  juz_no           SMALLINT,
  doura_round_id   UUID REFERENCES doura_rounds(id),
  errors_major     SMALLINT DEFAULT 0,        -- khata / forgotten
  errors_minor     SMALLINT DEFAULT 0,        -- tajweed
  prompts_count    SMALLINT DEFAULT 0,        -- luqma / how many times prompted
  grade            TEXT,                      -- EXCELLENT | GOOD | AVERAGE | WEAK | NOT_READY
  is_repeat        BOOLEAN DEFAULT false,     -- repeating yesterday's sabaq
  teacher_remark   TEXT,
  audio_url        TEXT,                      -- optional recitation clip in R2
  logged_by        UUID REFERENCES staff(id) NOT NULL,
  logged_at        TIMESTAMPTZ NOT NULL,
  device_id        TEXT,
  supersedes_id    UUID REFERENCES hifz_daily_logs(id),
  is_current       BOOLEAN DEFAULT true,
  CHECK (from_surah BETWEEN 1 AND 114 AND to_surah BETWEEN 1 AND 114)
);

CREATE INDEX ON hifz_daily_logs (enrollment_id, log_date DESC) WHERE is_current;
CREATE INDEX ON hifz_daily_logs (batch_id, log_date) WHERE is_current;

CREATE TABLE doura_rounds (
  id             UUID PRIMARY KEY,
  enrollment_id  UUID REFERENCES enrollments(id) NOT NULL,
  round_no       SMALLINT NOT NULL,           -- 1st doura, 2nd doura, …
  started_on     DATE NOT NULL,
  target_end_on  DATE,
  completed_on   DATE,
  status         TEXT DEFAULT 'in_progress',  -- in_progress | completed | abandoned
  supervisor_id  UUID REFERENCES staff(id),
  remark         TEXT,
  UNIQUE (enrollment_id, round_no)
);

-- rolling memorization state, maintained by a service (not a trigger) after each log
CREATE TABLE hifz_progress_snapshots (
  enrollment_id       UUID PRIMARY KEY REFERENCES enrollments(id),
  total_pages_memorized  NUMERIC(6,2) DEFAULT 0,
  total_juz_memorized    NUMERIC(4,2) DEFAULT 0,
  current_sabaq_page     SMALLINT,
  current_juz            SMALLINT,
  last_log_date          DATE,
  streak_days            INT DEFAULT 0,
  avg_lines_per_day_30d  NUMERIC(5,2),
  avg_errors_per_day_30d NUMERIC(5,2),
  completed_doura_count  SMALLINT DEFAULT 0,
  projected_khatm_date   DATE,
  updated_at             TIMESTAMPTZ DEFAULT now()
);
```

```sql
-- ─────────── Examination & Assessment ───────────
CREATE TABLE exams (
  id               UUID PRIMARY KEY,
  academic_year_id UUID REFERENCES academic_years(id),
  department_id    UUID REFERENCES departments(id),
  name             TEXT NOT NULL,             -- 'First Term Examination'
  assessment_type  TEXT NOT NULL,             -- FORMATIVE | SUMMATIVE
  term             TEXT,
  start_date       DATE,
  end_date         DATE,
  weightage        NUMERIC(5,2),              -- % contribution to final
  status           TEXT DEFAULT 'draft'       -- draft|scheduled|ongoing|marks_entry|published
);

CREATE TABLE exam_schedules (
  id                UUID PRIMARY KEY,
  exam_id           UUID REFERENCES exams(id) ON DELETE CASCADE,
  class_section_id  UUID REFERENCES class_sections(id),
  batch_id          UUID REFERENCES batches(id),
  subject_id        UUID REFERENCES subjects(id),
  exam_date         DATE NOT NULL,
  start_time        TIME,
  end_time          TIME,
  max_marks         INT NOT NULL,
  pass_marks        INT NOT NULL,
  invigilator_id    UUID REFERENCES staff(id),
  question_paper_url TEXT,                    -- R2, access-controlled + time-gated
  syllabus_note     TEXT
);

CREATE TABLE exam_marks (
  id                UUID PRIMARY KEY,
  exam_schedule_id  UUID REFERENCES exam_schedules(id),
  enrollment_id     UUID REFERENCES enrollments(id),
  marks_obtained    NUMERIC(6,2),
  is_absent         BOOLEAN DEFAULT false,
  grade             TEXT,
  remark            TEXT,
  entered_by        UUID REFERENCES staff(id),
  entered_at        TIMESTAMPTZ,
  verified_by       UUID REFERENCES staff(id),
  verified_at       TIMESTAMPTZ,
  supersedes_id     UUID REFERENCES exam_marks(id),
  is_current        BOOLEAN DEFAULT true,
  UNIQUE (exam_schedule_id, enrollment_id) WHERE is_current
);

CREATE TABLE grade_scales (
  id            UUID PRIMARY KEY,
  department_id UUID REFERENCES departments(id),
  grade         TEXT NOT NULL,       -- A+ | A | B+ …
  min_percent   NUMERIC(5,2) NOT NULL,
  max_percent   NUMERIC(5,2) NOT NULL,
  grade_point   NUMERIC(4,2),
  descriptor    TEXT
);

-- ─────────── Progress Reports ───────────
CREATE TABLE progress_reports (
  id                UUID PRIMARY KEY,
  enrollment_id     UUID REFERENCES enrollments(id),
  period_type       TEXT NOT NULL,           -- MONTHLY | TERM | ANNUAL
  period_start      DATE NOT NULL,
  period_end        DATE NOT NULL,
  payload           JSONB NOT NULL,          -- computed snapshot (immutable once published)
  pdf_url           TEXT,
  teacher_remark    TEXT,
  head_remark       TEXT,
  status            TEXT DEFAULT 'draft',    -- draft | approved | published
  published_at      TIMESTAMPTZ,
  UNIQUE (enrollment_id, period_type, period_start)
);

-- ─────────── Daily Activities ───────────
CREATE TABLE daily_activities (
  id             UUID PRIMARY KEY,
  scope_type     TEXT NOT NULL,             -- STUDENT | BATCH | CLASS | HOSTEL
  scope_id       UUID NOT NULL,
  activity_date  DATE NOT NULL,
  category       TEXT NOT NULL,             -- QURAN | STUDY | SPORTS | CLEANLINESS | EVENT | CONDUCT | OTHER
  title          TEXT NOT NULL,
  description    TEXT,
  media_urls     TEXT[],
  visible_to     TEXT[] DEFAULT '{PARENT}',        -- PARENT | STAFF_ONLY
  created_by     UUID REFERENCES staff(id),
  created_at     TIMESTAMPTZ DEFAULT now()
);

-- ─────────── Leave ───────────
CREATE TABLE leave_requests (
  id               UUID PRIMARY KEY,
  subject_type     TEXT NOT NULL,           -- STUDENT | STAFF
  student_id       UUID REFERENCES students(id),
  staff_id         UUID REFERENCES staff(id),
  leave_type       TEXT NOT NULL,           -- SICK | CASUAL | EMERGENCY | VACATION | HOME_VISIT
  from_date        DATE NOT NULL,
  to_date          DATE NOT NULL,
  is_half_day      BOOLEAN DEFAULT false,
  reason           TEXT NOT NULL,
  attachment_url   TEXT,
  requested_by     UUID REFERENCES users(id),
  status           TEXT DEFAULT 'pending',  -- pending|approved|rejected|cancelled
  current_stage    TEXT,                    -- CLASS_TEACHER | WARDEN | DEPT_HEAD | ADMIN
  decided_by       UUID REFERENCES users(id),
  decided_at       TIMESTAMPTZ,
  decision_note    TEXT,
  gate_pass_no     TEXT,
  actual_return_at TIMESTAMPTZ,
  CHECK (to_date >= from_date)
);

CREATE TABLE leave_approvals (       -- multi-stage trail
  id          UUID PRIMARY KEY,
  leave_id    UUID REFERENCES leave_requests(id) ON DELETE CASCADE,
  stage       TEXT NOT NULL,
  approver_id UUID REFERENCES users(id),
  action      TEXT NOT NULL,          -- approved | rejected | forwarded
  note        TEXT,
  acted_at    TIMESTAMPTZ DEFAULT now()
);

-- ─────────── Hostel ───────────
CREATE TABLE hostels (
  id       UUID PRIMARY KEY,
  name     TEXT NOT NULL,
  gender   TEXT,
  warden_id UUID REFERENCES staff(id),
  address  TEXT
);
CREATE TABLE hostel_blocks (
  id UUID PRIMARY KEY, hostel_id UUID REFERENCES hostels(id), name TEXT NOT NULL, floors SMALLINT
);
CREATE TABLE hostel_rooms (
  id UUID PRIMARY KEY, block_id UUID REFERENCES hostel_blocks(id),
  room_no TEXT NOT NULL, floor SMALLINT, capacity SMALLINT NOT NULL, room_type TEXT,
  status TEXT DEFAULT 'available'    -- available|full|maintenance
);
CREATE TABLE hostel_beds (
  id UUID PRIMARY KEY, room_id UUID REFERENCES hostel_rooms(id),
  bed_no TEXT NOT NULL, status TEXT DEFAULT 'vacant',
  UNIQUE (room_id, bed_no)
);
CREATE TABLE hostel_allocations (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES students(id),
  bed_id     UUID REFERENCES hostel_beds(id),
  allocated_on DATE NOT NULL,
  vacated_on   DATE,
  reason_for_change TEXT,
  allocated_by UUID REFERENCES staff(id)
);
CREATE TABLE hostel_attendance (      -- night roll call
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES students(id),
  check_date DATE NOT NULL,
  check_type TEXT NOT NULL,           -- NIGHT_ROLLCALL | FAJR | RETURN_FROM_LEAVE
  status     TEXT NOT NULL,           -- PRESENT | ABSENT | ON_LEAVE | LATE_RETURN
  marked_by  UUID REFERENCES staff(id),
  marked_at  TIMESTAMPTZ,
  UNIQUE (student_id, check_date, check_type)
);

-- ─────────── Canteen ───────────
CREATE TABLE canteen_items (
  id UUID PRIMARY KEY, name TEXT NOT NULL, category TEXT, unit_price NUMERIC(10,2),
  is_meal BOOLEAN DEFAULT false, is_active BOOLEAN DEFAULT true
);
CREATE TABLE canteen_menus (
  id UUID PRIMARY KEY, menu_date DATE NOT NULL,
  meal_type TEXT NOT NULL,            -- BREAKFAST | LUNCH | SNACKS | DINNER
  item_ids UUID[], notes TEXT,
  UNIQUE (menu_date, meal_type)
);
CREATE TABLE canteen_meal_records (
  id UUID PRIMARY KEY,
  person_type TEXT NOT NULL,          -- STUDENT | STAFF
  student_id UUID REFERENCES students(id),
  staff_id   UUID REFERENCES staff(id),
  meal_date  DATE NOT NULL,
  meal_type  TEXT NOT NULL,
  consumed   BOOLEAN DEFAULT true,
  marked_by  UUID REFERENCES staff(id),
  UNIQUE (student_id, meal_date, meal_type)
);
CREATE TABLE canteen_transactions (   -- optional wallet/ledger
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES students(id),
  txn_type TEXT NOT NULL,             -- CREDIT | DEBIT
  amount NUMERIC(10,2) NOT NULL,
  reference TEXT, note TEXT,
  balance_after NUMERIC(10,2),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─────────── Communication & Audit ───────────
CREATE TABLE announcements (
  id UUID PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL,
  audience JSONB NOT NULL,            -- {roles:[], departments:[], batches:[], classes:[]}
  attachment_urls TEXT[], pinned BOOLEAN DEFAULT false,
  publish_at TIMESTAMPTZ, expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id)
);
CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY, actor_id UUID, entity TEXT, entity_id UUID,
  action TEXT, before JSONB, after JSONB, ip TEXT, at TIMESTAMPTZ DEFAULT now()
);
```

### 9.3 Reference Data (seeded, read-only)

```sql
CREATE TABLE quran_surahs (
  number SMALLINT PRIMARY KEY, name_ar TEXT, name_en TEXT, name_ml TEXT,
  ayah_count SMALLINT, revelation_place TEXT, start_page SMALLINT
);
CREATE TABLE quran_ayah_index (       -- 6236 rows, enables page/line/juz derivation
  surah SMALLINT, ayah SMALLINT, page SMALLINT, juz SMALLINT,
  hizb SMALLINT, rub SMALLINT, line_start SMALLINT, line_end SMALLINT,
  PRIMARY KEY (surah, ayah)
);
```

This table is the backbone of the Hifz module: it converts a teacher's `from → to` ayah selection into **pages, lines and juz** so all progress metrics are computed rather than typed. It is bundled with the Flutter app as a read-only SQLite asset so the picker and page math work fully offline.

---

## 10. Module Specifications

Each module below is specified as: **purpose → roles → screens per client → key rules → API surface**.

---

### M01 · Authentication & Session

**Purpose.** Single sign-in across four clients, multi-role context switching, device registration.

**Screens (Flutter)**

- Splash → session hydration → route resolution
- Login: segmented control `Staff` / `Parent`
  - Staff → email + password (+ OTP if enabled)
  - Parent → phone + OTP (the phone number on the guardian record; resolves all linked wards)
- Forgot password
- Guardian onboarding: first login links every ward whose `student_guardians` row carries that phone
- Role switcher bottom sheet (only when `roles.length > 1`)
- Biometric unlock toggle (re-auth for stored refresh token)

**Rules**

- App version gate: if `appVersion < minSupportedVersion`, show a blocking update screen.
- A parent with 3 wards lands on a ward switcher; the selected ward persists in secure prefs. A guardian with exactly one ward skips the switcher entirely.
- **Students have no credentials.** There is no student sign-in path, and `students.user_id` is never provisioned. Any request resolving student data for a non-staff user must pass through `student_guardians`.
- Logout clears drift DB **for that user only** and revokes the FCM token server-side.
- Failed OTP: 5 attempts → 30-minute lockout on the phone number.

**API**

```
POST /api/v1/auth/sign-in/email
POST /api/v1/auth/otp/request        { phone }
POST /api/v1/auth/otp/verify         { phone, code }
POST /api/v1/auth/refresh
POST /api/v1/auth/devices            { fcmToken, platform, appVersion }
GET  /api/v1/session                 → { user, roles, scopes, wards[], settings }
POST /api/v1/auth/sign-out
```

---

### M02 · Student Management

**Purpose.** Master record for every student — the profile every other module hangs off.

**Roles.** Admin (CRUD) · Dept Head (R) · Teacher (R, assigned) · Parent (R, ward) · Student (R, self)

**Admin Console**

- Student list: filters by department, batch, class, residency, status; bulk actions (promote, transfer, deactivate)
- Admission wizard: personal → guardians → department enrollment(s) → hostel → documents → **guardian app invite** (SMS with the app link; the guardian's phone number is the credential)
- Student 360 view — tabs: Profile · Enrollments · Attendance · Hifz · Academics · Exams · Leave · Hostel · Canteen · Documents · Activity log
- Bulk import via CSV (with dry-run validation report)
- Promotion tool: end-of-year batch/class advancement with rollback

**Flutter — Teacher**

- Roster tile → Student detail (photo, admission no, batch, guardian call/WhatsApp shortcut, attendance %, current sabaq, last 7-day errors)

**Flutter — Parent**

- Ward card grid → Ward overview (photo, admission no, department chips, today-at-a-glance)
- Full student profile, read-only; a `Request correction` action opens a note to the office rather than editing master data directly

**Rules**

- `admission_no` is immutable and unique for life; alumni keep theirs.
- Deleting a student is never allowed — status changes to `alumni | transferred | dropped` with reason and date.
- A student **must** have at least one guardian marked `is_primary` — this is now a hard constraint, not a nicety, because it is the only channel through which student information reaches the family.
- Changing a primary guardian's phone number revokes existing sessions on the old number and re-invites the new one.
- Photo upload → presigned R2 PUT, resized server-side to 400×400 webp.

**API**

```
GET    /api/v1/students?departmentId=&batchId=&q=&cursor=
POST   /api/v1/students
GET    /api/v1/students/:id
PATCH  /api/v1/students/:id
POST   /api/v1/students/:id/enrollments
POST   /api/v1/students/:id/guardians
POST   /api/v1/students/import            (CSV, multipart)
GET    /api/v1/students/:id/overview      → aggregated 360 payload
```

---

### M03 · Attendance

**Purpose.** Department-scoped daily/period attendance with an offline-first teacher flow.

**Modes** (configurable per department):

| Mode       | Used by                                                  |
| ---------- | -------------------------------------------------------- |
| `FULL_DAY` | Hifz department — single mark per day                    |
| `SESSION`  | Forenoon / Afternoon                                     |
| `PERIOD`   | Islamic Studies & General Education — per timetable slot |

**Flutter — Teacher (core screen)**

- `Today` shows every slot the teacher owns with a status chip: `Not marked` / `Marked` / `Pending sync`
- Tap slot → roster screen
  - Default all → `PRESENT` (fast path: mark only the absentees)
  - Segmented per student: P / A / L / LV
  - Swipe a row for remark + late minutes
  - Sticky footer: `Present 34 · Absent 3 · Late 1` + `Submit`
  - Submit writes locally, returns instantly, queues sync
- Edit window: same day only for a teacher; beyond that requires an admin unlock request

**Flutter — Parent**

- Month calendar heatmap (green/amber/red), tap a day for period breakdown
- Rolling percentage + "below 75%" warning banner
- Absence push at a configurable time (default 10:30 AM) if unmarked-absent

**Rules**

- Marking is blocked for `holidays` and for students on approved leave (auto-marked `LEAVE`, teacher can override).
- Percentage = `(present + late + excused) / working_days` per department; the formula lives in one server service, nowhere else.
- Corrections are append-only: new row with `supersedes_id`, old row `is_current = false`.
- Late marks convert to `HALF_DAY` after a configurable threshold.

**API**

```
GET  /api/v1/attendance/roster?slotId=&date=        → students + existing marks
POST /api/v1/attendance/batch                        Idempotency-Key required
     { slotId, date, session, marks:[{enrollmentId,status,minutesLate,remark,clientId}] }
GET  /api/v1/attendance/student/:enrollmentId?from=&to=
GET  /api/v1/attendance/summary?batchId=&month=
POST /api/v1/attendance/:id/correct
```

---

### M04 · Hifz & Doura ⭐ _core differentiator_

**Purpose.** Replace the paper Hifz register. Track daily Sabaq / Sabqi / Manzil / Doura at ayah-and-line precision, derive real memorization metrics, and make it fast enough that a teacher can log 25 students during a halaqa.

#### 10.4.1 Domain Vocabulary

| Term                   | Meaning                                                                      | System treatment                                                      |
| ---------------------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **Sabaq**              | New lesson memorized today                                                   | One log/day/student, ayah range, lines count, error counts, grade     |
| **Sabqi** (Sabaq Para) | Revision of recently memorized portion (typically current juz / last 7 days) | Range + errors + grade                                                |
| **Manzil**             | Revision of older, consolidated memorization                                 | Range + errors + grade                                                |
| **Doura**              | A complete revision round of the entire memorized Quran / full Quran         | Belongs to a `doura_round`, sequential coverage tracked to completion |
| **Nazira**             | Reading from the mushaf (pre-hifz stage)                                     | Same log shape, `activity = NAZIRA`                                   |
| **Khatm**              | Completion of the full Quran                                                 | Milestone event, generates a certificate record                       |
| **Luqma / prompt**     | Teacher prompting a stuck student                                            | `prompts_count` — the single best quality signal                      |

#### 10.4.2 The Quick Log Screen (the most important screen in the product)

Design target: **≤ 20 seconds per student, ≤ 6 taps, fully offline.**

```
┌──────────────────────────────────────────────┐
│  Batch 01 · Ustadh Rashid       Thu 15 Jan    │  ← header
│  ●●●●●●●○○○○  7 of 22 logged                 │  ← progress
├──────────────────────────────────────────────┤
│  [ SABAQ ]  SABQI   MANZIL   DOURA           │  ← activity tabs
├──────────────────────────────────────────────┤
│  ┌─ Muhammed Ashiq  ·  Roll 04 ────────────┐ │
│  │ Suggested: An-Nisa 12 → 18   (auto)     │ │  ← continues from last log
│  │ From [An-Nisa ▾][12]  To [An-Nisa ▾][18]│ │
│  │ 7 ayah · 1.2 pages · 18 lines           │ │  ← derived live, offline
│  │                                          │ │
│  │ Mistakes  −[ 1 ]+     Prompts −[ 2 ]+   │ │  ← big steppers
│  │ Tajweed   −[ 0 ]+                       │ │
│  │ Grade  ⬤Excellent ○Good ○Avg ○Weak ○NR  │ │
│  │ 🎙 Record (optional)      📝 Remark      │ │
│  └──────────────────────────────────────────┘ │
│         [ Save & Next Student  → ]            │
└──────────────────────────────────────────────┘
```

Interaction rules that make the speed target achievable:

- **Auto-continuation:** the `from` ayah pre-fills as `last log's to_ayah + 1` for that activity. In practice the teacher edits only `to`.
- **Ayah picker** is a two-wheel Cupertino-style picker (surah wheel + ayah wheel), sourced from the bundled ayah index — no network, no typing.
- Steppers default to 0; a clean recitation is a single tap on `Excellent` then `Save & Next`.
- `Save & Next` writes to drift and advances to the next unlogged student in roll order — no back-navigation to a list.
- Absentees and students on leave are auto-skipped with a `Not present` chip.
- A `Repeat sabaq` toggle marks that the student is repeating yesterday's portion (does not advance the pointer, counts toward a "stuck" flag).

#### 10.4.3 Business Rules

1. **One current log per `(enrollment, date, activity)`.** Re-logging supersedes.
2. `to` position must be **≥** `from` position in absolute ayah order (validated against the ayah index, not surah number arithmetic).
3. **Sabaq cannot exceed the memorized frontier + 1.** Logging a sabaq far beyond `current_sabaq_page` raises a soft warning (teacher can confirm — students do jump between juz).
4. Pages/lines/juz are **derived**, never entered. `lines_count` comes from the ayah index line spans.
5. `DOURA` logs must be attached to an open `doura_round`. Opening a new round while one is `in_progress` requires closing or abandoning the previous one.
6. A doura round is auto-marked `completed` when cumulative coverage of its logs reaches the round's target scope (full Quran or the student's memorized portion).
7. **Khatm detection:** when cumulative distinct memorized pages reach 604, emit a `KHATM_ACHIEVED` event → notification to admin + guardian, certificate record created.
8. Backdating is limited to `hifzBackdateDays` (default 3) for teachers; admin unlimited with audit.
9. `hifz_progress_snapshots` is recomputed by the service after every log write and re-derived nightly by a Trigger.dev job (self-healing).

#### 10.4.4 Derived Metrics

| Metric              | Definition                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------- |
| Pages memorized     | Count of distinct Madani pages covered by `SABAQ` logs, deduped                           |
| Juz memorized       | `pages / 20.13` — displayed to 1 decimal, plus a 30-cell juz map                          |
| Daily average (30d) | Mean `lines_count` of `SABAQ` logs over the last 30 calendar days                         |
| Consistency streak  | Consecutive working days with a `SABAQ` log                                               |
| Quality index       | `100 − (3·errors_major + 1·errors_minor + 2·prompts) / lines × 10`, clamped 0–100         |
| Retention score     | Rolling error rate on `MANZIL` logs — the true measure of whether memorization is holding |
| Projected khatm     | `remaining_pages / avg_pages_per_day(60d)`, shown with a confidence band                  |
| Stuck flag          | 3+ consecutive `is_repeat` sabaq logs, or quality index < 40 for 5 days                   |

#### 10.4.5 Parent App — Hifz Screens

The guardian is the only non-staff audience, so these screens carry the **full** log detail. Present it in plain language — a parent is not an Ustadh and should not be handed a raw error matrix without framing.

- **Today's card:** today's sabaq / sabqi / manzil ranges (Surah + ayah, Arabic + transliteration), grade chip, teacher remark
- **Juz Map:** 30-cell grid, fill state per juz (memorized / in progress / not started); tap → page-level detail
- **Progress curve:** cumulative pages over time (`fl_chart`) with a target line and a 30-day pace label
- **History:** date-grouped log list, filter by activity, per-day mistakes / prompts / tajweed counts, error trend sparkline
- **Quality & retention:** quality index and manzil retention score shown as a 0–100 ring with a one-line plain-English interpretation, not a bare number
- **Doura tracker:** round no, % covered, days remaining, pace vs target
- **Milestones:** juz completions, khatm certificate download, consistency streak
- **Weekly digest:** an opt-in Friday push summarising the week — lines memorized, days logged, grade trend

#### 10.4.6 Presentation Guardrails for the Parent View

- Never surface the internal `stuck flag` as a label to a guardian. Surface it as a teacher-authored remark instead, so a human frames it.
- Grade labels are localized (Malayalam) and paired with a short descriptor; `NOT_READY` renders as "needs to repeat", not as a failure state.
- Show the ranges in the mushaf's own terms (Surah name + ayah, page number) — never as internal ayah indices.

**API**

```
GET  /api/v1/hifz/roster?batchId=&date=&activity=      → students + last log + suggested range
POST /api/v1/hifz/logs/batch                            Idempotency-Key required
GET  /api/v1/hifz/logs?enrollmentId=&from=&to=&activity=
POST /api/v1/hifz/logs/:id/correct
GET  /api/v1/hifz/progress/:enrollmentId                → snapshot + juz map + curve series
GET  /api/v1/hifz/batch-summary?batchId=&month=
POST /api/v1/doura/rounds                               { enrollmentId, roundNo, startedOn, targetEndOn }
PATCH /api/v1/doura/rounds/:id                          { status, completedOn, remark }
GET  /api/v1/doura/rounds/:id/coverage
GET  /api/v1/quran/index                                → bundled offline, endpoint for cache refresh only
```

---

### M05 · Academics — Islamic Studies & General Education

**Purpose.** Conventional class/subject/timetable structure for the two subject-based departments. Identical model, different department scope.

**Admin Console**

- Class & section CRUD, subject catalogue per department
- Subject–teacher–class mapping matrix
- Timetable builder: weekly grid, drag-drop, clash detection (teacher double-booked, room conflict), effective-date versioning
- Syllabus upload per subject, chapter/unit progress tracking
- Substitution management (absent teacher → cover assignment, notifies both)

**Flutter — Teacher**

- `Today` timeline of periods with room + class
- Per-period: take attendance · post class note · mark syllabus progress · assign homework
- Weekly timetable view

**Flutter — Parent**

- Ward's timetable (day + week), next-period card on the ward overview
- Subject detail: teacher, syllabus progress, class notes, materials
- Homework list with due dates and submission status
- Class-teacher and subject-teacher contact (tap-to-call / WhatsApp)

**Rules**

- Timetable slots are versioned by `effective_from` / `effective_to` — historical attendance must resolve against the timetable that was live on that date.
- Clash detection is a hard block on save for teacher conflicts, a warning for room conflicts.
- A period-mode attendance record requires a valid `timetable_slot_id`.

**API**

```
GET/POST/PATCH /api/v1/classes
GET/POST/PATCH /api/v1/subjects
GET  /api/v1/timetable?classSectionId=|batchId=|staffId=&date=
POST /api/v1/timetable/slots            (with clash validation)
POST /api/v1/timetable/substitutions
GET/POST /api/v1/homework
GET/POST /api/v1/syllabus-progress
```

---

### M06 · Examination & Assessment

**Purpose.** Exam lifecycle from scheduling → question paper → marks entry → verification → publish, supporting both formative (continuous) and summative (terminal) assessment.

**Lifecycle**

```
draft → scheduled → ongoing → marks_entry → verification → published
                                    ↑              │
                                    └──── reopen ───┘ (admin only, audited)
```

**Admin Console**

- Exam creation: name, department, type (formative/summative), term, weightage
- Schedule builder per class/batch/subject with date, time, max/pass marks, invigilator
- Question paper upload (PDF, R2) with **time-gated access** — teachers can download only from `exam_date − 1h`
- Marks entry monitoring dashboard: which subjects are pending, which teacher
- Verification & publish workflow; publish triggers push to students + parents
- Grade scale configuration per department
- Hall ticket / seating plan generation (optional, Phase 3)

**Flutter — Teacher**

- Marks entry screen: class roster, numeric keypad-optimized input, mark-absent toggle, running "entered N of M", offline-capable
- Validation inline: `marks ≤ max_marks`, non-negative, decimals per config
- Submit → status `entered`; locked after `verified`
- Formative assessment: lightweight rubric entry (skill × level) rather than raw marks

**Flutter — Parent**

- Exam timetable with countdown and syllabus notes per paper
- Results screen post-publish: subject-wise marks, grade, percentage, pass/fail, class average comparison, and rank if `showRankToParents` is enabled
- Historical exam comparison chart across terms
- Report card PDF download and share

**Rules**

- Marks are invisible to guardians until `published`. Enforced server-side in the query layer, not by hiding UI.
- Mark corrections after publish create a superseding row and a `RESULT_REVISED` notification.
- Final grade = weighted sum of formative + summative per department config.
- Absent students are excluded from class average, included in pass-percentage denominators.
- Hifz department "exams" use a different sheet: evaluation of memorized portions (juz-wise oral test, error count, tajweed grade) rather than written marks.

**API**

```
GET/POST/PATCH /api/v1/exams
POST /api/v1/exams/:id/schedules
GET  /api/v1/exams/:id/marks-entry?scheduleId=
POST /api/v1/exams/marks/batch                 Idempotency-Key required
POST /api/v1/exams/:id/verify
POST /api/v1/exams/:id/publish
GET  /api/v1/results/student/:enrollmentId?examId=
GET  /api/v1/exams/:id/question-paper          → signed, time-gated URL
```

---

### M07 · Progress Reports

**Purpose.** Consolidated periodic report combining attendance, Hifz progress, subject performance, conduct and remarks — generated as an immutable JSON snapshot plus a rendered PDF.

**Composition (department-aware)**

| Section                              | Hifz & Doura | Islamic Studies | General Education |
| ------------------------------------ | ------------ | --------------- | ----------------- |
| Attendance summary                   | ✅           | ✅              | ✅                |
| Sabaq / Sabqi / Manzil summary       | ✅           | —               | —                 |
| Pages & juz memorized, quality index | ✅           | —               | —                 |
| Doura round status                   | ✅           | —               | —                 |
| Subject-wise marks & grade           | —            | ✅              | ✅                |
| Formative rubric summary             | —            | ✅              | ✅                |
| Daily activity & conduct highlights  | ✅           | ✅              | ✅                |
| Teacher remark + Dept Head remark    | ✅           | ✅              | ✅                |

**Flow**

1. Admin/Dept Head triggers generation for a period + scope (batch / class / department)
2. Trigger.dev job computes each student's snapshot → `progress_reports.payload`
3. Teachers add remarks on their assigned students (Flutter: a remark queue screen)
4. Dept Head approves → PDF rendered to R2 → status `published`
5. Push to all linked guardians; PDF viewable, downloadable and shareable in-app

**Rules**

- Once published, `payload` is **immutable**. Corrections issue a new report version with `revision_no`.
- A report cannot publish while any assigned teacher remark is missing (configurable).
- PDF is bilingual (English + Malayalam labels), institution letterhead, QR code linking to a verification URL.

**API**

```
POST /api/v1/progress-reports/generate    { scope, periodType, from, to }
GET  /api/v1/progress-reports?enrollmentId=
POST /api/v1/progress-reports/:id/remark
POST /api/v1/progress-reports/:id/approve
POST /api/v1/progress-reports/:id/publish
GET  /api/v1/progress-reports/:id/pdf      → signed URL
```

---

### M08 · Daily Activities

**Purpose.** The daily-life feed of the institution — what a class/batch/hostel did today. This is the module that makes the Parent app feel alive rather than administrative.

**Flutter — Teacher / Warden**

- Compose: category, title, description, up to 5 photos, audience scope (batch / class / individual student). Visibility is `PARENT` for shared posts and `STAFF_ONLY` for internal notes — the `STUDENT` value is removed from the enum
- Quick templates: "Quran competition", "Cleanliness inspection", "Sports period", "Guest lecture"
- Individual student conduct note (positive or corrective) with a `share_with_guardian` flag; unflagged notes stay internal to staff

**Flutter — Parent**

- Chronological feed, date-grouped, image lightbox, filter by category
- Unread badge; push for individual-scoped notes only (not for every batch post, to avoid notification fatigue)

**Rules**

- Media is uploaded via presigned R2 URLs, compressed client-side to ≤ 1600px / 300 KB before upload.
- Conduct notes without `share_with_guardian` are staff-internal and never appear in the Parent app.
- Retention: media older than 2 academic years is archived to cold storage.

**API**

```
GET  /api/v1/activities?scopeType=&scopeId=&from=&to=&cursor=
POST /api/v1/activities
POST /api/v1/uploads/presign            { contentType, purpose }
DELETE /api/v1/activities/:id           (soft, author or admin within 24h)
```

---

### M09 · Leave Management

**Purpose.** Student and staff leave with a multi-stage approval trail, integrated with attendance and hostel gate pass. **All student leave is requested by a guardian** — there is no student-initiated path.

**Approval chains (configurable)**

```
Student · day scholar  : Class Teacher → (auto) Dept Head if > 3 days
Student · hosteller    : Class Teacher → Hostel Warden → Dept Head if > 3 days
Staff                  : Dept Head → Admin
Emergency              : single-stage Admin/Warden override, back-filled later
```

**Flutter — Parent**

- Request leave for ward: type, from/to, half-day toggle, reason, optional attachment (medical certificate)
- Status timeline with each approver's action and note
- Gate pass card (QR) once approved for a hosteller — shown at the gate

**Flutter — Teacher / Warden**

- Approvals inbox with swipe approve/reject, bulk approve, note required on reject
- Push on new request; badge on the shell

**Rules**

- Approved leave auto-marks attendance as `LEAVE` for the covered dates and blocks teacher marking (override with reason).
- Overlapping requests for the same student/date are rejected at creation, including across two different guardians of the same student.
- Only guardians with `can_approve_leave = true` may raise a request for a ward.
- Hosteller leave creates a `gate_pass_no` and expects an `actual_return_at` scan/entry; overdue returns notify the warden.
- Leave cancellation is allowed only while `pending`, or by admin after approval (reverts the attendance marks).

**API**

```
POST /api/v1/leave                      { subjectType, studentId?, type, from, to, reason }
GET  /api/v1/leave?status=&studentId=&cursor=
POST /api/v1/leave/:id/decide           { action, note }
POST /api/v1/leave/:id/cancel
GET  /api/v1/leave/approvals/inbox
POST /api/v1/leave/:id/return           { actualReturnAt }
```

---

### M10 · Hostel Management

**Purpose.** Occupancy management down to bed level, night roll call, and gate movement.

**Hierarchy:** `Hostel → Block → Room → Bed → Student`

**Admin / Warden Console**

- Visual occupancy grid: rooms as cards, beds as slots, colour-coded vacant/occupied/maintenance
- Allocation: drag a student onto a bed, or bulk-allocate a batch
- Room transfer with reason and history preservation
- Maintenance flags (room out of service → beds unavailable)
- Occupancy report: total/occupied/vacant by block, by gender

**Flutter — Warden**

- Night roll call: room-by-room list, present/absent/on-leave toggles, finish in one pass
- Absent-without-leave alert → immediate push to admin + guardian
- Gate pass verification (scan the QR from the guardian's app at the gate)
- Visitor log entry

**Flutter — Parent**

- Room and bed number, block, warden contact
- Roll-call history, gate pass status

**Rules**

- A bed holds at most one active allocation (`vacated_on IS NULL`) — enforced by a partial unique index.
- Allocating a day scholar requires first changing `students.residency` to `HOSTELLER` (guarded, audited).
- Night roll call is a distinct record from academic attendance — never conflate the two.
- `ABSENT` at roll call with no approved leave escalates: warden → admin → primary guardian, in that order, 15 minutes apart.

**API**

```
GET/POST/PATCH /api/v1/hostels|blocks|rooms|beds
POST /api/v1/hostel/allocations         { studentId, bedId, allocatedOn }
POST /api/v1/hostel/allocations/:id/vacate
POST /api/v1/hostel/rollcall/batch      Idempotency-Key required
GET  /api/v1/hostel/occupancy?hostelId=
POST /api/v1/hostel/gatepass/verify     { gatePassNo }
```

---

### M11 · Canteen Management

> ⚠️ The handwritten notes state only "Canteen Management" with no workflow. The scope below is a **proposal** and must be confirmed before build. See §14.

**Proposed scope (Phase 3)**

**Admin / Canteen Manager**

- Item catalogue with unit prices
- Daily menu planner per meal type (breakfast / lunch / snacks / dinner), publishable a week ahead
- Meal attendance capture (who ate) — by batch scan or manual roster
- Consumption report: headcount per meal per day, wastage tracking
- Optional prepaid wallet: credit top-ups by office, debits per meal, monthly statement per student

**Flutter — Parent**

- This week's menu
- Ward's meal record and wallet balance / statement
- Low-balance alert and top-up instructions

**Rules**

- Meal records are unique per `(student, date, meal_type)`.
- Wallet balance can go negative up to a configured credit limit; blocked beyond.
- Students on approved leave are excluded from headcount projections automatically.

**API**

```
GET/POST /api/v1/canteen/items
GET/POST /api/v1/canteen/menus?date=
POST /api/v1/canteen/meal-records/batch
GET  /api/v1/canteen/ledger/:studentId
POST /api/v1/canteen/transactions
GET  /api/v1/canteen/reports/consumption?from=&to=
```

---

### M12 · Announcements & Notifications

**Purpose.** One-way institutional communication + the push infrastructure every other module depends on.

**Announcements**

- Admin/Dept Head composes with an audience selector (roles × departments × batches × classes × hostel)
- Schedule publish, pin, expiry, attachments
- Read receipts (count only, per announcement)
- Optional WhatsApp fan-out via Cloud API for high-priority circulars

**Notification catalogue**

| Event                                   | To                          | Channel           |
| --------------------------------------- | --------------------------- | ----------------- |
| Marked absent                           | All linked guardians        | Push              |
| Leave decision                          | Requester                   | Push              |
| New leave request                       | Approver                    | Push              |
| Result published                        | All linked guardians        | Push + in-app     |
| Progress report published               | All linked guardians        | Push              |
| Hifz milestone (juz / khatm)            | All linked guardians, Admin | Push + WhatsApp   |
| Roll-call absent without leave          | Warden, Admin, Guardian     | Push (escalating) |
| Low canteen balance                     | Parent                      | Push              |
| Announcement                            | Audience                    | Push              |
| Weekly Hifz digest (opt-in)             | Primary guardian            | Push, Friday      |
| Pending attendance not marked by cutoff | Teacher                     | Push              |

**Rules**

- Per-user notification preferences with category toggles; critical safety notifications (roll-call absence) cannot be disabled.
- Fan-out targets **all guardians** linked to the student by default, with a per-student setting to restrict routine notifications to the primary guardian only. Critical notifications always go to every linked guardian.
- Quiet hours default 21:30–06:00 except critical.
- All pushes carry a `route` for deep linking.

---

### M13 · Master Data & Settings (Admin only)

- Academic year lifecycle: create, set current, roll over (promotes enrollments, archives timetables)
- Holiday calendar and working-day definition per department (Hifz often runs on days General Education does not — this is why working-day counts are department-scoped)
- Grade scales, assessment weightages
- Institution settings: `parent_performance_visibility` (default `full`), `hifzBackdateDays`, `attendanceCutoffTime`, `showRankToParents`, `notifyAllGuardians`, `minSupportedAppVersion`
- Guardian account management: re-invite, revoke, transfer a ward to a different guardian
- Role & permission assignment
- Data export (CSV/XLSX) and full backup download
- Audit log viewer with actor/entity/date filters

---

## 11. Reporting & Analytics

**Admin dashboard cards:** total students by department · today's attendance % · pending attendance by teacher · leave requests awaiting action · hostel occupancy · students below 75% attendance · Hifz khatm pipeline (students within 2 juz of completion) · stuck-student watchlist.

**Standard reports (all exportable to XLSX + PDF):**

| Report                         | Filters                                                      |
| ------------------------------ | ------------------------------------------------------------ |
| Attendance register            | department, batch/class, month                               |
| Defaulter list (< X%)          | department, threshold, date range                            |
| Hifz progress register         | batch, month — pages, lines/day, quality index per student   |
| Sabaq/Sabqi/Manzil daily sheet | batch, date — the digital replacement for the paper register |
| Doura status                   | department, round                                            |
| Examination result sheet       | exam, class — marks, grade, rank, pass %                     |
| Consolidated mark list         | academic year, class                                         |
| Leave register                 | subject type, date range, status                             |
| Hostel occupancy & roll-call   | hostel, month                                                |
| Canteen consumption            | meal type, date range                                        |
| Teacher workload               | staff, week — periods, batches, marks-entry pendency         |

Heavy reports are generated as background jobs (Trigger.dev), stored to R2, and delivered via a notification with a download link rather than blocking the request.

---

## 12. Non-Functional Requirements

| Area              | Requirement                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Availability**  | 99.5% monthly for API. Mobile apps remain functional read/write offline during outages.                                                                                                                                                                                                                                                                                                                    |
| **Performance**   | p95 API latency < 400 ms for reads, < 700 ms for batch writes of 50 items.                                                                                                                                                                                                                                                                                                                                 |
| **Scale target**  | 2,000 students · 150 staff · 3,000 guardian accounts · ~60k academic rows/month. Comfortably within a single Neon instance for years.                                                                                                                                                                                                                                                                      |
| **Security**      | TLS everywhere · JWT rotation with reuse detection · RBAC enforced server-side in the query layer · R2 objects served only via short-lived signed URLs · rate limiting per user and IP · OWASP MASVS L1 for mobile · certificate pinning in prod builds.                                                                                                                                                   |
| **Privacy**       | Student data is minor data, and since students hold no accounts, guardians exercise all data rights on their behalf. No third-party analytics on student PII. Photos accessible only to authorized scopes. Guardian phone numbers masked in teacher UI behind a tap-to-call action. Every guardian→student link is audited and reviewable. Data retention and deletion policy documented and configurable. |
| **Auditability**  | Every academic mutation is append-only with actor, timestamp, device and before/after payload.                                                                                                                                                                                                                                                                                                             |
| **Backup**        | Neon PITR (7-day) + nightly logical dump to R2 with 30-day retention + quarterly restore drill.                                                                                                                                                                                                                                                                                                            |
| **Localization**  | English and Malayalam UI, Arabic content. All dates in `Asia/Kolkata`. Hijri date shown alongside Gregorian where relevant.                                                                                                                                                                                                                                                                                |
| **Accessibility** | Minimum 4.5:1 contrast · 48dp touch targets · full screen-reader labels on attendance and hifz controls · text scale support to 1.3×.                                                                                                                                                                                                                                                                      |
| **Devices**       | Android 8.0+ (API 26), iOS 14+. Teacher app must be usable on a 5-inch 2 GB RAM device.                                                                                                                                                                                                                                                                                                                    |
| **Compliance**    | Aligned with India DPDP Act 2023 — consent capture at admission, purpose limitation, guardian consent for minors, breach notification process.                                                                                                                                                                                                                                                             |

---

## 13. Delivery Phases

| Phase                                  | Scope                                                                                                                                     | Outcome                                                                                 |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **P0 — Foundation** (3 wks)            | Monorepo, DB schema + migrations, Better Auth, RBAC engine, Flutter skeleton with design system, sync engine, CI/CD, quran reference seed | Login works on all four clients; sync harness proven with a dummy entity                |
| **P1 — Core Academic** (5 wks)         | M02 Students, M03 Attendance, M04 Hifz & Doura, M13 Master data                                                                           | Teachers replace the paper attendance and Hifz register. **This is the pilot release.** |
| **P2 — Academic Depth** (4 wks)        | M05 Academics/Timetable, M06 Exams, M07 Progress Reports, M12 Announcements                                                               | Full term cycle from timetable to published report card                                 |
| **P3 — Campus Life** (4 wks)           | M08 Activities, M09 Leave, M10 Hostel, M11 Canteen                                                                                        | Parent app becomes the daily touchpoint                                                 |
| **P4 — Analytics & Hardening** (3 wks) | M11 Reports, dashboards, performance tuning, security review, store release, admin training                                               | Production rollout                                                                      |

**Recommended pilot:** run P1 with **two Hifz batches and one class** for a full month before institution-wide rollout. The Hifz quick-log screen will need at least one round of field iteration — no amount of spec substitutes for watching an Ustadh use it in a live halaqa.

---

## 14. Open Questions for Client

These block or reshape the build and should be resolved before P1 detailed design:

**Hifz & Doura (highest priority)**

1. Is Sabqi defined as "current juz" or "last N days"? Should the system enforce the boundary or leave it to the teacher?
2. What is the institution's Manzil schedule — daily fixed portion, weekly cycle, or teacher discretion?
3. Does a Doura round cover the full 30 juz or only the student's memorized portion? Is there a standard duration/target?
4. Is memorization graded on a formal scale, and what are the labels the Ustadhs actually use?
5. Should recitation audio recording be part of the daily log, or is that out of scope?
6. Do batches move as a group through the same sabaq, or is every student on an individual pointer? (Affects the roster screen materially.)

**Policy** 7. ~~Parent visibility posture~~ — **resolved: no student role; guardians receive the full dataset (§2.3).** 8. When a student has two guardians with app access, should routine notifications go to both or only the primary? (`notifyAllGuardians` default.) 9. Who owns the final approval on progress reports — class teacher, department head, or principal? 10. Should older students (doura level, often 16–20) eventually get read-only accounts? Worth confirming now — the schema keeps `students.user_id` reserved for exactly this, and retrofitting later is cheap only if we know it is coming.

**Operational** 11. Working-day calendar: does the Hifz department run on days the General Education department is closed (Fridays, holidays)? 12. Attendance mode per department — full-day, session, or period-wise for each of the three? 13. **Canteen: what is the actual workflow?** Meal attendance only, or billing/wallet? This determines whether M11 is a two-week or a two-day module. 14. Is there a fee management requirement? It is absent from the notes but almost always surfaces mid-project — worth confirming now so the schema can accommodate it. 15. Biometric or RFID attendance hardware — present, planned, or not applicable? 16. Do teachers need a web console, or is mobile sufficient for all teacher workflows? 17. How are guardians onboarded at scale for existing students — bulk SMS invite from the current phone register, or in-person at the office?

---

## 15. Appendix

### 15.1 Glossary

| Term                   | Definition                                                         |
| ---------------------- | ------------------------------------------------------------------ |
| **Sabaq**              | The new portion of Quran memorized on a given day                  |
| **Sabqi / Sabaq Para** | Revision of recently memorized portions, typically the current juz |
| **Manzil**             | Revision of older, consolidated memorization                       |
| **Doura**              | A complete revision round of the Quran                             |
| **Nazira**             | Reading from the mushaf rather than from memory                    |
| **Hifz**               | Memorization of the Quran                                          |
| **Hafiz**              | One who has completed memorization                                 |
| **Khatm**              | Completion of the full Quran                                       |
| **Juz**                | One of 30 parts of the Quran (~20.13 pages)                        |
| **Halaqa**             | A teaching circle; here, a Hifz batch                              |
| **Luqma**              | A prompt given to a student who falters                            |
| **Ustadh**             | Teacher                                                            |
| **Tajweed**            | Rules of correct Quranic pronunciation                             |

### 15.2 Quran Reference Constants (Madani Mushaf, 15-line)

```
Surahs        114
Ayahs         6,236
Pages         604
Juz           30           (≈20.13 pages per juz)
Hizb          60
Rub al-Hizb   240
Lines/page    15           (except pages 1–2)
```

These constants and the full 6,236-row ayah index ship as a read-only SQLite asset in the Flutter app (`assets/quran_index.sqlite`, ~400 KB) so range → page/line/juz derivation works with zero network.

### 15.3 Naming Conventions

| Layer              | Convention                  | Example                   |
| ------------------ | --------------------------- | ------------------------- |
| Postgres           | `snake_case`, plural tables | `hifz_daily_logs`         |
| API JSON           | `camelCase`                 | `fromAyah`, `errorsMajor` |
| Dart classes       | `PascalCase`                | `HifzDailyLog`            |
| Dart files         | `snake_case`                | `hifz_daily_log.dart`     |
| Riverpod providers | `<noun>Provider`            | `hifzRepositoryProvider`  |
| Routes             | kebab-case paths            | `/batches/:batchId/hifz`  |
| Error codes        | `SCREAMING_SNAKE`           | `HIFZ_RANGE_OVERLAP`      |

### 15.4 Architecture Decision Records to Write

`docs/adr/` should capture, at minimum:

1. ADR-001 — Single Flutter app with role shell vs separate Teacher/Parent apps
2. ADR-002 — Riverpod over BLoC for this codebase
3. ADR-003 — Drift over Isar for the offline mirror
4. ADR-004 — Append-only academic ledger with `supersedes_id`
5. ADR-005 — Client-generated UUID v7 + idempotency keys for offline writes
6. ADR-006 — Department-scoped enrollment as the universal academic foreign key
7. ADR-007 — Server-side computation of all derived academic metrics
8. ADR-008 — No student accounts: guardian as the sole non-staff data channel

---

_End of specification. Next artefact: module-level SRS with wireframes and acceptance criteria for P1 (Students, Attendance, Hifz & Doura)._
