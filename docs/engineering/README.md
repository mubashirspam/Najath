# Engineering handbook

How code gets written in this repo. Read `01-universal.md` before your first
commit; read the surface guide for whatever you are touching.

| Doc                                                  | Covers                                                         |
| ---------------------------------------------------- | -------------------------------------------------------------- |
| [01-universal.md](01-universal.md)                   | Naming, IDs, time, errors, the append-only ledger, git, audit  |
| [02-backend.md](02-backend.md)                       | `/api/v1` route handlers, services, RBAC, Drizzle, idempotency |
| [03-flutter.md](03-flutter.md)                       | Layering, Riverpod, offline + sync, design system, testing     |
| [04-admin-console.md](04-admin-console.md)           | RSC, server actions, tables, forms, the access matrix UI       |
| [05-definition-of-done.md](05-definition-of-done.md) | The checklist every task closes against                        |

## The source of truth

`docs/srs/hufzul-quran-college-erp-spec.md` is the specification. **Where this
handbook and the spec disagree, the spec wins and the handbook is wrong** — open
a PR against it.

Where the spec is silent, this handbook decides. Where both are silent, follow
the nearest existing code and say so in the PR.

## Naming: the product is Najath

The spec is written for Hufzul Quran College. The platform ships as **Najath** —
npm scope `@najath/*`, Dart packages `najath_*`, `com.najath.erp`, database
`najath_erp`. Hufzul Quran College is the first institution on it, carried as an
`institution_id`, not as a build.

So: spec paths like `hufzul-erp/packages/db` mean `packages/db` here. Do not
introduce `hufzul` as an identifier anywhere.

## Five rules that override everything else

1. **The server computes; the client renders.** Percentages, grades, ranks,
   quality indices, projected khatm — every derived number has exactly one
   implementation, server-side. A client that calculates an academic figure is a
   bug, even when it agrees with the server.

2. **Academic records are append-only.** Attendance marks, hifz logs and mark
   entries are never updated in place and never hard-deleted. A correction
   inserts a new row carrying `supersedes_id`, and the old row flips
   `is_current = false`. Disputes about a child's record are resolved by reading
   history, which means the history has to exist.

3. **Nothing is scoped by `student_id` alone.** Every academic record hangs off
   an `enrollment_id` — a student in one department for one academic year. A
   student is in Hifz in the morning and General Education in the afternoon;
   "the student's attendance" is not a question the system can answer.

4. **Students have no accounts.** There is no student login, and
   `students.user_id` is never populated. Every non-staff path to student data
   goes `users → guardians → student_guardians → students`. That table is
   security-critical: a wrong row shows one family another family's child.

5. **The teacher app works with the network off.** Every teacher write commits
   locally first and syncs later. If a flow cannot be completed in airplane mode,
   it is not finished.
