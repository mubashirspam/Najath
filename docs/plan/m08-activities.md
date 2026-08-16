# M08 · Daily Activities

**Phase P3.** The daily-life feed of the institution — what a batch, class or
hostel did today. This is the module that makes the Parent app feel alive rather
than administrative.

## Tasks

| ID           | Task                                                                      | Depends      | Acceptance                                                                 |
| ------------ | ------------------------------------------------------------------------- | ------------ | -------------------------------------------------------------------------- |
| `M08-DB-01`  | `activities` — category, scope (batch/class/student), `visible_to`, media | `M02-DB-03`  | `visible_to` enum is `{PARENT, STAFF_ONLY}`. **`STUDENT` does not exist.** |
| `M08-DB-02`  | `conduct_notes` with `share_with_guardian`                                | `M08-DB-01`  | Unflagged notes are staff-internal and never leave the API                 |
| `M08-API-01` | `POST /uploads/presign { contentType, purpose }`                          | —            | Short-lived; scoped to one object key                                      |
| `M08-API-02` | `POST /activities`                                                        | `M08-DB-01`  | Up to 5 photos; scope validated against the author's assignments           |
| `M08-API-03` | `GET /activities?scopeType=&scopeId=&from=&to=&cursor=`                   | `M08-DB-01`  | A guardian's feed resolves through `student_guardians`, in the query       |
| `M08-API-04` | `DELETE /activities/:id` — soft, author or admin, within 24 h             | `M08-DB-01`  | Beyond 24 h only admin, audited                                            |
| `M08-JOB-01` | Media retention — archive to cold storage after 2 academic years          | `M08-DB-01`  |                                                                            |
| `M08-APP-01` | Teacher/Warden compose — category, title, description, photos, scope      | `M08-API-02` | **Client-side compression to ≤ 1600 px / 300 KB before upload**            |
| `M08-APP-02` | Quick templates — Quran competition, cleanliness, sports, guest lecture   | `M08-APP-01` | One tap to a pre-filled post                                               |
| `M08-APP-03` | Individual conduct note with the `share_with_guardian` flag               | `M08-DB-02`  | The flag's consequence is stated in the UI, not implied                    |
| `M08-APP-04` | Parent feed — chronological, date-grouped, lightbox, category filter      | `M08-API-03` | Images cached; feed readable offline                                       |
| `M08-APP-05` | Unread badge; **push only for individual-scoped notes**                   | `M12`        | No push for every batch post — notification fatigue kills the channel      |

## Rules that bite

- Media is compressed **client-side** before upload. A 12 MP photo from a
  teacher's phone over a halaqa's connection is a failed upload.
- Conduct notes without `share_with_guardian` never appear in the Parent app.
  Enforce in the query, not the UI.
- Push is for individual notes only. Batch-wide posts appear in the feed and
  bump the badge, nothing more.

## API surface

```
GET    /api/v1/activities?scopeType=&scopeId=&from=&to=&cursor=
POST   /api/v1/activities
POST   /api/v1/uploads/presign            { contentType, purpose }
DELETE /api/v1/activities/:id             (soft, author or admin within 24h)
```
