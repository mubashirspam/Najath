# M09 · Leave Management

**Phase P3.** Student and staff leave with a multi-stage approval trail,
integrated with attendance and the hostel gate pass.

**All student leave is requested by a guardian.** There is no student-initiated
path, because students have no accounts.

## Approval chains (configurable)

```
Student · day scholar : Class Teacher → (auto) Dept Head if > 3 days
Student · hosteller   : Class Teacher → Hostel Warden → Dept Head if > 3 days
Staff                 : Dept Head → Admin
Emergency             : single-stage Admin/Warden override, back-filled later
```

## Tasks

| ID           | Task                                                                     | Depends      | Acceptance                                                                           |
| ------------ | ------------------------------------------------------------------------ | ------------ | ------------------------------------------------------------------------------------ |
| `M09-DB-01`  | `leave_requests`, `leave_approvals` (stage trail)                        | `M02-DB-03`  | Every stage records actor, action, note, timestamp                                   |
| `M09-DB-02`  | Configurable chain definition per subject type + duration                | `M13`        | Changing the chain does not rewrite in-flight requests                               |
| `M09-API-01` | `POST /leave` — guardian on behalf of a ward, or staff for self          | `M09-DB-01`  | Only guardians with `can_approve_leave = true` may raise for a ward                  |
| `M09-API-02` | Overlap rejection at creation                                            | `M09-DB-01`  | **Including across two different guardians of the same student**                     |
| `M09-API-03` | `POST /leave/:id/decide { action, note }`                                | `M09-DB-02`  | Note required on reject; advances to the next stage automatically                    |
| `M09-API-04` | `GET /leave/approvals/inbox`                                             | `M09-DB-02`  | Scoped to what this approver can actually action                                     |
| `M09-API-05` | Approved leave → auto-mark attendance `LEAVE` for covered dates          | `M03-API-02` | Blocks teacher marking; override requires a reason and is audited                    |
| `M09-API-06` | `POST /leave/:id/cancel`                                                 | `M09-API-05` | Guardian while `pending` only; admin after approval **reverts the attendance marks** |
| `M09-API-07` | Gate pass for hostellers — `gate_pass_no`, QR payload                    | `M10`        | Generated on approval, not on request                                                |
| `M09-API-08` | `POST /leave/:id/return { actualReturnAt }`; overdue notifies the warden | `M10`, `M12` | Overdue is computed against the approved `to` date in IST                            |
| `M09-APP-01` | Parent: request leave — type, from/to, half-day, reason, attachment      | `M09-API-01` | Medical certificate via presigned upload                                             |
| `M09-APP-02` | Parent: status timeline with each approver's action and note             | `M09-API-03` | Shows who is currently holding it                                                    |
| `M09-APP-03` | Parent: gate pass card (QR) once approved                                | `M09-API-07` | Renders offline — the gate may have no signal                                        |
| `M09-APP-04` | Teacher/Warden: approvals inbox, swipe approve/reject, bulk approve      | `M09-API-04` | Reject requires a note before the action commits                                     |
| `M09-APP-05` | Push on new request + shell badge                                        | `M12`        |                                                                                      |
| `M09-ADM-01` | Console: all leave, filters, admin override, cancellation with revert    | `M09-API-06` | Reverting shows which attendance marks will change                                   |

## Rules that bite

- Approved leave **auto-marks attendance** as `LEAVE` and blocks teacher marking
  (overridable with a reason).
- Overlapping requests for the same student and date are rejected at creation,
  **including across two different guardians** — this is the common real case,
  both parents filing the same absence.
- Cancellation after approval is admin-only and **reverts the attendance marks**.
- Hosteller leave creates a `gate_pass_no` and expects an `actual_return_at`;
  overdue returns notify the warden.

## API surface

```
POST /api/v1/leave                      { subjectType, studentId?, type, from, to, reason }
GET  /api/v1/leave?status=&studentId=&cursor=
POST /api/v1/leave/:id/decide           { action, note }
POST /api/v1/leave/:id/cancel
GET  /api/v1/leave/approvals/inbox
POST /api/v1/leave/:id/return           { actualReturnAt }
```
