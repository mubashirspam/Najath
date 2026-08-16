# Admin console rules

`apps/web/src/app/(console)/**`. Next.js 16 App Router, RSC-first, shadcn/ui.
Desktop-first, responsive down to tablet. Not a phone surface — the phone
surface is the Flutter app.

## 1. Server-first

- **Default to a Server Component.** `'use client'` is opted into for a reason
  you can state: an event handler, a browser API, or a hook.
- Data is fetched in the server component that renders it, through the same
  `packages/core` services the API uses. The console does not call its own
  `/api/v1` over HTTP — that is a network hop to talk to yourself.
- Mutations are **Server Actions** wrapped in `next-safe-action`, with the same
  Zod schema from `packages/contracts` the API route uses, and the same policy
  guard. One rule, two entry points.

```ts
export const publishResults = authedAction
  .schema(publishResultsInput)
  .use(policy(can("result", "publish").inScope("department")))
  .action(async ({ parsedInput, ctx }) =>
    examService.publish(ctx, parsedInput),
  );
```

A server action that skips the policy guard because "it's the admin console" is
the bug that lets a `DEPT_HEAD` publish another department's results.

## 2. State that belongs in the URL

Table filters, pagination, sort, the selected tab, the academic year — all live
in query params via `nuqs`. Reasons that matter here specifically:

- Office staff share links to a filtered view ("the students still missing a
  primary guardian").
- A wrongly-filtered bulk action is a support incident; the URL is the evidence
  of what was on screen.
- Back/forward behave.

Client state is for genuinely ephemeral things: an open dialog, a dirty form.

## 3. Tables

TanStack Table over shadcn primitives. Every admin list is the same shape:

- Server-side pagination (offset for admin tables, cursor for feeds).
- Filters in the URL, debounced 350 ms.
- Column visibility persisted per user.
- Empty, loading (skeleton rows at the real row height) and error states are
  part of the component, not an afterthought.
- **Bulk actions confirm with a count and a sample**: "Promote 213 students from
  Batch 01 → Batch 02" and the first five names. The promotion tool has an
  explicit rollback; anything irreversible names what cannot be undone.

## 4. Forms

`react-hook-form` + `@hookform/resolvers/zod`, schema imported from
`packages/contracts`. Never redeclare the shape.

- Server-returned `error.field` maps onto the form field of the same name, so an
  API rejection lands on the input rather than in a toast.
- Multi-step flows (the admission wizard) keep step state in the URL and draft
  values in the form; a refresh mid-admission does not lose the parent's details.
- Destructive actions type-to-confirm only when they cannot be undone.

## 5. Dates and academic year

Every console screen operates inside an **academic year context**, selected once
and carried in the URL. A screen that reads data without a year is showing
whichever year the query defaulted to, which is how last year's marks get edited.

Dates render in `Asia/Kolkata`, always, regardless of the admin's browser
timezone. Use the shared formatter; `toLocaleDateString()` with no timezone is a
review rejection.

## 6. The access matrix screen

The role × screen matrix (spec §3 and the `role_screen_access` table) is edited
here. It is the highest-consequence screen in the console, so:

- Show the effective result, not just the stored override — a cell that is on by
  registry default looks different from one an admin turned on.
- Show what a change closes. Revoking a permission closes every screen that
  depends on it; list them before saving.
- Never let the console lock out the last `SUPER_ADMIN`. Guard server-side.
- Every change bumps `access_policy_version` and is audited with actor and
  before/after.

## 7. Reporting

- Charts use Recharts and the same `HufzTokens` semantic colours as the app —
  sabaq is the same green in both places.
- Every table export is CSV **and** the on-screen filter state, so an exported
  file can be explained.
- Long exports and PDF generation go through Trigger.dev and notify on
  completion; a request handler does not generate a 300-page report card batch.

## 8. Accessibility and density

- The console is used all day by office staff on 1366×768 laptops. Design for
  density: compact row height, keyboard-navigable tables, no modal-in-modal.
- Every interactive element is reachable by keyboard, and focus is visible.
- Colour is never the only signal — attendance status carries an icon or a
  letter alongside the fill.
