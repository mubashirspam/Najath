# Definition of done

Every task in `docs/plan/` closes against this. A task that ships without a line
here satisfied is not done — it is deferred, and the deferral is written down.

## Every task

- [ ] Closes a task ID from `docs/plan/`, named in the PR description.
- [ ] `pnpm exec turbo run lint typecheck build` passes.
- [ ] `dart run melos run analyze` and `melos run test` pass (if Flutter touched).
- [ ] Prettier and `dart format` clean — CI checks both.
- [ ] No new `TODO` without an issue number.
- [ ] The PR says how it was verified, not just that it was.

## Anything with an API

- [ ] Zod input **and** output schema in `packages/contracts`.
- [ ] Route runs the standard pipeline — rate limit, auth, context, parse,
      policy, service, envelope, audit.
- [ ] RBAC guard checks role **and** scope **and** state. Covered by the
      policy matrix test.
- [ ] Mutations write `audit_log` in the same transaction.
- [ ] Anything the mobile outbox can replay accepts `Idempotency-Key`, and there
      is a test proving two identical requests produce one row.
- [ ] Error codes added to the closed enum and mapped to ARB strings in the app.
- [ ] OpenAPI regenerates cleanly.

## Anything touching academic records

- [ ] Scoped by `enrollment_id`, not `student_id`.
- [ ] Append-only: corrections insert with `supersedes_id` and flip
      `is_current`. No `UPDATE` of values, no `DELETE`.
- [ ] Reads filter `is_current = true` in the service, not at the call site.
- [ ] Dates are `Asia/Kolkata` calendar dates, never derived from a UTC
      timestamp.
- [ ] Derived numbers — percentages, grades, quality index, ranks — computed
      server-side only. The client renders what it is given.

## Anything in the Flutter app

- [ ] Domain layer has zero `flutter/`, `dio` or `drift` imports.
- [ ] The feature package imports no other feature package.
- [ ] The screen watches a **local DB stream**, not a network future.
- [ ] `loading` / `error` / `data` all handled. No `.value!`, no
      `.requireValue` in `build`.
- [ ] Ward-scoped providers are `family`-keyed on `studentId`.
- [ ] No raw `Color` or `TextStyle` outside `design_system`.
- [ ] No user-visible string literal — ARB entries for `en` and `ml`.
- [ ] Quranic content rendered through `ArabicText`.
- [ ] **Works with the network off**, if a teacher can reach it.

## Anything touching sync

- [ ] Client-generated UUID v7; no temp-ID remapping.
- [ ] Idempotency key derived as `sha256(entity + clientId + naturalKey)`.
- [ ] Outbox pauses and resumes across a 401 refresh; the queue is never
      dropped.
- [ ] The non-negotiable test runs green: full day, three batches, network off,
      app killed, reopened, network returns → zero loss, zero duplicates.

## Anything in the admin console

- [ ] Server Component unless `'use client'` is justified.
- [ ] Mutation is a Server Action with the same schema and policy as the API.
- [ ] Filters, pagination and academic year in the URL.
- [ ] Empty, loading and error states exist.
- [ ] Bulk actions confirm with a count and a sample; irreversible ones say so.

## Before a phase ships

- [ ] The RBAC matrix test covers every role × resource in spec §3.
- [ ] Performance budget measured on a real mid-range Android, not a simulator.
- [ ] A migration has been applied to a Neon preview branch and rolled forward
      on `dev` without manual intervention.
- [ ] Seed data contains no real student or guardian information.
- [ ] The ADRs listed for the phase are written.
