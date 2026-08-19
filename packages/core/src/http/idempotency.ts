import { createHash } from 'node:crypto';
import { and, eq, lt } from 'drizzle-orm';
import type { ErrorCode } from '@najath/contracts';
import { db, schema } from '@najath/db';

/**
 * A failure a route handler turns into an error envelope.
 *
 * Declared here rather than imported from the web app: `@najath/core` must not
 * depend on Next, or a Trigger.dev job could not call the same code.
 */
export class ServiceError extends Error {
  constructor(
    readonly code: ErrorCode,
    message?: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message ?? code);
    this.name = 'ServiceError';
  }
}

/** Keys are kept seven days, per the sync rules. */
const TTL_MS = 7 * 24 * 60 * 60 * 1000;

export interface StoredResponse {
  status: number;
  body: unknown;
}

/**
 * Replay protection for anything the mobile outbox can send twice.
 *
 * The teacher's phone retrying while the first request is still committing is
 * the normal case on a halaqa's connection, not an edge case. Without this a
 * retry writes a second attendance mark and the roster shows a duplicate the
 * teacher never made.
 */
export class IdempotencyStore {
  /**
   * Returns a stored response when this key has already been answered.
   *
   * Rejects a key reused with a *different* body: that is a client bug — two
   * unrelated writes sharing a key — and returning the first response would
   * silently discard the second.
   */
  static async lookup(
    key: string,
    endpoint: string,
    body: unknown,
  ): Promise<StoredResponse | null> {
    const [row] = await db
      .select()
      .from(schema.idempotencyKeys)
      .where(eq(schema.idempotencyKeys.key, key))
      .limit(1);

    if (!row) return null;

    if (row.expiresAt.getTime() <= Date.now()) {
      await db.delete(schema.idempotencyKeys).where(eq(schema.idempotencyKeys.key, key));
      return null;
    }

    const hash = IdempotencyStore.hash(body);
    if (row.endpoint !== endpoint || row.requestHash !== hash) {
      throw new ServiceError(
        'IDEMPOTENCY_KEY_REUSED',
        'This Idempotency-Key was already used for a different request',
        { endpoint: row.endpoint },
      );
    }

    // Still in flight: the first request reserved the key but has not written
    // its response yet. Answering "conflict" is right — the client should
    // back off and retry, not receive a half-truth.
    if (row.responseStatus === null) {
      throw new ServiceError('CONFLICT', 'That request is still being processed', {
        retryAfterSeconds: 2,
      });
    }

    return {
      status: Number(row.responseStatus),
      body: row.responseBody,
    };
  }

  /**
   * Reserves the key before the work runs.
   *
   * Reserving first is what closes the race: two concurrent retries cannot both
   * get past this, because the primary key collides.
   */
  static async reserve(params: {
    key: string;
    userId: string | null;
    endpoint: string;
    body: unknown;
  }): Promise<void> {
    try {
      await db.insert(schema.idempotencyKeys).values({
        key: params.key,
        userId: params.userId,
        endpoint: params.endpoint,
        requestHash: IdempotencyStore.hash(params.body),
        expiresAt: new Date(Date.now() + TTL_MS),
      });
    } catch {
      // The row appeared between lookup and reserve — another retry won the
      // race. Treat it exactly as an in-flight duplicate.
      throw new ServiceError('CONFLICT', 'That request is still being processed', {
        retryAfterSeconds: 2,
      });
    }
  }

  /** Records the response so a later replay returns the identical answer. */
  static async complete(key: string, status: number, body: unknown): Promise<void> {
    await db
      .update(schema.idempotencyKeys)
      .set({ responseStatus: String(status), responseBody: body as never })
      .where(eq(schema.idempotencyKeys.key, key));
  }

  /**
   * Releases a reservation whose work failed.
   *
   * Without this a transient 500 would poison the key for seven days and the
   * client's retry — the thing most likely to succeed — would be refused.
   */
  static async release(key: string): Promise<void> {
    await db.delete(schema.idempotencyKeys).where(
      and(
        eq(schema.idempotencyKeys.key, key),
        // Only if nothing was recorded; never drop a completed answer.
        eq(schema.idempotencyKeys.responseStatus, null as never),
      ),
    );
  }

  /** Nightly cleanup. Cheap enough to also run opportunistically. */
  static async purgeExpired(): Promise<void> {
    await db.delete(schema.idempotencyKeys).where(lt(schema.idempotencyKeys.expiresAt, new Date()));
  }

  static hash(body: unknown): string {
    return createHash('sha256')
      .update(JSON.stringify(body ?? null))
      .digest('hex');
  }
}
