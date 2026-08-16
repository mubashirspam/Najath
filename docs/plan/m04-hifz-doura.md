# M04 · Hifz & Doura ⭐

**Phase P1.** The core differentiator and the largest module. Replaces the paper
Hifz register: daily Sabaq / Sabqi / Manzil / Doura at ayah-and-line precision,
real memorization metrics, fast enough to log 25 students during a halaqa.

**Design target for the quick-log screen: ≤ 20 seconds per student, ≤ 6 taps,
fully offline.** Every task here is subordinate to that number.

## Vocabulary (do not translate in code)

| Term       | Meaning                                      | System treatment                                           |
| ---------- | -------------------------------------------- | ---------------------------------------------------------- |
| **Sabaq**  | New lesson memorized today                   | One log/day/student, ayah range, lines, errors, grade      |
| **Sabqi**  | Revision of recently memorized portion       | Range + errors + grade                                     |
| **Manzil** | Revision of older, consolidated memorization | Range + errors + grade                                     |
| **Doura**  | A complete revision round                    | Belongs to a `doura_round`, coverage tracked to completion |
| **Nazira** | Reading from the mushaf (pre-hifz)           | Same log shape, `activity = NAZIRA`                        |
| **Khatm**  | Completion of the full Quran                 | Milestone event, certificate record                        |
| **Luqma**  | Teacher prompting a stuck student            | `prompts_count` — the single best quality signal           |

## Blocked questions

| Q      | Question                                                                    | Blocks                                                                       |
| ------ | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **Q6** | Does a batch move as a group, or is every student on an individual pointer? | `M04-APP-02` — **chase this first, it changes the roster screen materially** |
| Q1     | Is Sabqi "current juz" or "last N days"? Enforce or leave to teacher?       | `M04-API-04`                                                                 |
| Q2     | Manzil schedule — daily fixed, weekly cycle, or discretion?                 | `M04-API-04`                                                                 |
| Q3     | Doura scope — full 30 juz or memorized portion only?                        | `M04-DB-02`                                                                  |
| Q4     | Formal grading scale and the labels Ustadhs actually use                    | `M04-DB-01`                                                                  |
| Q5     | Is recitation audio part of the daily log?                                  | `M04-APP-05`                                                                 |

## Tasks

### Database & derivation

| ID            | Task                                                                                     | Depends     | Acceptance                                                                         |
| ------------- | ---------------------------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------------------- |
| `M04-DB-01`   | `hifz_daily_logs` — enrollment-scoped, append-only, activity, range, error counts, grade | `M02-DB-03` | One **current** log per `(enrollment, date, activity)`. Re-logging supersedes.     |
| `M04-DB-02`   | `doura_rounds` + coverage tracking                                                       | `M04-DB-01` | ⛔ **BLOCKED — Q3**. One `in_progress` round per enrollment, enforced.             |
| `M04-DB-03`   | `hifz_progress_snapshots`                                                                | `M04-DB-01` | Recomputed after every log write; nightly job re-derives (self-healing)            |
| `M04-DB-04`   | `khatm_certificates` milestone records                                                   | `M04-DB-03` | Created once per student per khatm, idempotently                                   |
| `M04-CORE-01` | Ayah-index derivation service — range → ayah count, pages, lines, juz                    | `P0-DB-05`  | `An-Nisa 12→18` = 7 ayah, 1.2 pages, 18 lines. Exhaustive tests against the index. |
| `M04-CORE-02` | Same derivation in Dart against the bundled SQLite asset                                 | `P0-DB-06`  | Dart and TS agree on all 6,236 ayahs — a cross-check test asserts this             |

### API

| ID           | Task                                                                                    | Depends            | Acceptance                                                                             |
| ------------ | --------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------- |
| `M04-API-01` | `GET /hifz/roster?batchId=&date=&activity=` → students + last log + **suggested range** | `M04-CORE-01`      | Suggested `from` = last log's `to` + 1, per activity, per student                      |
| `M04-API-02` | `POST /hifz/logs/batch` — `Idempotency-Key`, per-item status                            | `P0-API-05`        | 25 logs in one request; one bad range rejects only that item                           |
| `M04-API-03` | Range validation against absolute ayah order                                            | `M04-CORE-01`      | `to ≥ from` validated by index position, **not surah-number arithmetic**               |
| `M04-API-04` | Sabqi / Manzil boundary rules                                                           | —                  | ⛔ **BLOCKED — Q1, Q2**                                                                |
| `M04-API-05` | Frontier soft warning — sabaq beyond `current_sabaq_page` warns, teacher confirms       | `M04-DB-03`        | A warning, never a block. Students do jump between juz.                                |
| `M04-API-06` | `GET /hifz/logs?enrollmentId=&from=&to=&activity=`                                      | `M04-DB-01`        | `is_current` filtered in the service                                                   |
| `M04-API-07` | `POST /hifz/logs/:id/correct`                                                           | `M04-DB-01`        | Backdating limited to `hifzBackdateDays` (default 3) for teachers, unlimited for admin |
| `M04-API-08` | Derived metrics service — all eight metrics below                                       | `M04-DB-03`        | Server-only. No client computes any of these.                                          |
| `M04-API-09` | `GET /hifz/progress/:enrollmentId` → snapshot + juz map + curve series                  | `M04-API-08`       | One request feeds the whole parent progress screen                                     |
| `M04-API-10` | `GET /hifz/batch-summary?batchId=&month=`                                               | `M04-API-08`       | Feeds the teacher's monthly view and the admin dashboard                               |
| `M04-API-11` | `POST /doura/rounds`, `PATCH /doura/rounds/:id`, `GET /:id/coverage`                    | `M04-DB-02`        | Opening a round while one is `in_progress` requires closing or abandoning the previous |
| `M04-API-12` | Khatm detection — 604 distinct pages → `KHATM_ACHIEVED` event                           | `M04-DB-04`, `M12` | Notifies admin + guardians, creates the certificate record, exactly once               |
| `M04-JOB-01` | Nightly snapshot re-derivation                                                          | `M04-DB-03`        | Fixes drift silently; a corrupted snapshot self-heals within a day                     |

### App — Teacher: the quick-log screen

This is the most important screen in the product. Build it, then watch an Ustadh
use it, then rebuild it.

| ID            | Task                                                                      | Depends       | Acceptance                                                   |
| ------------- | ------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------ |
| `M04-APP-01`  | Batch roster with progress `●●●●●●●○○○○ 7 of 22 logged`                   | `M04-API-01`  | Reads local mirror; correct with the network off             |
| `M04-APP-02`  | Activity tabs `SABAQ · SABQI · MANZIL · DOURA`                            | `M04-APP-01`  | ⛔ **BLOCKED — Q6**                                          |
| `M04-APP-03`  | **`AyahRangePicker`** — two-wheel Cupertino picker (surah × ayah)         | `M04-CORE-02` | No typing, no network. Sourced from the bundled index.       |
| `M04-APP-04`  | Auto-continuation — `from` pre-fills as last `to` + 1                     | `M04-API-01`  | In practice the teacher edits only `to`                      |
| `M04-APP-05`  | Live derivation line — `7 ayah · 1.2 pages · 18 lines`                    | `M04-CORE-02` | Updates as the wheels move, offline, no jank                 |
| `M04-APP-06`  | **`ErrorCounterStepper`** — mistakes, prompts, tajweed; big tap targets   | `P0-APP-08`   | Defaults 0. A clean recitation needs zero interaction here.  |
| `M04-APP-07`  | **`HifzGradeSelector`** — Excellent / Good / Avg / Weak / NR              | —             | ⛔ **BLOCKED — Q4** for the labels                           |
| `M04-APP-08`  | `Save & Next Student` — writes drift, advances in roll order              | `P0-APP-02`   | < 100 ms perceived. **No back-navigation to a list.**        |
| `M04-APP-09`  | Auto-skip absentees and students on leave with a `Not present` chip       | `M03-API-01`  | Skipped students are visibly skipped, not silently missing   |
| `M04-APP-10`  | `Repeat sabaq` toggle — does not advance the pointer, counts toward stuck | `M04-DB-01`   | Three consecutive repeats raise the internal stuck flag      |
| `M04-APP-11`  | Optional remark + optional audio recording                                | —             | ⛔ **BLOCKED — Q5** for audio                                |
| `M04-TEST-01` | Timed test: log 22 students end to end, offline                           | `M04-APP-08`  | **≤ 20 s per student, ≤ 6 taps.** Fails the task if not met. |

### App — Parent

The guardian is the only non-staff audience, so these carry full log detail. A
parent is not an Ustadh: present it in plain language.

| ID           | Task                                                                 | Depends      | Acceptance                                                           |
| ------------ | -------------------------------------------------------------------- | ------------ | -------------------------------------------------------------------- |
| `M04-APP-12` | Today's card — sabaq/sabqi/manzil ranges, grade chip, teacher remark | `M04-API-09` | Ranges shown as Surah name + ayah + page, **never internal indices** |
| `M04-APP-13` | Juz map — 30-cell grid, fill state, tap → page detail                | `M04-API-09` | Uses `HufzTokens` hifz semantic colours                              |
| `M04-APP-14` | Progress curve — cumulative pages, target line, 30-day pace label    | `M04-API-09` | `RepaintBoundary`; no jank on scroll                                 |
| `M04-APP-15` | History — date-grouped, activity filter, error trend sparkline       | `M04-API-06` | Paginated; 60 days local, older fetched on demand                    |
| `M04-APP-16` | Quality & retention rings with a **one-line plain-English reading**  | `M04-API-08` | Never a bare number. "Holding well" beats "87".                      |
| `M04-APP-17` | Doura tracker — round no, % covered, days remaining, pace vs target  | `M04-API-11` |                                                                      |
| `M04-APP-18` | Milestones — juz completions, khatm certificate download, streak     | `M04-API-12` | Certificate is a signed R2 URL                                       |
| `M04-APP-19` | Opt-in Friday weekly digest push                                     | `M12`        | Lines memorized, days logged, grade trend                            |

### Console

| ID           | Task                                                      | Depends      | Acceptance                              |
| ------------ | --------------------------------------------------------- | ------------ | --------------------------------------- |
| `M04-ADM-01` | Batch hifz register view (month grid)                     | `M04-API-10` | Exports CSV                             |
| `M04-ADM-02` | Khatm pipeline card — students within 2 juz of completion | `M04-API-08` | Links to each student                   |
| `M04-ADM-03` | Stuck-student watchlist                                   | `M04-API-08` | Internal only — see the guardrail below |

## Derived metrics — server-side only

| Metric              | Definition                                                                |
| ------------------- | ------------------------------------------------------------------------- |
| Pages memorized     | Distinct Madani pages covered by `SABAQ` logs, deduped                    |
| Juz memorized       | `pages / 20.13`, 1 decimal, plus the 30-cell map                          |
| Daily average (30d) | Mean `lines_count` of `SABAQ` logs over 30 calendar days                  |
| Consistency streak  | Consecutive working days with a `SABAQ` log                               |
| Quality index       | `100 − (3·errors_major + 1·errors_minor + 2·prompts) / lines × 10`, 0–100 |
| Retention score     | Rolling error rate on `MANZIL` logs — whether memorization is holding     |
| Projected khatm     | `remaining_pages / avg_pages_per_day(60d)`, with a confidence band        |
| Stuck flag          | 3+ consecutive `is_repeat` sabaq, or quality index < 40 for 5 days        |

## Presentation guardrails for the parent view

- **Never surface the internal stuck flag to a guardian.** Surface it as a
  teacher-authored remark, so a human frames it.
- Grade labels are localized and paired with a descriptor. `NOT_READY` renders
  as "needs to repeat", not as a failure state.
- Ranges are shown in the mushaf's own terms — Surah name + ayah + page.

## API surface

```
GET   /api/v1/hifz/roster?batchId=&date=&activity=
POST  /api/v1/hifz/logs/batch                      Idempotency-Key required
GET   /api/v1/hifz/logs?enrollmentId=&from=&to=&activity=
POST  /api/v1/hifz/logs/:id/correct
GET   /api/v1/hifz/progress/:enrollmentId
GET   /api/v1/hifz/batch-summary?batchId=&month=
POST  /api/v1/doura/rounds
PATCH /api/v1/doura/rounds/:id
GET   /api/v1/doura/rounds/:id/coverage
GET   /api/v1/quran/index                          bundled offline; endpoint for cache refresh only
```
