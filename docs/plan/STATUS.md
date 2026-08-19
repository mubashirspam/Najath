# Status

Audited against the code, not against intentions. Updated as work lands.

**Legend** — ✅ done · 🟡 partial (what's missing is named) · ⬜ not started · ⛔ blocked

---

## P0 · Foundation

### Reconciliation with the spec

| ID          | Task                                 | Status                                         |
| ----------- | ------------------------------------ | ---------------------------------------------- |
| `P0-REC-01` | 8 roles replacing the 4-role model   | ✅                                             |
| `P0-REC-02` | Scope in the RBAC engine             | ✅ 16 matrix tests                             |
| `P0-REC-03` | `Result<Failure,T>` + freezed unions | ✅                                             |
| `P0-REC-04` | Relational drift mirror              | ✅ 19 tests                                    |
| `P0-REC-05` | `@riverpod` codegen                  | ⬜ providers hand-written but correctly shaped |
| `P0-REC-06` | Outbox reshaped to the spec          | ✅                                             |
| `P0-REC-07` | `Asia/Kolkata` calendar dates        | ✅ `IstDate`                                   |

### Database & contracts

| ID          | Task                                            | Status                                  |
| ----------- | ----------------------------------------------- | --------------------------------------- |
| `P0-DB-01`  | Institution, AcademicYear, Department           | ✅                                      |
| `P0-DB-02`  | Users, scoped roles, staff, guardians           | ✅                                      |
| `P0-DB-03`  | Students, Enrollment                            | ✅                                      |
| `P0-DB-04`  | `audit_log`, `idempotency_keys`, policy version | ✅                                      |
| `P0-DB-05`  | Quran ayah index seed (6,236 rows)              | ⛔ **needs a real dataset** — see below |
| `P0-DB-06`  | `quran_index.sqlite` asset                      | ⛔ depends on DB-05                     |
| `P0-CON-01` | Error code enum + envelope                      | ✅                                      |

### Auth & RBAC

| ID          | Task                         | Status                                              |
| ----------- | ---------------------------- | --------------------------------------------------- |
| `P0-API-01` | Better Auth email + password | 🟡 configured; no sign-in exercised against a DB    |
| `P0-API-02` | Phone OTP + 30-min lockout   | 🟡 plugin wired; MSG91 transport and lockout ⬜     |
| `P0-API-03` | RBAC engine, matrix as data  | ✅                                                  |
| `P0-API-04` | `GET /session`               | ✅                                                  |
| `P0-API-05` | Request pipeline middleware  | ✅ audit-in-service still to be applied per service |

### Sync harness

| ID           | Task                                | Status                                           |
| ------------ | ----------------------------------- | ------------------------------------------------ |
| `P0-APP-01`  | drift mirror + outbox + cursors     | ✅                                               |
| `P0-APP-02`  | Outbox drain, backoff, 401 pause    | ✅                                               |
| `P0-APP-03`  | Delta pull + tombstones             | 🟡 cursor store and tombstone DAO exist; no pull |
| `P0-APP-04`  | UUID v7 + idempotency keys          | ✅                                               |
| `P0-APP-05`  | Sync chip + outbox inspector        | ✅                                               |
| `P0-API-06`  | `GET /sync/pull` + one dummy entity | ⬜                                               |
| `P0-TEST-01` | **The non-negotiable test**         | ⬜ blocked on APP-03 + API-06                    |

### App shell & design system

| ID          | Task                                  | Status                                              |
| ----------- | ------------------------------------- | --------------------------------------------------- |
| `P0-APP-06` | `bootstrap.dart`, error zone, flavors | 🟡 flavors ✅; `runZonedGuarded` and crash sinks ⬜ |
| `P0-APP-07` | Role shell, router, role switcher     | ✅                                                  |
| `P0-APP-08` | Tokens, theme, shared widgets         | 🟡 `ArabicText` ⬜ (blocks any Quranic rendering)   |
| `P0-APP-09` | ARB `en` + `ml`, failure messages     | ⬜ strings are English literals today               |
| `P0-APP-10` | App version gate screen               | 🟡 server side ✅; blocking screen ⬜               |
| `P0-ADM-01` | Console shell, year context, role nav | ⬜                                                  |

### Delivery

| ID          | Task                         | Status                   |
| ----------- | ---------------------------- | ------------------------ |
| `P0-OPS-01` | Fastlane → Play / TestFlight | ⬜                       |
| `P0-OPS-02` | Sentry, Crashlytics, Axiom   | ⬜                       |
| `P0-OPS-03` | ADR-001…008                  | 🟡 only ADR-0001 written |

---

## Modules

Nothing below has started beyond the attendance slice, which exists as the
pattern exemplar rather than as a finished module.

| ID  | Module                   | Phase | Status                                                      |
| --- | ------------------------ | ----- | ----------------------------------------------------------- |
| M01 | Authentication & Session | P0    | 🟡 `/session` ✅, login screen ✅; OTP transport ⬜         |
| M02 | Student Management       | P1    | ⬜ schema ✅, no API or screens                             |
| M03 | Attendance               | P1    | 🟡 offline slice ✅ (mirror, outbox, roster); no API, no DB |
| M04 | Hifz & Doura ⭐          | P1    | ⛔ blocked on the ayah index                                |
| M05 | Academics & Timetable    | P2    | ⬜ schema ✅ only                                           |
| M06 | Exams                    | P2    | ⬜                                                          |
| M07 | Progress Reports         | P2    | ⬜                                                          |
| M08 | Daily Activities         | P3    | ⬜                                                          |
| M09 | Leave                    | P3    | ⬜                                                          |
| M10 | Hostel                   | P3    | ⬜                                                          |
| M11 | Canteen                  | P3    | ⛔ scope unconfirmed (Q13)                                  |
| M12 | Announcements & Push     | P2    | ⬜ infrastructure needed from P0                            |
| M13 | Master Data & Settings   | P1    | ⬜ schema ✅, no console                                    |

---

## Recently closed

`P0-TEST-01` is green. A full day for three batches — 66 marks — written with no
network, the database closed and reopened from disk, then drained: zero loss,
zero duplicates. It found a real bug on the way in, described below.

## The two hard blockers

**The Quran ayah index (`P0-DB-05`).** M04 — the product's core differentiator —
cannot start without it. Surah ayah counts and absolute ayah ordering are stable
and can be generated, which alone unblocks range validation (`M04-API-03`). What
cannot be generated is the **Madani 15-line page and line spans** for all 6,236
ayahs. That needs a real dataset — [QUL](https://qul.tarteel.ai) or
[Tanzil](https://tanzil.net). Inventing it in a Hifz application is not an option.

**Client question Q6.** Does a halaqa move as a group through the same sabaq, or
is every student on an individual pointer? It changes the quick-log roster
materially, and that screen is the product.

## Known gaps carried deliberately

- **The rate limiter is per-instance.** In-process memory, so on Vercel it is
  per-lambda. Enough to blunt a stuck retry loop; **not** enough for credential
  stuffing. `POST /auth/otp/request` needs a shared store before launch.
- **Audit writes are per-service, not middleware.** The rule is "same transaction
  as the change", which a wrapper committing separately cannot honour.
  `setRoleScreenAccess` shows the pattern.
- **The outbox dedupes on the idempotency key, not the row id.** An append-only
  correction gets a new row id each time, so deduping on the id queued three
  requests for three taps — and since all three carried the same key, the server
  would have honoured the _first_ and discarded the teacher's final answer. The
  replay test caught it.
- **`freezed` is on a `3.2.6-dev` prerelease**, held there by the analyzer 12
  ceiling that also pins `melos` and `drift_dev`.
