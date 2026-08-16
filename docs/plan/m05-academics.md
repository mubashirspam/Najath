# M05 · Academics — Islamic Studies & General Education

**Phase P2.** Conventional class/subject/timetable structure for the two
subject-based departments. Identical model, different department scope.

## Tasks

### Database & API

| ID           | Task                                                                     | Depends            | Acceptance                                                                 |
| ------------ | ------------------------------------------------------------------------ | ------------------ | -------------------------------------------------------------------------- |
| `M05-DB-01`  | `class_sections`, `subjects` (per department), subject–teacher–class map | `M13-DB-01`        | A subject belongs to exactly one department                                |
| `M05-DB-02`  | `timetable_slots` with `effective_from` / `effective_to` versioning      | `M05-DB-01`        | Historical attendance resolves against the timetable live **on that date** |
| `M05-DB-03`  | `homework`, `syllabus_progress`, `substitutions`                         | `M05-DB-01`        |                                                                            |
| `M05-API-01` | Classes and subjects CRUD                                                | `M05-DB-01`        | Scope-guarded: a DEPT_HEAD edits only their own department                 |
| `M05-API-02` | `POST /timetable/slots` with **clash detection**                         | `M05-DB-02`        | Teacher double-booking is a **hard block**; room conflict is a warning     |
| `M05-API-03` | `GET /timetable?classSectionId=                                          | batchId=           | staffId=&date=`                                                            | `M05-DB-02` | Resolves the version effective on `date`, not the latest |
| `M05-API-04` | `POST /timetable/substitutions` — notifies both teachers                 | `M05-DB-03`, `M12` | Absent teacher and cover both receive a push                               |
| `M05-API-05` | Homework CRUD                                                            | `M05-DB-03`        |                                                                            |
| `M05-API-06` | Syllabus progress per subject                                            | `M05-DB-03`        |                                                                            |

### Console

| ID           | Task                                                         | Depends      | Acceptance                                                              |
| ------------ | ------------------------------------------------------------ | ------------ | ----------------------------------------------------------------------- |
| `M05-ADM-01` | Class & section CRUD, subject catalogue per department       | `M05-API-01` |                                                                         |
| `M05-ADM-02` | Subject–teacher–class mapping matrix                         | `M05-API-01` | Shows unassigned subjects prominently                                   |
| `M05-ADM-03` | **Timetable builder** — weekly grid, drag-drop, clash detect | `M05-API-02` | A clash is shown at drag time, not on save                              |
| `M05-ADM-04` | Effective-date versioning UI                                 | `M05-API-03` | Changing a live timetable asks "from when?" rather than editing history |
| `M05-ADM-05` | Syllabus upload per subject, chapter/unit progress           | `M05-API-06` |                                                                         |
| `M05-ADM-06` | Substitution management                                      | `M05-API-04` |                                                                         |

### App — Teacher

| ID           | Task                                                                        | Depends             | Acceptance                     |
| ------------ | --------------------------------------------------------------------------- | ------------------- | ------------------------------ |
| `M05-APP-01` | `Today` timeline of periods with room + class                               | `M05-API-03`        | Works offline from the mirror  |
| `M05-APP-02` | Per-period actions — attendance · class note · syllabus progress · homework | `M03`, `M05-API-05` | Each writes locally and queues |
| `M05-APP-03` | Weekly timetable view                                                       | `M05-API-03`        |                                |

### App — Parent

| ID           | Task                                                               | Depends      | Acceptance                         |
| ------------ | ------------------------------------------------------------------ | ------------ | ---------------------------------- |
| `M05-APP-04` | Ward timetable (day + week), next-period card on the overview      | `M05-API-03` | Ward-scoped, family-keyed provider |
| `M05-APP-05` | Subject detail — teacher, syllabus progress, class notes, material | `M05-API-06` |                                    |
| `M05-APP-06` | Homework list with due dates and submission status                 | `M05-API-05` |                                    |
| `M05-APP-07` | Class-teacher / subject-teacher tap-to-call and WhatsApp           | `M05-DB-01`  |                                    |

## Rules that bite

- Timetable slots are **versioned by effective date**. Historical attendance must
  resolve against the timetable that was live on that date — not today's.
- Clash detection: teacher conflict is a hard block on save, room conflict a
  warning.
- A `PERIOD`-mode attendance record requires a valid `timetable_slot_id`.

## API surface

```
GET/POST/PATCH /api/v1/classes
GET/POST/PATCH /api/v1/subjects
GET  /api/v1/timetable?classSectionId=|batchId=|staffId=&date=
POST /api/v1/timetable/slots            (with clash validation)
POST /api/v1/timetable/substitutions
GET/POST /api/v1/homework
GET/POST /api/v1/syllabus-progress
```
