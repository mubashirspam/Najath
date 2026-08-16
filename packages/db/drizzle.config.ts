import { config } from 'dotenv';
import { defineConfig } from 'drizzle-kit';

// Env lives at the monorepo root, not in this package.
config({ path: '../../.env' });

// Migrations want the DIRECT endpoint. The app's `DATABASE_URL` is the pooled
// one, and PgBouncer in transaction mode drops the session-level state
// drizzle-kit relies on — protocol-level prepared statements and the advisory
// lock that stops two migrations racing. Falls back to DATABASE_URL so a
// single-URL setup still works.
const url = process.env.DATABASE_URL_UNPOOLED || process.env.DATABASE_URL;
if (!url) {
  throw new Error(
    'Set DATABASE_URL_UNPOOLED (preferred) or DATABASE_URL — see docs/engineering/06-environments.md',
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
