# Build plan

Module-by-module, task-based. Every task is small enough to be one PR and
carries an acceptance line you can argue about before writing code.

Read [`docs/engineering/`](../engineering/README.md) first — the plans assume
those rules and do not repeat them.

## Task IDs

```
M04-API-03      module · surface · sequence
P0-REC-02       phase  · workstream · sequence
```

| Surface | Meaning                                       |
| ------- | --------------------------------------------- |
| `DB`    | Drizzle schema, migration, seed               |
| `API`   | `/api/v1` route + service + policy + contract |
| `ADM`   | Admin console screen or flow                  |
| `APP`   | Flutter — teacher, parent or warden           |
| `JOB`   | Trigger.dev task                              |
| `TEST`  | A test that is itself the deliverable         |

Order inside a module is `DB → API → ADM/APP`. A Flutter task never starts
before its API task is merged and its contract is published — otherwise the app
is written against an imagined response shape.

## Phases

| Phase                   | Weeks | Modules                                        | Outcome                                                             |
| ----------------------- | ----- | ---------------------------------------------- | ------------------------------------------------------------------- |
| **P0 — Foundation**     | 3     | [Foundation](p0-foundation.md), M01            | Login works on all clients; sync harness proven with a dummy entity |
| **P1 — Core Academic**  | 5     | M02, M03, M04, M13                             | Teachers replace the paper register. **Pilot release.**             |
| **P2 — Academic Depth** | 4     | M05, M06, M07, M12                             | Full term cycle, timetable → published report card                  |
| **P3 — Campus Life**    | 4     | M08, M09, M10, M11                             | Parent app becomes the daily touchpoint                             |
| **P4 — Hardening**      | 3     | Reporting, dashboards, perf, security, release | Production rollout                                                  |

**Pilot before rollout:** run P1 with two Hifz batches and one class for a full
month. The quick-log screen will need at least one round of field iteration —
no spec substitutes for watching an Ustadh use it in a live halaqa.

## Modules

| ID                             | Module                        | Phase | Notes                                |
| ------------------------------ | ----------------------------- | ----- | ------------------------------------ |
| [M01](m01-auth-session.md)     | Authentication & Session      | P0    | Multi-role, phone OTP for guardians  |
| [M02](m02-students.md)         | Student Management            | P1    | The record everything else hangs off |
| [M03](m03-attendance.md)       | Attendance                    | P1    | Department-scoped, offline-first     |
| [M04](m04-hifz-doura.md)       | Hifz & Doura                  | P1    | ⭐ The product. Largest module.      |
| [M05](m05-academics.md)        | Academics & Timetable         | P2    |                                      |
| [M06](m06-exams.md)            | Examination & Assessment      | P2    |                                      |
| [M07](m07-progress-reports.md) | Progress Reports              | P2    | Depends on M03, M04, M06             |
| [M08](m08-activities.md)       | Daily Activities              | P3    |                                      |
| [M09](m09-leave.md)            | Leave Management              | P3    |                                      |
| [M10](m10-hostel.md)           | Hostel Management             | P3    |                                      |
| [M11](m11-canteen.md)          | Canteen Management            | P3    | Scope depends on open question 13    |
| [M12](m12-announcements.md)    | Announcements & Notifications | P2    |                                      |
| [M13](m13-master-data.md)      | Master Data & Settings        | P1    | Admin only. Blocks M02–M06.          |

## Dependency graph

```
        P0 Foundation ── M01 Auth
                            │
                     ┌──────┴───────┐
                  M13 Master     M02 Students
                     │               │
        ┌────────────┼───────────────┼────────────┐
     M03 Attendance  │        M04 Hifz & Doura    │
        │            │               │            │
        │        M05 Academics       │        M09 Leave
        │            │               │            │
        │        M06 Exams           │        M10 Hostel
        └────────────┴───────┬───────┘            │
                     M07 Progress Reports     M11 Canteen
                             │
                      M12 Announcements ─ M08 Activities
```

M13 blocks almost everything — departments, batches, classes and the academic
year have to exist before a student can be enrolled in one. Build it first even
though it is the least interesting module.

## Blocked on the client

Spec §14 lists 17 open questions. These block detailed design and are marked in
the module files as **`⛔ BLOCKED — Q<n>`**:

| Q   | Question                                              | Blocks          |
| --- | ----------------------------------------------------- | --------------- |
| 1   | Is Sabqi "current juz" or "last N days"?              | M04-API-04      |
| 2   | Manzil schedule — daily, weekly cycle, or discretion? | M04-API-04      |
| 3   | Doura scope — full 30 juz or memorized portion only?  | M04-DB-02       |
| 4   | Formal grading scale and the labels Ustadhs use       | M04-DB-01       |
| 5   | Is recitation audio in scope for the daily log?       | M04-APP-05      |
| 6   | Batch moves as a group, or individual pointer?        | M04-APP-02 ⭐   |
| 11  | Does Hifz run on days General Education is closed?    | M03-API-03, M13 |
| 12  | Attendance mode per department                        | M03-DB-01       |
| 13  | Canteen — meal attendance only, or billing/wallet?    | All of M11      |
| 14  | Is fee management in scope?                           | Schema headroom |
| 15  | Biometric / RFID attendance hardware                  | M03 scope       |
| 16  | Do teachers need a web console?                       | Console scope   |
| 17  | How are guardians onboarded at scale?                 | M01-ADM-03      |

**Q6 is the one to chase first.** Whether a halaqa moves as a group or every
student carries an individual pointer changes the roster screen materially, and
that screen is the product.
