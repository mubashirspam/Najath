import { config } from 'dotenv';
import { defineConfig } from 'drizzle-kit';

// Env lives at the monorepo root, not in this package.
config({ path: '../../.env' });

export default defineConfig({
  schema: './src/schema/index.ts',
  out: './migrations',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
  casing: 'snake_case',
  verbose: true,
  strict: true,
});
