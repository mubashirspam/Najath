# Backend rules

`apps/web/src/app/api/v1/**` and `packages/{db,contracts,core,auth,jobs}`.

## 1. The request pipeline

Every route handler runs the same pipeline, in this order, with no exceptions:

```
Request
  → rate limit (per IP + per user)
  → auth resolve (session cookie for console | bearer JWT for mobile)
  → context inject (institution, academic year, actor roles + scopes)
  → Zod parse of body/query
  → RBAC guard (role × resource × scope)
  → service call (pure, Drizzle injected)
  → envelope + audit write
```

Do not reorder. In particular, **RBAC runs after Zod**, because the guard needs
parsed IDs to check scope — "may this teacher write to batch X" cannot be
answered before X is parsed.

Route handlers are thin. They wire the pipeline and call one service function.
Business logic in a route handler is a review rejection.

```ts
// apps/web/src/app/api/v1/hifz/logs/batch/route.ts
export const POST = handler({
  input: hifzLogBatchInput, // Zod, from @najath/contracts
  policy: can("hifz", "create").inScope("batch"),
  idempotent: true,
  async run({ input, ctx }) {
    return hifzService.logBatch(ctx, input);
  },
});
```

## 2. Layout

```
apps/web/src/
├── app/
│   ├── (console)/          admin UI — RSC
│   └── api/v1/…            route handlers only
└── server/
    ├── services/           pure domain logic, Drizzle injected
    ├── policies/           RBAC guards
    ├── middleware/         the pipeline pieces
    └── mappers/            row → API shape
```

Shared, reusable domain rules live in `packages/core` — anything the admin
console's server actions and the API both need. `apps/web/src/server/services`
is for logic that is genuinely route-adjacent.

**Services never import from `next/*`.** They take a context object and a
Drizzle handle. That is what makes them testable and what lets a Trigger.dev job
call the same code as an HTTP request.

## 3. Validation

- Every input schema lives in `packages/contracts`, exported and consumed by both
  the API and the OpenAPI generator.
- Parse at the boundary, once. Below the parse, types are trusted — no defensive
  re-checking, no `as any`.
- Output schemas exist for anything the Flutter client deserializes, so a
  response shape change breaks the contract package's typecheck rather than the
  app at runtime.

## 4. RBAC

Eight roles, many-to-many with users:

```
SUPER_ADMIN  ADMIN  DEPT_HEAD  TEACHER  HOSTEL_WARDEN  CANTEEN_MANAGER  ACCOUNTANT  PARENT
```

A guard answers three questions and all three must pass:

1. **Role** — does any of the actor's roles grant this action on this resource?
2. **Scope** — is the target inside the actor's scope? A `TEACHER` holds batch
   and class-section IDs; a `DEPT_HEAD` holds a department; a `PARENT` holds
   student IDs resolved through `student_guardians`.
3. **State** — is the record in a state that permits this action? A teacher may
   edit attendance the same day only; marks are locked after `verified`; an exam
   reopen is `SUPER_ADMIN`/`ADMIN` and audited.

Scope resolution for a `PARENT` goes through `student_guardians` **in the
query**, never as a post-filter on results. Fetching all wards and filtering in
memory is how the wrong family's child leaks.

The matrix in spec §3 is the specification of rule 1. Encode it once, in
`packages/auth`, as data — not as `if (role === 'TEACHER')` scattered across
handlers.

## 5. Database

- Drizzle schema in `packages/db/src/schema/<module>.ts`, one file per module
  boundary, re-exported from `index.ts`. Keeps merge conflicts down when several
  modules are in flight.
- `db:generate` locally, commit the SQL and the journal. CI applies it. See
  ADR-001 and `.github/workflows/db.yml`.
- Every academic table carries `enrollment_id`, not `student_id`. If you are
  writing `student_id` on an academic record, stop and re-read §1 rule 3.
- Every academic table carries `is_current`, `supersedes_id`, `created_by`,
  `created_at`.
- Index for the query you actually run. The hot ones are
  `(enrollment_id, date)` and `(batch_id, date)` — a teacher opening today's
  roster and a guardian opening a month.
- Money and marks are `numeric`, never `float`.

## 6. High-volume writes

Teacher writes arrive in batches, from a queue, possibly twice.

- Every high-volume write has a batch endpoint: `/attendance/batch`,
  `/hifz/logs/batch`. Up to 100 items, **per-item result status** — one bad row
  must not fail the other 99, and the app needs to know which one to show.
- Batch endpoints require `Idempotency-Key`.
- The response reports each item by its client-generated ID so the app can
  reconcile its outbox without positional matching.

```jsonc
{
  "data": {
    "results": [
      { "clientId": "018f…", "status": "created", "id": "018f…" },
      { "clientId": "018f…", "status": "duplicate", "id": "018f…" },
      { "clientId": "018f…", "status": "rejected", "error": { "code": "HIFZ_RANGE_OVERLAP", … } }
    ]
  }
}
```

## 7. Delta pull

```
GET /api/v1/sync/pull?entities=students,batches,timetable&since=<iso>
```

Returns changed rows, **tombstones** for deletions, and a new cursor. Tombstones
are not optional: without them a student transferred out stays on the teacher's
roster forever.

The cursor is server time, not client time. Clients store and echo it opaquely.

## 8. Background jobs

`packages/jobs` (Trigger.dev). Jobs are for work that is slow, scheduled, or
must survive a request:

- nightly re-derivation of `hifz_progress_snapshots` (self-healing — the
  synchronous recompute after each log write is the fast path, the nightly job
  is the correctness guarantee)
- progress report PDF generation
- push fan-out on result publish
- absence notification at the configured time

A job is idempotent and re-runnable. It reads the same services as the API.

## 9. Testing

- Services: unit tested against a real Postgres (Neon branch or a container),
  not a mock. The interesting bugs here are SQL bugs.
- Policies: table-driven test over the RBAC matrix — every role × resource ×
  scope combination the spec lists, asserted. This test is the matrix.
- Route handlers: one happy path and one refused path each; the pipeline is
  tested once, not per route.
- **Required test for anything the outbox replays:** the same request twice with
  the same `Idempotency-Key` produces one row and two identical responses.
