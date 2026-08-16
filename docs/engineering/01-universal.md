# Universal rules

Applies to every surface. Read once, then use as reference.

## 1. Naming

| Layer             | Convention           | Example                         |
| ----------------- | -------------------- | ------------------------------- |
| Postgres tables   | `snake_case`, plural | `hifz_daily_logs`               |
| Postgres columns  | `snake_case`         | `errors_major`, `supersedes_id` |
| API JSON          | `camelCase`          | `fromAyah`, `errorsMajor`       |
| Route paths       | kebab-case           | `/batches/:batchId/hifz`        |
| Error codes       | `SCREAMING_SNAKE`    | `HIFZ_RANGE_OVERLAP`            |
| TypeScript types  | `PascalCase`         | `HifzDailyLog`                  |
| TS files          | kebab-case           | `hifz-daily-log.ts`             |
| Dart classes      | `PascalCase`         | `HifzDailyLog`                  |
| Dart files        | `snake_case`         | `hifz_daily_log.dart`           |
| Riverpod provider | `<noun>Provider`     | `hifzRepositoryProvider`        |
| Dart packages     | `najath_<name>`      | `najath_hifz`                   |
| npm packages      | `@najath/<name>`     | `@najath/contracts`             |

Drizzle is configured with `casing: 'snake_case'`, so TS field names are written
`camelCase` and the column name is derived. Do not pass explicit column names.

**Domain vocabulary is not translated in code.** A sabaq is `sabaq`, not
`newLesson`. Manzil is `manzil`, not `oldRevision`. The Ustadhs' words are the
domain language; inventing English synonyms makes the code unreviewable by the
people who know whether it is right. See the glossary in the spec appendix.

## 2. Identifiers

- **UUID v7 everywhere**, for every entity. Time-ordered, so it indexes like a
  sequence without leaking a count.
- **Clients generate IDs.** The Flutter app creates the UUID for a hifz log or
  an attendance mark before it ever reaches the network, and the server accepts
  it. There is no temp-ID remapping, because remapping is where offline sync
  goes wrong.
- `admission_no` is a separate, human-facing, immutable business key. It is
  never a primary key and never reused, including for alumni.

## 3. Time and dates

This is the single most common source of subtle bugs in this system. Two
different things, handled differently:

- **Timestamps** (`created_at`, `synced_at`, `at`) are `timestamptz`, stored and
  transmitted UTC, ISO-8601 with a `Z`.
- **Dates** (attendance date, hifz log date, leave from/to) are `DATE` in
  **`Asia/Kolkata`**. They are calendar facts about a school day, not instants.

**Never derive a date from a UTC timestamp.** `new Date().toISOString().slice(0,10)`
is wrong: at 06:00 IST it returns yesterday. A teacher marking a 6 AM Fajr halaqa
would file the log against the wrong day, and the correction would land on the
wrong day too.

Use the shared helpers:

```ts
import { todayInIst, toIstDate } from "@najath/core/time";
```

```dart
import 'package:najath_core/najath_core.dart';
final date = IstDate.today();          // never DateTime.now() for an academic date
```

## 4. Errors

One closed enum of error codes, declared in `packages/contracts`, shared by
server and app.

```jsonc
{
  "error": {
    "code": "HIFZ_RANGE_OVERLAP",
    "message": "Sabaq range overlaps an existing log for this date.",
    "field": "fromAyah",
    "details": { "conflictingLogId": "018f…" },
  },
}
```

Rules:

- **The server never sends a user-facing Malayalam string.** `message` is English
  and is a developer/log-facing fallback. The app maps `code` to a localized
  string. A new error code without an ARB entry is an incomplete feature.
- Codes are `SCREAMING_SNAKE` and never renamed once shipped — an old app build
  in the field still sends and receives them.
- `field` is set for anything a form can highlight.
- `details` carries what the client needs to act, not a stack trace.

Success envelope:

```jsonc
{
  "data": {},
  "meta": { "page": 1, "pageSize": 50, "total": 812, "serverTime": "…" },
}
```

`meta.serverTime` is always present. Clients use it to detect a skewed device
clock before trusting their own for a date.

## 5. The append-only ledger

Applies to `attendance_marks`, `hifz_daily_logs`, `mark_entries`, and anything
else a dispute could hinge on.

```
correction:
  INSERT new row  (id = new uuid v7, supersedes_id = old.id, is_current = true)
  UPDATE old row  SET is_current = false
```

- Never `UPDATE` the values of an existing academic row.
- Never `DELETE`. A voided record sets a status, keeps the row.
- Every read of "current" data filters `is_current = true`. Put that in the
  service, not in each call site — a query that forgets it returns duplicates.
- The history view is a product feature, not a debugging tool: guardians and
  admins can both see that a mark was corrected, by whom, and when.

## 6. Idempotency

Every mutating endpoint accepts an `Idempotency-Key` header and it is
**required** for anything the mobile outbox can replay.

```
idempotencyKey = sha256(entity + clientId + naturalKey)
```

The server stores keys for 7 days and returns the original response on a repeat.
This is what makes "the teacher's phone retried while the first request was
already committing" safe, which is the normal case on a bad connection, not an
edge case.

## 7. Audit

Every mutation writes `audit_log(actor_id, entity, entity_id, action, before, after, ip, at)`.

Write it in the service layer, in the same transaction as the change. An audit
row written after the transaction commits is an audit row that can go missing
exactly when it matters.

Security-critical writes — `student_guardians`, role assignment, result publish,
exam reopen — additionally require the actor to be re-checked at the policy layer
even if the route already guarded, and are surfaced in an admin activity feed.

## 8. Git

- **Conventional commits.** `feat(hifz): …`, `fix(attendance): …`,
  `chore(deps): …`. The scope is the module id or package name.
- One task per PR where possible. A PR that touches three modules is three PRs.
- Branch from `dev`, PR into `dev`. `dev → staging → production` promote by
  merge, never by cherry-pick.
- The PR description states which task ID it closes and how it was verified.
- Migrations are generated locally and committed; CI applies them. Never point
  `db:migrate` at a shared database from your machine.

## 9. What never goes in the repo

- Real student names, admission numbers, guardian phone numbers — including in
  fixtures, screenshots and test data. Seed data uses generated names.
- `google-services.json`, `GoogleService-Info.plist`, `config/*.json`, `.env`.
- Anything under `assets/fonts/UthmanicHafs.ttf` — licensed, fetched at setup.
