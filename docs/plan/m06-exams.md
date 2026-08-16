# M06 · Examination & Assessment

**Phase P2.** Exam lifecycle from scheduling → question paper → marks entry →
verification → publish, for both formative (continuous) and summative (terminal)
assessment.

```
draft → scheduled → ongoing → marks_entry → verification → published
                                  ↑              │
                                  └──── reopen ───┘  (admin only, audited)
```

## Tasks

### Database & API

| ID           | Task                                                                      | Depends      | Acceptance                                                                         |
| ------------ | ------------------------------------------------------------------------- | ------------ | ---------------------------------------------------------------------------------- |
| `M06-DB-01`  | `exams`, `exam_schedules`, `mark_entries` (append-only)                   | `M05-DB-01`  | Mark corrections insert with `supersedes_id`                                       |
| `M06-DB-02`  | Grade scales + assessment weightage per department                        | `M13-DB-03`  | Final grade = weighted formative + summative, per department config                |
| `M06-DB-03`  | Hifz-department evaluation sheet (juz-wise oral test, errors, tajweed)    | `M04-DB-01`  | A **different shape** from written marks — do not force one table                  |
| `M06-API-01` | Exam CRUD + state machine                                                 | `M06-DB-01`  | Illegal transitions rejected with the current state in `details`                   |
| `M06-API-02` | `POST /exams/:id/schedules` per class/batch/subject                       | `M06-DB-01`  | Date, time, max/pass marks, invigilator                                            |
| `M06-API-03` | Question paper upload → R2, **time-gated** signed URL                     | —            | Downloadable only from `exam_date − 1h`. Earlier requests 403 with a reason.       |
| `M06-API-04` | `POST /exams/marks/batch` — `Idempotency-Key`, per-item status            | `P0-API-05`  | `marks ≤ max_marks`, non-negative, decimals per config — validated server-side     |
| `M06-API-05` | `POST /exams/:id/verify`                                                  | `M06-API-01` | Locks entry; teachers can no longer edit                                           |
| `M06-API-06` | `POST /exams/:id/publish` → push fan-out                                  | `M12`        | **Marks are invisible to guardians until published — enforced in the query layer** |
| `M06-API-07` | Post-publish correction → superseding row + `RESULT_REVISED` notification | `M06-DB-01`  | Guardians are told the result changed, not silently shown a new number             |
| `M06-API-08` | `GET /results/student/:enrollmentId?examId=`                              | `M06-API-06` | Class average excludes absentees; pass-percentage denominator includes them        |
| `M06-API-09` | Rank computation, gated by `showRankToParents`                            | `M13`        | Server-computed; absent from the payload entirely when the setting is off          |

### Console

| ID           | Task                                                           | Depends         | Acceptance                                             |
| ------------ | -------------------------------------------------------------- | --------------- | ------------------------------------------------------ |
| `M06-ADM-01` | Exam creation — name, department, type, term, weightage        | `M06-API-01`    |                                                        |
| `M06-ADM-02` | Schedule builder                                               | `M06-API-02`    | Clash-checks against the timetable                     |
| `M06-ADM-03` | Question paper upload with the time gate explained             | `M06-API-03`    | Shows exactly when teachers gain access                |
| `M06-ADM-04` | Marks entry monitoring — which subject, which teacher, pending | `M06-API-04`    | The single screen the office lives in during exam week |
| `M06-ADM-05` | Verification & publish workflow                                | `M06-API-05,06` | Publish confirms with a count of students affected     |
| `M06-ADM-06` | Grade scale configuration per department                       | `M06-DB-02`     |                                                        |
| `M06-ADM-07` | Hall ticket / seating plan generation                          | —               | Optional, Phase 3                                      |

### App — Teacher

| ID           | Task                                                                     | Depends      | Acceptance                                             |
| ------------ | ------------------------------------------------------------------------ | ------------ | ------------------------------------------------------ |
| `M06-APP-01` | Marks entry — roster, numeric-keypad-optimised, running "entered N of M" | `M06-API-04` | Offline-capable; entry never waits on the network      |
| `M06-APP-02` | Inline validation                                                        | `M06-API-04` | `marks ≤ max_marks`, non-negative — shown at the field |
| `M06-APP-03` | Mark-absent toggle                                                       | `M06-DB-01`  | Absent is a state, not a zero                          |
| `M06-APP-04` | Submit → `entered`; locked after `verified`                              | `M06-API-05` | The lock is explained, not a silently disabled field   |
| `M06-APP-05` | Formative rubric entry (skill × level)                                   | `M06-DB-02`  | Lightweight — not raw marks                            |
| `M06-APP-06` | Hifz oral evaluation sheet                                               | `M06-DB-03`  | Juz-wise, error count, tajweed grade                   |

### App — Parent

| ID           | Task                                                                             | Depends      | Acceptance                                                  |
| ------------ | -------------------------------------------------------------------------------- | ------------ | ----------------------------------------------------------- |
| `M06-APP-07` | Exam timetable with countdown and per-paper syllabus notes                       | `M06-API-02` |                                                             |
| `M06-APP-08` | Results — subject marks, grade, percentage, pass/fail, class average, rank if on | `M06-API-08` | Nothing renders before publish, because nothing is returned |
| `M06-APP-09` | Historical comparison chart across terms                                         | `M06-API-08` |                                                             |
| `M06-APP-10` | Report card PDF download and share                                               | `M07`        |                                                             |

## Rules that bite

- **Marks are invisible to guardians until published, enforced server-side in the
  query layer** — not by hiding a widget.
- Post-publish corrections supersede and notify (`RESULT_REVISED`).
- Absent students are excluded from the class average and included in
  pass-percentage denominators.
- The Hifz department's "exam" is an oral evaluation of memorized portions, a
  different sheet from written marks.

## API surface

```
GET/POST/PATCH /api/v1/exams
POST /api/v1/exams/:id/schedules
GET  /api/v1/exams/:id/marks-entry?scheduleId=
POST /api/v1/exams/marks/batch                 Idempotency-Key required
POST /api/v1/exams/:id/verify
POST /api/v1/exams/:id/publish
GET  /api/v1/results/student/:enrollmentId?examId=
GET  /api/v1/exams/:id/question-paper          → signed, time-gated URL
```
