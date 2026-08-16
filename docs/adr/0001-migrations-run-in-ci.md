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
- `main` is migrated on merge, gated behind the `production` environment.

## Consequences

- Requires repo variable `NEON_PROJECT_ID` and secrets `NEON_API_KEY` and
  `DATABASE_URL` (the production connection string).
- Journal collisions become ordinary PR conflicts, caught before merge rather
  than after someone has already migrated a shared database.
- A migration cannot be applied out of band in an emergency without either
  running the workflow manually or temporarily bypassing this rule. Accepted.
