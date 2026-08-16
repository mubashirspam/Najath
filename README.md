# Najath Quran Academy — ERP monorepo

| | |
|---|---|
| Admin console + API | `apps/web` — Next.js 16, Tailwind 4, shadcn/ui (radix base, nova preset) |
| Mobile | `apps/mobile` — Flutter 3.44, Dart pub workspace, Riverpod 3 |
| Shared TS packages | `packages/{db,contracts,core,auth,jobs,ui}` under the `@najath/*` scope |
| Database | Neon Postgres (`najath_erp`) via Drizzle |
| Auth | Better Auth — staff email/password, guardian phone OTP, bearer tokens for mobile |
| Background jobs | Trigger.dev |

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
export PATH="$PATH:$HOME/.pub-cache/bin"   # melos
melos bootstrap                             # == flutter pub get at the root
cd app
flutter run --flavor dev --dart-define-from-file=../config/dev.json
```

`10.0.2.2` is the Android emulator's route to the host. On a physical device use
your LAN IP and start Next with `pnpm dev -H 0.0.0.0`.

Melos scripts (`melos run analyze | test | gen | gen:watch | format`) are defined
in `apps/mobile/pubspec.yaml`.

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

## Migrations

CI owns every `db:migrate`. You run `db:generate` locally and commit the SQL +
journal; `.github/workflows/db.yml` spins up a Neon branch per PR, applies the
migrations there, and migrates `main` on merge. See
[ADR 0001](docs/adr/0001-migrations-run-in-ci.md).

Needs one repo variable and two secrets:

| | |
|---|---|
| `vars.NEON_PROJECT_ID` | Neon project id |
| `secrets.NEON_API_KEY` | Neon API key, for branch create/delete |
| `secrets.DATABASE_URL` | production connection string (`production` environment) |

## Known version constraints

The Dart analyzer-plugin ecosystem is behind analyzer 13, which forces a few pins:

- `riverpod_lint` and `custom_lint` are **not** installed — neither supports the
  analyzer version that `drift_dev` + `riverpod_generator` require. Linting is
  `very_good_analysis` only, via `apps/mobile/analysis_options.yaml`. Re-add them
  once they ship analyzer 12+ support.
- `melos` is pinned `<7.8.2`; from that version it needs `cli_util ^0.5.0`, which
  `drift_dev` 2.34.0 cannot satisfy.
- `freezed` resolves to a `3.2.6-dev` prerelease for the same reason.
