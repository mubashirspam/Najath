# M02 · Student Management

**Phase P1.** The master record every other module hangs off.

## Surfaces

| Surface | Scope                                                                    |
| ------- | ------------------------------------------------------------------------ |
| Console | List + filters, admission wizard, Student 360, CSV import, promotion     |
| App     | Teacher: roster tile → student detail. Parent: ward grid → ward overview |

## Tasks

### Database & API

| ID           | Task                                                                    | Depends      | Acceptance                                                                |
| ------------ | ----------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------- |
| `M02-DB-01`  | `students` — admission_no unique+immutable, status, residency, photo    | `P0-DB-03`   | Status transitions to `alumni/transferred/dropped`; no delete path exists |
| `M02-DB-02`  | `guardians`, `student_guardians` (is_primary, can_approve_leave)        | `P0-DB-02`   | Constraint: every student has ≥ 1 `is_primary` guardian                   |
| `M02-DB-03`  | `enrollments` — one row per student per department per academic year    | `P0-DB-03`   | A Hifz + General Education student has two enrollments, both queryable    |
| `M02-API-01` | `GET /students` — filters, cursor pagination, scope-aware               | `P0-API-03`  | A teacher sees only assigned students; a parent only their wards          |
| `M02-API-02` | `POST /students` + `POST /students/:id/enrollments`                     | `M02-DB-03`  | Creating without a primary guardian is rejected with a field-level error  |
| `M02-API-03` | `PATCH /students/:id` — audited                                         | `M02-DB-01`  | `admission_no` is rejected as an update field                             |
| `M02-API-04` | `POST /students/:id/guardians` — admin-only write path, full audit      | `M02-DB-02`  | Every write logs actor, before, after. This is a security-critical table. |
| `M02-API-05` | `GET /students/:id/overview` — aggregated 360 payload                   | M03, M04     | One request, no N+1; served from read replica                             |
| `M02-API-06` | `POST /students/import` — CSV multipart with **dry-run** validation     | `M02-API-02` | Dry run reports every row's errors before anything is written             |
| `M02-API-07` | Promotion — end-of-year batch/class advancement with rollback           | `M13`        | Rollback restores prior enrollments exactly; both directions audited      |
| `M02-API-08` | Photo upload — presigned R2 PUT, server resize to 400×400 webp          | —            | Original is discarded; only the resized object is retained                |
| `M02-JOB-01` | Guardian reconciliation report — students with 0 or >1 primary guardian | `M02-DB-02`  | Runs nightly; result visible in the console                               |

### Console

| ID           | Task                                                                                                                          | Depends      | Acceptance                                                            |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------- | ------------ | --------------------------------------------------------------------- |
| `M02-ADM-01` | Student list — filters (dept, batch, class, residency, status), bulk ops                                                      | `M02-API-01` | Filters in the URL; a filtered view is shareable                      |
| `M02-ADM-02` | Admission wizard: personal → guardians → enrollments → hostel → docs                                                          | `M02-API-02` | Refresh mid-wizard does not lose entered guardian details             |
| `M02-ADM-03` | Guardian app invite step (SMS, phone is the credential)                                                                       | `M01-API-08` | ⛔ **BLOCKED — Q17**                                                  |
| `M02-ADM-04` | Student 360 — Profile · Enrollments · Attendance · Hifz · Academics · Exams · Leave · Hostel · Canteen · Documents · Activity | `M02-API-05` | Tabs lazy-load; the page is usable before every tab resolves          |
| `M02-ADM-05` | CSV import UI with the dry-run report                                                                                         | `M02-API-06` | The report is downloadable and names the row and column of each error |
| `M02-ADM-06` | Promotion tool with rollback                                                                                                  | `M02-API-07` | Confirms with a count and a five-name sample before executing         |

### App

| ID           | Task                                                                                                 | Depends      | Acceptance                                                           |
| ------------ | ---------------------------------------------------------------------------------------------------- | ------------ | -------------------------------------------------------------------- |
| `M02-APP-01` | Teacher: student detail — photo, admission no, batch, attendance %, current sabaq, last-7-day errors | `M02-API-05` | Renders from the local mirror with the network off                   |
| `M02-APP-02` | Teacher: guardian call / WhatsApp shortcut                                                           | `M02-DB-02`  | Dials the primary guardian; secondary reachable in one more tap      |
| `M02-APP-03` | Parent: ward card grid                                                                               | `M01-APP-04` | One ward skips the grid entirely                                     |
| `M02-APP-04` | Parent: ward overview — photo, admission no, department chips, today-at-a-glance                     | `M02-API-05` | "Today" is correct offline from cached data, with a staleness marker |
| `M02-APP-05` | Parent: full profile, read-only, with `Request correction` → note to the office                      | `M02-API-04` | Guardians never edit master data directly                            |

## Rules that bite

- `admission_no` is **immutable and unique for life**; alumni keep theirs.
- **Deleting a student is never allowed.** Status changes to
  `alumni | transferred | dropped` with a reason and a date.
- A student **must** have at least one `is_primary` guardian — a hard database
  constraint, because it is the only channel through which information reaches
  the family.
- Changing a primary guardian's phone revokes sessions on the old number.
- `student_guardians` is security-critical: admin-only write path, full audit,
  and the nightly reconciliation report (`M02-JOB-01`).

## API surface

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
