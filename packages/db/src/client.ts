import { Pool, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-serverless';
import * as schema from './schema';

type NeonDb = ReturnType<typeof createDb>;

function createDb() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
  }

  // The WebSocket driver, not `neon()` over HTTP.
  //
  // HTTP is faster for one-shot reads, but `drizzle-orm/neon-http` throws
  // "No transactions support" — and this schema cannot be written without
  // transactions. An append-only correction is two statements (insert the new
  // row, flip `is_current` on the old), and every mutation writes `audit_log`
  // alongside the change. Either of those half-applied is a corrupt academic
  // record, which is the one thing this system exists to prevent.
  //
  // Node 22+ ships a global WebSocket; without it the driver needs the `ws`
  // package.
  if (!neonConfig.webSocketConstructor && typeof globalThis.WebSocket !== 'undefined') {
    neonConfig.webSocketConstructor = globalThis.WebSocket;
  }

  return drizzle({
    client: new Pool({ connectionString: url }),
    schema,
    casing: 'snake_case',
  });
}

let instance: NeonDb | undefined;

/**
 * The Drizzle client, created on first use.
 *
 * Lazy on purpose: `next build` statically evaluates every route module, so a
 * connection built at import time turns a missing `DATABASE_URL` into a build
 * failure rather than a request-time error. The proxy keeps the ergonomic
 * `db.select()` call shape while deferring construction.
 */
export const db = new Proxy({} as NeonDb, {
  get(_target, property, receiver) {
    instance ??= createDb();
    return Reflect.get(instance, property, receiver) as unknown;
  },
});

export type Db = NeonDb;
