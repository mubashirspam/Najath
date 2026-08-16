# M03 · Attendance

**Phase P1.** Department-scoped daily/period attendance with an offline-first
teacher flow. Together with M04 this is what replaces the paper register.

## Modes (configurable per department)

| Mode       | Used by                             |
| ---------- | ----------------------------------- |
| `FULL_DAY` | Hifz department — one mark per day  |
| `SESSION`  | Forenoon / Afternoon                |
| `PERIOD`   | Islamic Studies & General Education |

⛔ **BLOCKED — Q12.** Which mode each of the three departments actually uses is
unconfirmed. Build all three; the per-department setting is `M13`.

## Tasks

### Database & API

| ID           | Task                                                                               | Depends      | Acceptance                                                                   |
| ------------ | ---------------------------------------------------------------------------------- | ------------ | ---------------------------------------------------------------------------- |
| `M03-DB-01`  | `attendance_marks` — enrollment-scoped, append-only, `is_current`, `supersedes_id` | `M02-DB-03`  | A correction inserts and flips; no `UPDATE` path exists                      |
| `M03-DB-02`  | `attendance_sessions` / slot binding per mode                                      | `M03-DB-01`  | A `PERIOD` mark without a valid `timetable_slot_id` is rejected              |
| `M03-DB-03`  | Working-day calendar per department                                                | `M13-DB-02`  | ⛔ **BLOCKED — Q11** (does Hifz run when General Education is closed?)       |
| `M03-API-01` | `GET /attendance/roster?slotId=&date=` → students + existing marks                 | `M03-DB-02`  | Returns students on approved leave already marked `LEAVE`                    |
| `M03-API-02` | `POST /attendance/batch` — up to 100, per-item status, `Idempotency-Key`           | `P0-API-05`  | Same key twice → one row, two identical responses. Test required.            |
| `M03-API-03` | Percentage service — `(present + late + excused) / working_days`, per dept         | `M03-DB-03`  | **One implementation.** Any second place computing this is a bug.            |
| `M03-API-04` | `GET /attendance/student/:enrollmentId?from=&to=`                                  | `M03-DB-01`  | Filters `is_current`; corrections visible as history, not as duplicates      |
| `M03-API-05` | `GET /attendance/summary?batchId=&month=`                                          | `M03-API-03` | Feeds both the parent heatmap and the admin dashboard                        |
| `M03-API-06` | `POST /attendance/:id/correct`                                                     | `M03-DB-01`  | Teacher: same day only. Beyond that returns `ATTENDANCE_EDIT_WINDOW_CLOSED`. |
| `M03-API-07` | Late → `HALF_DAY` conversion above a configurable threshold                        | `M13`        | Threshold is a setting, not a constant                                       |
| `M03-JOB-01` | Absence push at a configurable time (default 10:30 IST)                            | `M12`        | Fires once per student per day, to all linked guardians                      |
| `M03-JOB-02` | "Attendance not marked by cutoff" push to the teacher                              | `M12`        | Only for slots the teacher actually owns today                               |

### App — Teacher (the core flow)

| ID           | Task                                                                                | Depends             | Acceptance                                                                  |
| ------------ | ----------------------------------------------------------------------------------- | ------------------- | --------------------------------------------------------------------------- |
| `M03-APP-01` | `Today` — every slot the teacher owns with `Not marked` / `Marked` / `Pending sync` | `M03-API-01`        | Status is read from the local mirror + outbox, correct with the network off |
| `M03-APP-02` | Roster screen — **default all `PRESENT`**, mark only the absentees                  | `M03-APP-01`        | Marking a 40-student class where 3 are absent takes 3 taps plus submit      |
| `M03-APP-03` | Per-student segmented P / A / L / LV                                                | `M03-APP-02`        | 60 fps scroll on a 40-row roster                                            |
| `M03-APP-04` | Swipe a row → remark + late minutes                                                 | `M03-APP-03`        | Remark persists locally before the sheet closes                             |
| `M03-APP-05` | Sticky footer `Present 34 · Absent 3 · Late 1` + Submit                             | `M03-APP-03`        | Counts update live; submit is never disabled by a pending network call      |
| `M03-APP-06` | Submit → local write, instant return, queued sync                                   | `P0-APP-02`         | < 100 ms perceived; the screen never waits on the network                   |
| `M03-APP-07` | Same-day edit window; beyond it, request an admin unlock                            | `M03-API-06`        | The UI explains the window rather than silently disabling                   |
| `M03-APP-08` | Leave/holiday blocking with teacher override + reason                               | `M03-API-01`, `M09` | An auto-`LEAVE` student is overridable but the override is recorded         |

### App — Parent

| ID           | Task                                            | Depends      | Acceptance                                                          |
| ------------ | ----------------------------------------------- | ------------ | ------------------------------------------------------------------- |
| `M03-APP-09` | Month calendar heatmap, green/amber/red         | `M03-API-05` | Colour is never the only signal — each day carries a letter or icon |
| `M03-APP-10` | Tap a day → period breakdown                    | `M03-API-04` | Shows the corrected value and that it was corrected                 |
| `M03-APP-11` | Rolling percentage + "below 75%" warning banner | `M03-API-03` | The number comes from the server; the app does not divide anything  |

### Console

| ID           | Task                                               | Depends      | Acceptance                                           |
| ------------ | -------------------------------------------------- | ------------ | ---------------------------------------------------- |
| `M03-ADM-01` | Attendance register view per batch/class per month | `M03-API-05` | Exports CSV with the filter state                    |
| `M03-ADM-02` | Correction/unlock workflow with audit              | `M03-API-06` | Admin unlock is audited with a reason                |
| `M03-ADM-03` | "Pending attendance by teacher" dashboard card     | `M03-API-01` | Names the teacher and the slot, links straight to it |

## Rules that bite

- Marking is **blocked for holidays** and for students on approved leave
  (auto-marked `LEAVE`, teacher can override with a reason).
- Percentage lives in **one server service**. Not in the app, not in the console,
  not in a second query.
- Corrections are append-only — new row with `supersedes_id`, old row
  `is_current = false`.
- Attendance is department-scoped. There is no "the student's attendance".

## API surface

```
GET  /api/v1/attendance/roster?slotId=&date=        → students + existing marks
POST /api/v1/attendance/batch                        Idempotency-Key required
     { slotId, date, session, marks:[{enrollmentId,status,minutesLate,remark,clientId}] }
GET  /api/v1/attendance/student/:enrollmentId?from=&to=
GET  /api/v1/attendance/summary?batchId=&month=
POST /api/v1/attendance/:id/correct
```
