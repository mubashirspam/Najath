# P0 · Foundation

3 weeks. Outcome: **login works on the admin console and the mobile app, and the
sync harness is proven end-to-end with a dummy entity** — before any real module
depends on it.

Two workstreams: `REC` reconciles what already exists with the spec, `FND` builds
what is missing.

---

## Reconciliation — what the current code gets wrong

The repo was scaffolded and partly built before this spec landed. Four decisions
in the existing code contradict it. They are cheap to change now and expensive
after M04 is built on top of them.

| ID          | Change                                                                     | Why                                                                                                                                                                           | Touches                                                                    |
| ----------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `P0-REC-01` | Replace the 4-role model with the spec's 8 roles                           | Current code has `admin/staff/teacher/guardian`. Spec needs `SUPER_ADMIN, ADMIN, DEPT_HEAD, TEACHER, HOSTEL_WARDEN, CANTEEN_MANAGER, ACCOUNTANT, PARENT`, many-to-many.       | `packages/contracts/src/access.ts`, `packages/auth`, emitted Dart registry |
| `P0-REC-02` | Add scope to the RBAC engine                                               | The current matrix answers "may this role read attendance". It cannot answer "for _this_ batch". Every P1 endpoint needs scope.                                               | `packages/auth`, `packages/core/src/access`                                |
| `P0-REC-03` | Replace `ApiResponse`/`ApiError` with `Result<Failure,T>` + freezed unions | Spec §7.4 is explicit. Sealed unions give exhaustive `when` on failure states; the current class-based error carries no compile-time exhaustiveness.                          | `najath_network`, `najath_core`, every repo impl                           |
| `P0-REC-04` | Replace the JSON box cache with a **relational** drift mirror              | Current `CacheStore` is a Hive-style key/value store. Spec §4.1 rejects that for this project: the offline data is genuinely relational (student → batch → hifz log).         | `najath_local_db`, `najath_sync`, attendance feature                       |
| `P0-REC-05` | Adopt `@riverpod` codegen                                                  | Spec §7.3. Current notifiers are hand-written (carried over from the Telios reference). Codegen gives compile-safe families, which matters once every provider is ward-keyed. | all Flutter feature packages                                               |
| `P0-REC-06` | Rework the outbox to the spec's shape                                      | Current outbox has no `idempotencyKey`, no `entity`/`operation` split, no `SyncCursor`. Delta pull cannot work without a cursor table.                                        | `najath_local_db`, `najath_sync`                                           |
| `P0-REC-07` | Move date handling to `Asia/Kolkata` calendar dates                        | Current code uses `DateTime.now()` and UTC ISO strings for academic dates. A 6 AM Fajr halaqa logs against yesterday.                                                         | `najath_core`, `packages/core`                                             |

> `P0-REC-04` is the big one — roughly a week, and it invalidates the attendance
> feature written against the box store. Do it before M03, not after.

**What survives unchanged:** the monorepo layout, package boundaries, CI, the
Neon branch-per-PR migration flow, the flavor setup, the design-system split, and
the contracts→Dart emitter (which gets new content, not a new mechanism).

---

## Foundation tasks

### Database & contracts

| ID          | Task                                                                    | Depends | Acceptance                                                                    |
| ----------- | ----------------------------------------------------------------------- | ------- | ----------------------------------------------------------------------------- |
| `P0-DB-01`  | Institution, AcademicYear, Department tables                            | —       | Three departments seed; a year can be marked current                          |
| `P0-DB-02`  | Users, roles (M:N), staff, guardians, `student_guardians`               | REC-01  | A user can hold TEACHER + PARENT and both resolve                             |
| `P0-DB-03`  | Students, Enrollment (one row per student per department per year)      | DB-01   | A student enrolled in Hifz + General Education has two enrollments            |
| `P0-DB-04`  | `audit_log`, `idempotency_keys`, `access_policy_version`                | —       | Audit row written in the same transaction as a change                         |
| `P0-DB-05`  | Quran reference seed — 6,236 ayah index with page/line/juz/hizb spans   | —       | `An-Nisa 12→18` resolves to 7 ayah / 1.2 pages / 18 lines                     |
| `P0-DB-06`  | Ship the ayah index as `assets/quran_index.sqlite` (~400 KB, read-only) | DB-05   | Range→page derivation works with the network off; asset generated by a script |
| `P0-CON-01` | Error code enum, response envelope, shared Zod primitives               | —       | Every code has an ARB entry in `en` and `ml`                                  |

### Auth & RBAC

| ID          | Task                                                                            | Depends      | Acceptance                                                            |
| ----------- | ------------------------------------------------------------------------------- | ------------ | --------------------------------------------------------------------- |
| `P0-API-01` | Better Auth: email+password (staff), bearer JWT 15 min / refresh 60 d rotating  | DB-02        | Refresh token reuse is detected and revokes the family                |
| `P0-API-02` | Phone + OTP for guardians; 5 failed attempts → 30-min lockout on the number     | DB-02        | Lockout is per phone number, not per device                           |
| `P0-API-03` | RBAC engine: role × resource × scope × state, matrix encoded as data            | REC-01,02    | Table-driven test covers every cell of spec §3                        |
| `P0-API-04` | `GET /session` → user, roles, scopes, wards, settings, `minSupportedAppVersion` | API-01,02,03 | A teacher-who-is-also-a-parent gets both role sets and both scopes    |
| `P0-API-05` | The request pipeline as reusable middleware                                     | CON-01       | A new route gets rate limit, auth, context, parse, policy, audit free |

### Sync harness

| ID           | Task                                                                    | Depends        | Acceptance                                                                             |
| ------------ | ----------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------- |
| `P0-APP-01`  | drift schema: relational mirror + `SyncOutbox` + `SyncCursor`           | REC-04, REC-06 | Real FKs; a roster query is a join, not N reads                                        |
| `P0-APP-02`  | Outbox drain: FIFO per entity, backoff, pause/resume across 401 refresh | APP-01         | Queue survives a token expiry mid-drain                                                |
| `P0-APP-03`  | Delta pull with per-entity cursor + tombstones                          | APP-01         | A transferred-out student disappears from the roster on next pull                      |
| `P0-APP-04`  | UUID v7 + idempotency key derivation                                    | APP-01         | Same natural key produces the same idempotency key on two devices                      |
| `P0-APP-05`  | `SyncStatusChip` + outbox inspector screen                              | APP-02         | `N pending`; tapping shows each queued op and its last error                           |
| `P0-API-06`  | `GET /sync/pull` + one dummy entity end to end                          | APP-03         | Dummy entity round-trips offline→online with no loss                                   |
| `P0-TEST-01` | **The non-negotiable test**                                             | APP-02,03,04   | Full day, 3 batches, network off, app killed, reopened, network back → 0 loss, 0 dupes |

### App shell & design system

| ID          | Task                                                                            | Depends   | Acceptance                                                                  |
| ----------- | ------------------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------- |
| `P0-APP-06` | `bootstrap.dart` — DI, `runZonedGuarded`, hydration; three flavor entrypoints   | —         | Uncaught errors reach Crashlytics and Sentry                                |
| `P0-APP-07` | Role-resolved shell + `go_router` redirect + role switcher sheet                | API-04    | Switching role rebuilds the router and clears feature providers, no re-auth |
| `P0-APP-08` | `HufzTokens`, theme, `ArabicText`, `OfflineBanner`, `EmptyState`, `StudentTile` | —         | No feature package declares a raw `Color`                                   |
| `P0-APP-09` | ARB scaffolding for `en` + `ml`; `FailureMessageMapper`                         | CON-01    | Every `Failure` variant renders a localized string                          |
| `P0-APP-10` | App version gate — blocking update screen below `minSupportedAppVersion`        | API-04    | Old build cannot proceed past splash                                        |
| `P0-ADM-01` | Console shell: auth, academic-year context in the URL, nav by role              | API-03,04 | A `CANTEEN_MANAGER` sees only the canteen section                           |

### Delivery

| ID          | Task                                                              | Acceptance                                             |
| ----------- | ----------------------------------------------------------------- | ------------------------------------------------------ |
| `P0-OPS-01` | Fastlane → Play Internal + TestFlight from CI on a `staging` push | A tagged build lands in both tracks unattended         |
| `P0-OPS-02` | Sentry + Crashlytics + Axiom wired for all three surfaces         | A thrown error in each surface appears within a minute |
| `P0-OPS-03` | ADR-001…008 written (spec §15.4)                                  | Each ADR states the decision, not just the outcome     |

---

## Exit criteria

P0 is done when a teacher account and a guardian account can both sign in on a
physical device, the guardian sees their wards, the teacher sees their batches,
and `P0-TEST-01` is green in CI. Not before.
