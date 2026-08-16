# M12 · Announcements & Notifications

**Phase P2**, but the **push infrastructure is needed from P0** — M03, M04, M06,
M09 and M10 all fan out through it. Build `M12-API-01..03` early, in P0/P1, and
the announcement surface in P2.

## Tasks — notification infrastructure (early)

| ID           | Task                                                      | Depends      | Acceptance                                                                 |
| ------------ | --------------------------------------------------------- | ------------ | -------------------------------------------------------------------------- |
| `M12-API-01` | Notification dispatch service + `devices` registry        | `M01-API-05` | One call site; modules emit events, they do not talk to FCM                |
| `M12-API-02` | Fan-out resolution to **all linked guardians** by default | `M02-DB-02`  | Per-student setting can restrict routine notifications to the primary only |
| `M12-API-03` | Per-user preferences with category toggles                | —            | **Critical safety notifications cannot be disabled**                       |
| `M12-API-04` | Quiet hours, default 21:30–06:00 IST, except critical     | `M12-API-03` | A queued notification sends at 06:00, it is not dropped                    |
| `M12-JOB-01` | Retry + dead-letter for failed pushes                     | `M12-API-01` | A stale FCM token is pruned rather than retried forever                    |
| `M12-APP-01` | `route` deep-link handling from a push payload            | `P0-APP-07`  | Tapping "marked absent" lands on that ward's attendance day                |
| `M12-APP-02` | Notification preferences screen                           | `M12-API-03` | Critical categories render as locked-on with a reason                      |

## Tasks — announcements (P2)

| ID           | Task                                                                           | Depends      | Acceptance                                                  |
| ------------ | ------------------------------------------------------------------------------ | ------------ | ----------------------------------------------------------- |
| `M12-DB-01`  | `announcements` — audience, schedule, pin, expiry, attachments                 | `M13-DB-01`  |                                                             |
| `M12-DB-02`  | `announcement_reads` (count only, not per-user display)                        | `M12-DB-01`  |                                                             |
| `M12-API-05` | Compose + audience selector (roles × departments × batches × classes × hostel) | `M12-DB-01`  | Audience resolution is a server query, previewed as a count |
| `M12-API-06` | Scheduled publish, pin, expiry                                                 | `M12-DB-01`  | A scheduled announcement fires once                         |
| `M12-API-07` | Optional WhatsApp Cloud API fan-out for high-priority circulars                | `M12-API-01` | Opt-in per announcement; failures do not block the push     |
| `M12-ADM-01` | Compose UI with audience preview and read receipts                             | `M12-API-05` | "This reaches 412 guardians" before sending                 |
| `M12-APP-03` | Notices feed, pinned first                                                     | `M12-API-05` | Cached; readable offline                                    |

## Notification catalogue

| Event                           | To                          | Channel           |
| ------------------------------- | --------------------------- | ----------------- |
| Marked absent                   | All linked guardians        | Push              |
| Leave decision                  | Requester                   | Push              |
| New leave request               | Approver                    | Push              |
| Result published                | All linked guardians        | Push + in-app     |
| Progress report published       | All linked guardians        | Push              |
| Hifz milestone (juz / khatm)    | All linked guardians, Admin | Push + WhatsApp   |
| Roll-call absent without leave  | Warden, Admin, Guardian     | Push (escalating) |
| Low canteen balance             | Parent                      | Push              |
| Announcement                    | Audience                    | Push              |
| Weekly Hifz digest (opt-in)     | Primary guardian            | Push, Friday      |
| Attendance not marked by cutoff | Teacher                     | Push              |

## Rules that bite

- Fan-out targets **all linked guardians** by default; a per-student setting can
  restrict routine notifications to the primary. **Critical notifications always
  go to every linked guardian**, regardless of the setting.
- Category toggles exist, but roll-call absence and other safety notifications
  cannot be disabled.
- Quiet hours 21:30–06:00 except critical — queued, not dropped.
- Every push carries a `route` for deep linking. A notification that opens the
  home screen wasted the interruption.
