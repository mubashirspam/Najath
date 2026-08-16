# M07 · Progress Reports

**Phase P2.** Consolidated periodic report combining attendance, Hifz progress,
subject performance, conduct and remarks — an **immutable JSON snapshot** plus a
rendered PDF.

Depends on M03, M04 and M06 being complete. It is the module that proves the rest
computed correctly, because a parent reads it end to end.

## Composition is department-aware

| Section                              | Hifz & Doura | Islamic Studies | General Education |
| ------------------------------------ | ------------ | --------------- | ----------------- |
| Attendance summary                   | ✅           | ✅              | ✅                |
| Sabaq / Sabqi / Manzil summary       | ✅           | —               | —                 |
| Pages & juz memorized, quality index | ✅           | —               | —                 |
| Doura round status                   | ✅           | —               | —                 |
| Subject-wise marks & grade           | —            | ✅              | ✅                |
| Formative rubric summary             | —            | ✅              | ✅                |
| Daily activity & conduct highlights  | ✅           | ✅              | ✅                |
| Teacher remark + Dept Head remark    | ✅           | ✅              | ✅                |

A student in two departments gets **two report sections**, not one merged sheet.

## Flow

```
1. Admin/Dept Head triggers generation for a period + scope (batch/class/dept)
2. Trigger.dev job computes each student's snapshot → progress_reports.payload
3. Teachers add remarks (Flutter: remark queue screen)
4. Dept Head approves → PDF rendered to R2 → status published
5. Push to all linked guardians; PDF viewable, downloadable, shareable in-app
```

## Tasks

| ID           | Task                                                              | Depends             | Acceptance                                                                        |
| ------------ | ----------------------------------------------------------------- | ------------------- | --------------------------------------------------------------------------------- |
| `M07-DB-01`  | `progress_reports` — payload JSONB, status, `revision_no`         | M03, M04, M06       | Published payload is **immutable**; a correction issues a new revision            |
| `M07-API-01` | `POST /progress-reports/generate { scope, periodType, from, to }` | `M07-DB-01`         | Enqueues; returns immediately with a job handle                                   |
| `M07-JOB-01` | Snapshot computation job, department-aware                        | `M07-API-01`        | Re-runnable and idempotent; a re-run of the same period replaces the draft        |
| `M07-API-02` | `POST /progress-reports/:id/remark`                               | `M07-DB-01`         | Scoped to assigned teachers only                                                  |
| `M07-API-03` | `POST /progress-reports/:id/approve`                              | `M07-API-02`        | ⛔ **BLOCKED — Q9** (class teacher, dept head, or principal owns final approval?) |
| `M07-API-04` | Publish gate — blocked while any assigned remark is missing       | `M07-API-02`        | Configurable. Names which teacher is outstanding.                                 |
| `M07-API-05` | `POST /progress-reports/:id/publish` → PDF render + push          | `M07-JOB-02`, `M12` | Guardians notified only after the PDF exists                                      |
| `M07-JOB-02` | Bilingual PDF render (React-PDF) → R2                             | `M07-DB-01`         | Letterhead, English + Malayalam labels, QR to a verification URL                  |
| `M07-API-06` | `GET /progress-reports?enrollmentId=` and `/:id/pdf` (signed URL) | `M07-JOB-02`        | Guardian gets only their ward's reports                                           |
| `M07-ADM-01` | Generation trigger + progress monitor                             | `M07-API-01`        | Shows per-student status across a batch                                           |
| `M07-ADM-02` | Approval queue                                                    | `M07-API-03`        | Blocked reports say what is missing                                               |
| `M07-APP-01` | Teacher: remark queue screen                                      | `M07-API-02`        | Works offline; remarks queue like any other write                                 |
| `M07-APP-02` | Parent: report list + in-app PDF view, download, share            | `M07-API-06`        | PDF module is deferred-loaded (APK budget)                                        |

## Rules that bite

- Once published, `payload` is **immutable**. Corrections issue a new report
  version with `revision_no`, they do not edit the old one.
- A report cannot publish while an assigned teacher remark is missing
  (configurable) — the office needs to know _which_ teacher.
- The PDF is bilingual with a QR code linking to a verification URL, so a printed
  report card can be checked against the system.

## API surface

```
POST /api/v1/progress-reports/generate    { scope, periodType, from, to }
GET  /api/v1/progress-reports?enrollmentId=
POST /api/v1/progress-reports/:id/remark
POST /api/v1/progress-reports/:id/approve
POST /api/v1/progress-reports/:id/publish
GET  /api/v1/progress-reports/:id/pdf     → signed URL
```
