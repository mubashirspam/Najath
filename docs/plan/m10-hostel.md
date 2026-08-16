# M10 · Hostel Management

**Phase P3.** Occupancy down to bed level, night roll call, and gate movement.

**Hierarchy:** `Hostel → Block → Room → Bed → Student`

## Tasks

| ID           | Task                                                                | Depends            | Acceptance                                                                            |
| ------------ | ------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------- |
| `M10-DB-01`  | `hostels`, `blocks`, `rooms`, `beds`                                | `M13-DB-01`        | Room maintenance flag takes its beds out of service                                   |
| `M10-DB-02`  | `hostel_allocations` with `vacated_on`                              | `M10-DB-01`        | **Partial unique index**: at most one active allocation per bed                       |
| `M10-DB-03`  | `rollcall_records` — distinct from academic attendance              | `M02-DB-03`        | Never joined to or conflated with `attendance_marks`                                  |
| `M10-DB-04`  | `visitor_log`                                                       | `M10-DB-01`        |                                                                                       |
| `M10-API-01` | Hostel/block/room/bed CRUD                                          | `M10-DB-01`        |                                                                                       |
| `M10-API-02` | `POST /hostel/allocations` — requires `residency = HOSTELLER`       | `M10-DB-02`, `M02` | Allocating a day scholar is rejected; changing residency is a separate audited action |
| `M10-API-03` | `POST /hostel/allocations/:id/vacate` — history preserved           | `M10-DB-02`        | Room transfer is vacate + allocate, both retained                                     |
| `M10-API-04` | `POST /hostel/rollcall/batch` — `Idempotency-Key`                   | `M10-DB-03`        | One pass, room by room                                                                |
| `M10-API-05` | Absent-without-leave escalation                                     | `M09`, `M12`       | **Warden → Admin → primary guardian, 15 minutes apart.** Cannot be disabled.          |
| `M10-API-06` | `GET /hostel/occupancy?hostelId=`                                   | `M10-DB-02`        | Total/occupied/vacant by block and by gender                                          |
| `M10-API-07` | `POST /hostel/gatepass/verify { gatePassNo }`                       | `M09-API-07`       | Verifying an already-used or expired pass fails loudly                                |
| `M10-ADM-01` | Visual occupancy grid — rooms as cards, beds as slots, colour-coded | `M10-API-06`       | Vacant / occupied / maintenance; colour is not the only signal                        |
| `M10-ADM-02` | Allocation — drag a student onto a bed, or bulk-allocate a batch    | `M10-API-02`       | Bulk confirms with a count and sample                                                 |
| `M10-ADM-03` | Room transfer with reason; maintenance flags                        | `M10-API-03`       |                                                                                       |
| `M10-ADM-04` | Occupancy report                                                    | `M10-API-06`       | Exports CSV                                                                           |
| `M10-APP-01` | Warden: night roll call — room-by-room, P/A/leave, one pass         | `M10-API-04`       | Completes offline; 40 students in under two minutes                                   |
| `M10-APP-02` | Warden: absent-without-leave alert                                  | `M10-API-05`       | Immediate, even when the roll call itself is still queued                             |
| `M10-APP-03` | Warden: gate pass QR scan verification                              | `M10-API-07`       | Works offline against locally cached active passes                                    |
| `M10-APP-04` | Warden: visitor log entry                                           | `M10-DB-04`        |                                                                                       |
| `M10-APP-05` | Parent: room, bed, block, warden contact                            | `M10-API-06`       |                                                                                       |
| `M10-APP-06` | Parent: roll-call history and gate pass status                      | `M10-DB-03`        |                                                                                       |

## Rules that bite

- A bed holds **at most one active allocation** (`vacated_on IS NULL`), enforced
  by a partial unique index — not by application logic alone.
- Allocating a day scholar requires first changing `students.residency` to
  `HOSTELLER`. Guarded and audited, deliberately two steps.
- **Night roll call is not academic attendance.** Two records, two tables, two
  meanings. Conflating them corrupts both the attendance percentage and the
  safety escalation.
- `ABSENT` at roll call with no approved leave escalates warden → admin →
  primary guardian, 15 minutes apart. This is a safety notification and cannot be
  turned off in user preferences.

## API surface

```
GET/POST/PATCH /api/v1/hostels|blocks|rooms|beds
POST /api/v1/hostel/allocations         { studentId, bedId, allocatedOn }
POST /api/v1/hostel/allocations/:id/vacate
POST /api/v1/hostel/rollcall/batch      Idempotency-Key required
GET  /api/v1/hostel/occupancy?hostelId=
POST /api/v1/hostel/gatepass/verify     { gatePassNo }
```
