import { config } from 'dotenv';
import { defineConfig } from 'drizzle-kit';

// Env lives at the monorepo root, not in this package.
config({ path: '../../.env' });

/**
 * Production, for INSPECTION ONLY — `pnpm --filter @najath/db db:studio:prod`.
 *
 * There is deliberately no `db:migrate:prod` script pointing here. CI owns every
 * migration (ADR-0001): a migration applied from a laptop is invisible to the
 * journal check that guards the PR, so the next PR's check fails against a
 * database nobody can explain.
 *
 * If you are about to run `drizzle-kit migrate --config drizzle.config.prod.ts`,
 * the answer is a PR into `main` instead.
 */
// `??` would not catch this: an unset variable in .env is an empty string, not
// undefined, and an empty URL fails later with an opaque connection error.
const url = process.env.DATABASE_URL_PROD;
if (!url) {
  throw new Error(
    'DATABASE_URL_PROD is empty. Set it in .env — see docs/engineering/06-environments.md',
  );
}

export default defineConfig({
  schema: './src/schema/index.ts',
  out: './migrations',
  dialect: 'postgresql',
  dbCredentials: { url },
  casing: 'snake_case',
  verbose: true,
  strict: true,
});
