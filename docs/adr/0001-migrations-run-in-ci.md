# ADR 0001 — Migrations run in CI, on a Neon branch per PR

Status: accepted — 2026-08-16

## Context

`packages/db` uses Drizzle, whose `migrations/meta/_journal.json` is a single
append-only file. If two people run `db:generate` in the same week against their
own machines, both append an entry with the same index and the journal conflicts
on merge — a conflict git cannot resolve meaningfully, because the SQL files
either side references are already named.

Neon's branching makes the alternative cheap: a branch is a copy-on-write fork
of the database that costs nothing while idle.

## Decision

- Developers run `db:generate` locally and **commit** the generated SQL and
  journal. Generation stays a human step so the diff is reviewable.
- Nobody applies migrations to a shared database from their own machine.
- CI (`.github/workflows/db.yml`) creates a Neon branch `preview/pr-<n>` for every
  PR that touches `packages/db`, applies the migrations there, and deletes the
  branch when the PR closes.
- The preview job re-runs `db:generate` and fails if the result differs from what
  was committed, so a schema edit without a matching migration cannot merge.
- Preview branches fork from the Neon `production` branch when the PR targets `main`, and
  from `dev` otherwise, so a migration is rehearsed against data shaped like the
  database it will actually hit.

## Environments

Three long-lived git branches, two databases:

| Branch    | GitHub environment | Neon branch  |
| --------- | ------------------ | ------------ |
| `dev`     | `dev`              | `dev`        |
| `staging` | `dev`              | `dev`        |
| `main`    | `production`       | `production` |

`dev` and `staging` deliberately share one database. The mapping lives in the
`target` job of `db.yml` rather than in duplicated environment secrets, so the
sharing is visible in the diff when someone changes it.

Sharing is safe for migrations specifically because Drizzle's journal table makes
re-application a no-op: by the time `staging` runs, the migration `dev` already
applied is skipped. It is _not_ safe for data — staging exercises the same rows
as dev, so neither is a realistic rehearsal for production data volume. Splitting
them later means adding a `staging` GitHub environment with its own Neon branch
and one line in the `case` statement.

## Consequences

- Requires repo variable `NEON_PROJECT_ID`, secret `NEON_API_KEY`, and a
  `DATABASE_URL` secret on each of the `dev` and `production` environments.
- Journal collisions become ordinary PR conflicts, caught before merge rather
  than after someone has already migrated a shared database.
- A migration cannot be applied out of band in an emergency without either
  running the workflow manually or temporarily bypassing this rule. Accepted.
