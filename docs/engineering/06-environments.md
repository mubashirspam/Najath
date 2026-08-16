# Environments & configuration

Three environments, two databases, four places a value can live. This document
is the map.

## The three environments

| Environment | Git branch | Flutter flavor | GitHub environment | Database                   | R2 bucket              |
| ----------- | ---------- | -------------- | ------------------ | -------------------------- | ---------------------- |
| dev         | `dev`      | `dev`          | `dev`              | Neon branch `dev`          | `najath-media-staging` |
| staging     | `staging`  | `staging`      | `dev`              | Neon branch `dev` (shared) | `najath-media-staging` |
| production  | `main`     | `prod`         | `production`       | Neon branch `production`   | `najath-media`         |

`dev` and `staging` **deliberately share one database.** The mapping is a single
`case` statement in `.github/workflows/db.yml`, so the sharing is visible in a
diff rather than hidden in two identical secrets. Rationale and the cost of that
choice: [ADR-0001](../adr/0001-migrations-run-in-ci.md).

Sharing is safe for _migrations_ — Drizzle's journal makes re-application a
no-op — and **not** safe for _data_. Staging exercises the same rows as dev, so
it is not a rehearsal for production volume. Splitting later means one Neon
branch, one GitHub environment, and one line in that `case`.

## Where a value actually lives

| Location                     | Holds                                           | Read by                     |
| ---------------------------- | ----------------------------------------------- | --------------------------- |
| `.env` (gitignored)          | Your laptop's values                            | `next dev`, `drizzle-kit`   |
| Vercel environment variables | Deployed staging and production values          | the running API and console |
| GitHub environment secrets   | CI values, per `dev` / `production` environment | `ci.yml`, `db.yml`          |
| `apps/mobile/config/*.json`  | Flutter per-flavor defines (gitignored)         | `--dart-define-from-file`   |

`.env` **configures your laptop only.** Deployed environments never read it.
Copying a production secret into `.env` to "test something" puts a production
credential on a developer machine and in shell history; use a Neon branch.

`.env.example` only lists what something actually reads. A variable that no code
consumes yet is kept there **commented out**, tagged with the module that will
need it — a blank `R2_BUCKET=""` is indistinguishable from a misconfiguration,
and people waste an afternoon on it.

### Adding a new variable

1. Add it to `.env.example`, commented if nothing reads it yet, with a note on
   what it does and how it differs per environment.
2. Add it to your `.env`.
3. Add it to Vercel for Preview and Production.
4. If CI needs it, add it to the GitHub **environment** — not to repo-level
   secrets, or staging could read the production value.
5. If the mobile app needs it, add it to **all three** `config/*.example.json`
   files and read it in `EnvConfig.fromDartDefines`.

Step 5 is the one people get wrong. A define present in only one flavor silently
falls back to its Dart default in the others, which is how staging ends up
behaving like dev with nothing in the diff to explain it.

## Database URL — there is only one

`.env` carries **one** `DATABASE_URL`: the database your laptop talks to.

```bash
DATABASE_URL="postgresql://…@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
```

There is no `DATABASE_URL_STAGING` or `_PROD`, because `.env` does not configure
staging or production. Those URLs belong in the GitHub environment secrets and
in Vercel, where the thing that actually connects can read them. A staging URL
sitting in a developer's `.env` is a credential on a laptop that nothing on that
laptop is supposed to use.

**Use the direct endpoint, not the `-pooler` one.** drizzle-kit runs a migration
inside a transaction, and PgBouncer in transaction pooling mode rejects that. The
serverless driver the app uses is fine either way, so the direct URL is the one
that works for both.

**If you are changing schema, point `DATABASE_URL` at your own Neon branch**, not
at the shared `dev` one. A half-applied migration on the shared branch blocks
everyone else's local work.

To inspect production, pass the URL to the tool rather than storing it:

```bash
DATABASE_URL="<prod url>" pnpm --filter @najath/db db:studio
```

**Never run `db:migrate` that way.** CI owns every migration — that is the whole
point of [ADR-0001](../adr/0001-migrations-run-in-ci.md), and a laptop-applied
migration is invisible to the journal check that guards the PR.

## Secrets that must differ per environment

Reusing any of these across environments defeats the separation:

- `BETTER_AUTH_SECRET` — a shared secret means a staging session token is valid
  in production.
- `R2_BUCKET` — staging writing to the production bucket overwrites real student
  photos and report card PDFs. There is no undo.
- `MSG91_AUTH_KEY` — a real key sends real SMS to real guardians. Use the test
  key locally, always.
- `TRIGGER_SECRET_KEY`, `SENTRY_DSN`, `AXIOM_DATASET`.

`FCM_SERVICE_ACCOUNT_JSON` follows the Firebase project, and each flavor has its
own Firebase app (`com.najath.erp.dev`, `.stg`, and the bare id) — so this
differs per environment by construction.

## Flutter flavors

```bash
flutter run --flavor dev     --dart-define-from-file=../config/dev.json
flutter run --flavor staging --dart-define-from-file=../config/staging.json
flutter run --flavor prod    --dart-define-from-file=../config/prod.json
```

`config/*.json` is gitignored; `config/*.example.json` is committed and is what
CI copies. Two independent things decide the environment:

- **The flavor** comes from the platform build (`appFlavor`), so `F.appFlavor`
  is the truth about which binary this is.
- **The config** comes from the JSON.

`EnvConfig.fromDartDefines(flavor)` takes the flavor as an argument rather than
reading it from the JSON, so a dev config accidentally shipped inside a prod
build still reports `Environment.prod`. That is deliberate: the thing that
decides whether logging is on should not be the file that got copied wrong.

### The defines

| Key                          | dev                           | staging                         | prod                        |
| ---------------------------- | ----------------------------- | ------------------------------- | --------------------------- |
| `API_BASE_URL`               | `http://10.0.2.2:3000/api/v1` | `https://stg.najath.app/api/v1` | `https://najath.app/api/v1` |
| `ENV`                        | `dev`                         | `staging`                       | `prod`                      |
| `ENABLE_LOGGING`             | `true`                        | `true`                          | **`false`**                 |
| `ENABLE_CRASH_REPORTING`     | `false`                       | `true`                          | `true`                      |
| `SENTRY_DSN`                 | empty                         | staging DSN                     | prod DSN                    |
| `SYNC_PULL_INTERVAL_MINUTES` | `15`                          | `15`                            | `15`                        |
| `LOCAL_RETENTION_DAYS`       | `60`                          | `60`                            | `60`                        |

`ENABLE_LOGGING` must be `false` in prod. Dio's log interceptor prints request
bodies, and in this product a request body is a guardian's phone number and a
child's attendance record.

`10.0.2.2` is the Android emulator's route to your host. On a physical device
use your LAN IP, and start Next with `pnpm dev -H 0.0.0.0` so it accepts a
non-localhost origin.

## GitHub setup checklist

Repo-level **variable**:

- `NEON_PROJECT_ID`

Repo-level **secret**:

- `NEON_API_KEY` — used to create and delete per-PR preview branches

Environment `dev` (used by both the `dev` and `staging` branches):

- `DATABASE_URL` → the shared Neon `dev` branch

Environment `production` (used by `main`), with required reviewers:

- `DATABASE_URL` → the Neon `production` branch

Neon itself needs branches named exactly `dev` and `production` — `db.yml` forks
preview branches from one of those two by name.
