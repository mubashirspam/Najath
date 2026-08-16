# Najath Quran Academy — ERP monorepo

|                     |                                                                                  |
| ------------------- | -------------------------------------------------------------------------------- |
| Admin console + API | `apps/web` — Next.js 16, Tailwind 4, shadcn/ui (radix base, nova preset)         |
| Mobile              | `apps/mobile` — Flutter 3.44, Dart pub workspace, Riverpod 3                     |
| Shared TS packages  | `packages/{db,contracts,core,auth,jobs,ui}` under the `@najath/*` scope          |
| Database            | Neon Postgres (`najath_erp`) via Drizzle                                         |
| Auth                | Better Auth — staff email/password, guardian phone OTP, bearer tokens for mobile |
| Background jobs     | Trigger.dev                                                                      |

## Setup

```bash
pnpm install
cp .env.example .env          # fill in DATABASE_URL and friends

pnpm --filter @najath/db db:generate   # SQL from src/schema
pnpm --filter @najath/db db:migrate    # needs a reachable DATABASE_URL
pnpm dev                                # turbo → next dev on :3000
```

Mobile:

```bash
cd apps/mobile
flutter pub get   # resolves the whole pub workspace; == melos bootstrap
cp config/dev.example.json config/dev.json

cd app
flutter run --flavor dev --dart-define-from-file=../config/dev.json
```

`10.0.2.2` is the Android emulator's route to the host. On a physical device use
your LAN IP and start Next with `pnpm dev -H 0.0.0.0`.

Melos scripts are defined in `apps/mobile/pubspec.yaml` and run without a global
activation:

```bash
dart run melos run analyze | test | gen | gen:watch | format | clean:deep
```

## Things the scaffold left for you

- **`apps/mobile/app/assets/fonts/UthmanicHafs.ttf`** — not redistributable, so
  it is not committed. Drop it in and uncomment the `fonts:` block in
  `apps/mobile/app/pubspec.yaml`; Flutter fails asset bundling if a registered
  font file is missing.
- **`apps/mobile/app/assets/db/quran_index.sqlite`** — generate from the seed
  script in `packages/db` once that lands.
- **Trigger.dev project ref** — `packages/jobs/trigger.config.ts` carries a
  placeholder. Run `pnpm dlx trigger.dev@latest init -p <ref> --override-config`
  from `packages/jobs` once the cloud project exists.
- **Firebase** — `google-services.json` / `GoogleService-Info.plist` per flavor.
  Both are gitignored.

## Mobile architecture

Layering follows the Telios 3.0 reference: routing → UI → Riverpod notifiers →
domain → data → core infrastructure, offline-first throughout. Telios keeps it in
one `lib/`; here the same layers are the workspace packages.

| Telios                                           | Najath package                                      |
| ------------------------------------------------ | --------------------------------------------------- |
| `core/config,constants,error,storage,responsive` | `najath_core`                                       |
| `core/network`                                   | `najath_network` — `DioClient`, `ApiResponse`       |
| Hive local sources                               | `najath_local_db` — drift JSON cache + write outbox |
| `shared/sync`                                    | `najath_sync` — paced pipeline, task registry       |
| `features/auth`                                  | `najath_auth` — session + access policy             |
| `app/theme`, shared widgets                      | `najath_design_system`                              |
| `features/<name>`                                | `packages/features/<name>`                          |

Each feature keeps the same internal shape:

```
features/<name>/lib/src/
├── data/          data_sources/ · models/ (DTOs) · repositories/ (+ providers)
├── domain/        entities/ · repositories/ (contracts) · use_cases/
└── presentation/  notifiers/ · screens/ · widgets/
```

Notifiers are hand-written (`Notifier` / `AsyncNotifier`), as in Telios. The one
exception to "no codegen" is drift, which requires it — everything else is
hand-written `fromJson` / `toEntity` / `copyWith`.

`packages/features/attendance` is the worked example of the whole stack; the
other modules are wired but their screens are placeholders.

### Offline

Reads are cache-first: `CacheStore` holds one JSON document per row in a named
box, and repositories fall back to the network only on a miss. Writes are the
other way round — `OutboxStore` commits locally and queues the request, and
`SyncEngine` drains it oldest-first when a transport appears. A repeated edit of
the same target collapses on `dedupeKey`, so correcting a mark three times
offline still sends one request carrying the final answer.

`SyncEngine` knows nothing about any feature: modules register a `SyncTask` and
the app supplies the list via `syncTasksProvider`.

## Roles and screen access

The admin console controls which screens each role can open. The registry lives
in `packages/contracts/src/access.ts` — the single source of truth for the
console, the API, and the app. The Dart mirror
(`apps/mobile/packages/core/lib/src/access/screen_registry.dart`) is emitted from
it and CI fails if it drifts:

```bash
pnpm --filter @najath/contracts emit:dart
```

`resolveAccessPolicy` (`@najath/core`) layers registry defaults → the role
matrix → per-role permission overrides → per-user overrides, and serves the
result from `GET /api/v1/me/access`. A screen survives only if it is granted
**and** the role still holds the permission it declares, so revoking a
permission closes every screen depending on it.

On the device the policy is cached in secure storage (not the clearable cache),
so access stays correct offline. It drives three things: the router's redirect
guard, the nav shell's destinations, and `PermissionGate` / `ScreenGate` around
individual affordances. A 403 from the API refetches the policy — that means an
admin changed the matrix since the last fetch.

None of this is the security boundary; the API re-checks every request. It is
what stops the UI offering things that would 403.

## Branches and environments

Three long-lived branches, **two** databases — `dev` and `staging` share one.

| Branch       | Flavor    | GitHub environment | Database          |
| ------------ | --------- | ------------------ | ----------------- |
| `dev`        | `dev`     | `dev`              | shared Neon `dev` |
| `staging`    | `staging` | `dev`              | shared Neon `dev` |
| `production` | `prod`    | `production`       | Neon `production` |

Feature branches PR into `dev`; `dev` promotes to `staging`, `staging` to
`production`. Because `dev` and `staging` point at the same database, a
migration that lands on `dev` is already applied by the time `staging` runs —
Drizzle skips anything in its journal table, so the second run is a no-op.

`DATABASE_URL` lives on the GitHub environment, not on the repo, which is what
makes the sharing a one-line mapping in `.github/workflows/db.yml` rather than a
duplicated secret. Put production behind required reviewers on the `production`
environment.

## CI

| Workflow | Runs                                                                                        |
| -------- | ------------------------------------------------------------------------------------------- |
| `ci.yml` | prettier `--check`, `turbo run lint typecheck build`, `melos run analyze`, `melos run test` |
| `ci.yml` | Android debug APK — only on pushes to a shared branch, or PRs into `production`             |
| `db.yml` | migrations; see below                                                                       |

## Migrations

CI owns every `db:migrate`. You run `db:generate` locally and commit the SQL +
journal; `.github/workflows/db.yml` spins up a throwaway Neon branch for each PR
that touches `packages/db` — forked from `production` when the PR targets
`production`, from `dev` otherwise — and applies migrations to the shared or
production database on push. See [ADR 0001](docs/adr/0001-migrations-run-in-ci.md).

Needs one repo variable and two secrets:

|                        |                                                |
| ---------------------- | ---------------------------------------------- |
| `vars.NEON_PROJECT_ID` | Neon project id                                |
| `secrets.NEON_API_KEY` | Neon API key, for preview branch create/delete |
| `secrets.DATABASE_URL` | set **per environment** (`dev`, `production`)  |

## Known version constraints

The Dart analyzer-plugin ecosystem is behind analyzer 13, which forces a few pins:

- `riverpod_lint` and `custom_lint` are **not** installed — neither supports the
  analyzer version that `drift_dev` + `riverpod_generator` require. Linting is
  `very_good_analysis` only, via `apps/mobile/analysis_options.yaml`. Re-add them
  once they ship analyzer 12+ support.
- `melos` is pinned `<7.8.2`; from that version it needs `cli_util ^0.5.0`, which
  `drift_dev` 2.34.0 cannot satisfy.
- `freezed` resolves to a `3.2.6-dev` prerelease for the same reason.
- `flutter_secure_storage` is pinned to `^10.3.1`. Version 11 declares
  `compileSdk = 37`, which AGP resolves to the platform `android-37` — and Google
  no longer publishes one, only `android-37.0` and `android-37.1`. The Android
  build fails outright on 11.x. Unpin when the plugin adopts a minor SDK version.
