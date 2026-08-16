import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import * as schema from './schema';

type NeonDb = ReturnType<typeof createDb>;

function createDb() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
  }
  return drizzle({ client: neon(url), schema, casing: 'snake_case' });
}

let instance: NeonDb | undefined;

/**
 * The Drizzle client, created on first use.
 *
 * Lazy on purpose: `next build` statically evaluates every route module, so a
 * connection built at import time turns a missing `DATABASE_URL` into a build
 * failure rather than a request-time error. The proxy keeps the ergonomic
 * `db.select()` call shape while deferring the actual construction.
 */
export const db = new Proxy({} as NeonDb, {
  get(_target, property, receiver) {
    instance ??= createDb();
    return Reflect.get(instance, property, receiver) as unknown;
  },
});

export type Db = NeonDb;
