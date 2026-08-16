# M13 · Master Data & Settings

**Phase P1, but build it first.** Admin console only. Nothing can be enrolled,
scheduled, marked or examined until departments, batches, classes and the
academic year exist. It is the least interesting module and it blocks M02–M06.

## Tasks

### Academic structure

| ID           | Task                                                                         | Depends     | Acceptance                                                                                                                   |
| ------------ | ---------------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `M13-DB-01`  | `institutions`, `academic_years`, `departments`, `batches`, `class_sections` | `P0-DB-01`  | Three departments seed: HIFZ_DOURA, ISLAMIC_STUDIES, GENERAL_EDUCATION                                                       |
| `M13-DB-02`  | Holiday calendar and working-day definition **per department**               | `M13-DB-01` | ⛔ **BLOCKED — Q11.** Hifz often runs when General Education does not — this is why working-day counts are department-scoped |
| `M13-DB-03`  | Grade scales and assessment weightages per department                        | `M13-DB-01` |                                                                                                                              |
| `M13-DB-04`  | `institution_settings`                                                       | `M13-DB-01` | Every setting below has a default and is readable from `/session`                                                            |
| `M13-API-01` | Academic year lifecycle — create, set current, roll over                     | `M13-DB-01` | Roll over promotes enrollments and archives timetables, with a dry run first                                                 |
| `M13-API-02` | Settings read/write, audited                                                 | `M13-DB-04` | Changing a setting bumps a version the app can notice                                                                        |
| `M13-API-03` | Role & permission assignment                                                 | `P0-API-03` | **Cannot remove the last SUPER_ADMIN** — guarded server-side                                                                 |
| `M13-API-04` | Data export (CSV/XLSX) and full backup download                              | —           | Export runs as a job; large exports notify on completion                                                                     |
| `M13-API-05` | Audit log query — actor / entity / date filters                              | `P0-DB-04`  | Read-only, and itself audited                                                                                                |

### Console

| ID           | Task                                                             | Depends      | Acceptance                                                         |
| ------------ | ---------------------------------------------------------------- | ------------ | ------------------------------------------------------------------ |
| `M13-ADM-01` | Department, batch and class-section management                   | `M13-API-01` |                                                                    |
| `M13-ADM-02` | Academic year lifecycle UI with roll-over dry run                | `M13-API-01` | Dry run lists what will move before anything moves                 |
| `M13-ADM-03` | Holiday calendar per department                                  | `M13-DB-02`  | Two departments can disagree about whether a date is a working day |
| `M13-ADM-04` | Grade scale and weightage configuration                          | `M13-DB-03`  |                                                                    |
| `M13-ADM-05` | Institution settings screen                                      | `M13-API-02` | Each setting states its effect in one line                         |
| `M13-ADM-06` | **Role & permission matrix** (see the access-matrix rules)       | `M13-API-03` | Shows effective vs overridden; lists what a revocation closes      |
| `M13-ADM-07` | Guardian account management — re-invite, revoke, transfer a ward | `M01-ADM-03` | Transfer audits both sides. This is a security-critical action.    |
| `M13-ADM-08` | Data export + backup download                                    | `M13-API-04` |                                                                    |
| `M13-ADM-09` | Audit log viewer                                                 | `M13-API-05` | Filterable by actor, entity and date range                         |

## Institution settings

| Setting                         | Default | Effect                                                                                                       |
| ------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| `parent_performance_visibility` | `full`  | `summary \| full \| report_card_only`. Enforced **server-side in the query layer**, never by hiding widgets. |
| `hifzBackdateDays`              | `3`     | How far back a teacher may log hifz. Admin is unlimited.                                                     |
| `attendanceCutoffTime`          | `10:30` | When the "not marked" push fires and when absence notifications go out.                                      |
| `showRankToParents`             | `false` | When off, rank is absent from the payload entirely, not hidden client-side.                                  |
| `notifyAllGuardians`            | `true`  | Routine notifications to all linked guardians vs primary only. Critical always goes to all.                  |
| `minSupportedAppVersion`        | —       | Below this the app shows a blocking update screen. The only lever for retiring a broken sync client.         |

## Rules that bite

- Working days are **per department**. A single institution-wide calendar makes
  every Hifz attendance percentage wrong.
- The role matrix cannot lock out the last `SUPER_ADMIN`.
- Settings that control visibility are enforced in the **query layer**. A setting
  that only hides a widget is not a setting, it is a decoration.
- Academic year roll-over is destructive-ish and gets a dry run, a confirmation
  with counts, and an audit trail.
