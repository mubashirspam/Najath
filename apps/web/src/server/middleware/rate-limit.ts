import { ApiError } from '../http/envelope';

/**
 * Fixed-window rate limiter, in process memory.
 *
 * Deliberately simple and deliberately temporary: on Vercel each lambda has its
 * own memory, so the effective limit is per-instance rather than global. That is
 * enough to blunt a stuck retry loop — a teacher's phone hammering
 * `/attendance/batch` — which is the failure this actually protects against.
 *
 * It is **not** enough for credential stuffing. `POST /auth/otp/request` needs a
 * shared store before launch; the OTP lockout in M01-API-02 is the real defence
 * and it lives in the database.
 *
 * TODO(P0-API-05): move to Upstash or Vercel KV when the first public endpoint
 * ships.
 */
interface Window {
  count: number;
  resetAt: number;
}

const windows = new Map<string, Window>();

/** Trims expired entries so a long-lived instance does not grow without bound. */
function sweep(now: number) {
  if (windows.size < 5_000) return;
  for (const [key, window] of windows) {
    if (window.resetAt <= now) windows.delete(key);
  }
}

export interface RateLimit {
  /** Requests allowed per window. */
  limit: number;
  /** Window length in milliseconds. */
  windowMs: number;
}

export const RATE_LIMITS = {
  /** Ordinary authenticated reads and writes. */
  default: { limit: 120, windowMs: 60_000 },
  /** Batch endpoints — one request carries up to 100 items already. */
  batch: { limit: 30, windowMs: 60_000 },
  /** Anything unauthenticated. Tighter, because the identity is unproven. */
  auth: { limit: 10, windowMs: 60_000 },
} as const satisfies Record<string, RateLimit>;

export interface RateLimitResult {
  remaining: number;
  resetAt: number;
}

/**
 * Consumes one unit. Throws `RATE_LIMITED` when the window is exhausted.
 *
 * Keyed by user when there is one and by IP otherwise, so one noisy tenant on a
 * shared school NAT cannot lock out the rest of the staff room.
 */
export function consume(key: string, config: RateLimit): RateLimitResult {
  const now = Date.now();
  sweep(now);

  const existing = windows.get(key);

  if (!existing || existing.resetAt <= now) {
    const window = { count: 1, resetAt: now + config.windowMs };
    windows.set(key, window);
    return { remaining: config.limit - 1, resetAt: window.resetAt };
  }

  existing.count += 1;

  if (existing.count > config.limit) {
    const retryAfter = Math.ceil((existing.resetAt - now) / 1000);
    throw new ApiError('RATE_LIMITED', 'Too many requests — slow down', {
      details: { retryAfterSeconds: retryAfter },
    });
  }

  return { remaining: config.limit - existing.count, resetAt: existing.resetAt };
}

/** Only for tests — production never needs to forget a window. */
export function resetAll() {
  windows.clear();
}
