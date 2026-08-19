import { NextResponse } from 'next/server';
import type { ZodType } from 'zod';
import { auth } from '@najath/auth';
import {
  assertCan,
  ForbiddenError,
  IdempotencyStore,
  loadActorContext,
  ServiceError,
  type ActorContext,
} from '@najath/core';
import type { Action, Resource, ScopeType } from '@najath/contracts';

import { consume, RATE_LIMITS, type RateLimit } from '../middleware/rate-limit';
import { ApiError, failure, success } from './envelope';
import { zodIssues } from './zod';

/**
 * The request pipeline, in the order the handbook mandates:
 *
 *   rate limit → auth → context → parse → policy → service → envelope → audit
 *
 * The order is not arbitrary. **RBAC runs after Zod** because the guard needs
 * parsed ids to check scope — "may this teacher write to batch X" cannot be
 * answered before X is parsed. And idempotency reserves *before* the service
 * runs, because reserving afterwards leaves the race it exists to close.
 *
 * Route handlers stay thin: they wire this and call one service function.
 * Business logic in a route handler is a review rejection.
 */

export interface RequestContext<TInput> {
  input: TInput;
  actor: ActorContext;
  request: Request;
  /** Present when the route declared `idempotent`. */
  idempotencyKey?: string;
}

/** What the route asks the guard to check before the service runs. */
export interface PolicyRequirement<TInput> {
  resource: Resource;
  action: Action;
  /**
   * Pulls the target id out of the parsed input, so the guard can check scope.
   * Omit for collection reads — the service narrows by `actor.scopes` instead.
   */
  target?: (input: TInput) => { id: string; scopeType?: ScopeType } | undefined;
}

export interface RouteConfig<TInput, TOutput> {
  /** Zod schema for body (mutations) or search params (reads). */
  input?: ZodType<TInput>;
  policy?: PolicyRequirement<TInput>;
  /** Requires and honours `Idempotency-Key`. Mandatory for outbox-replayable writes. */
  idempotent?: boolean;
  rateLimit?: RateLimit;
  /** Skips the auth resolver. Only for sign-in and health. */
  public?: boolean;
  run: (context: RequestContext<TInput>) => Promise<TOutput>;
}

type RouteHandler = (request: Request) => Promise<NextResponse>;

export function handler<TInput = undefined, TOutput = unknown>(
  config: RouteConfig<TInput, TOutput>,
): RouteHandler {
  return async (request: Request): Promise<NextResponse> => {
    let reservedKey: string | undefined;

    try {
      // ── 1. rate limit ──────────────────────────────────────────────────────
      // Keyed by user once we have one, IP before that, so a school's shared
      // NAT cannot lock out the whole staff room.
      const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';

      // ── 2. auth ────────────────────────────────────────────────────────────
      const session = config.public
        ? null
        : await auth.api.getSession({ headers: request.headers });

      if (!config.public && !session?.user) {
        throw new ApiError('UNAUTHENTICATED', 'Sign in to continue');
      }

      const userId = session?.user.id ?? null;
      const limit = config.rateLimit ?? (config.public ? RATE_LIMITS.auth : RATE_LIMITS.default);
      const rate = consume(`${userId ?? ip}:${new URL(request.url).pathname}`, limit);

      // ── 3. context ─────────────────────────────────────────────────────────
      let actor: ActorContext | null = null;
      if (userId) {
        actor = await loadActorContext(userId);
        if (!actor) {
          // Authenticated but holding no role. A real state — a guardian
          // invited before their ward's row was written — and the app renders
          // it as "no sections enabled yet" rather than as an error.
          throw new ApiError('NO_ROLES_ASSIGNED', 'This account has no roles assigned yet');
        }
      }

      // ── 4. parse ───────────────────────────────────────────────────────────
      const input = await parseInput(request, config.input);

      // ── 5. policy ──────────────────────────────────────────────────────────
      if (config.policy && actor) {
        const target = config.policy.target?.(input);
        assertCan(actor, config.policy.resource, config.policy.action, target);
      }

      // ── 6. idempotency + service ───────────────────────────────────────────
      const idempotencyKey = request.headers.get('Idempotency-Key') ?? undefined;

      if (config.idempotent) {
        if (!idempotencyKey) {
          throw new ApiError(
            'IDEMPOTENCY_KEY_REQUIRED',
            'This endpoint requires an Idempotency-Key header',
          );
        }

        const endpoint = new URL(request.url).pathname;
        const replayed = await IdempotencyStore.lookup(idempotencyKey, endpoint, input);
        if (replayed) {
          return NextResponse.json(replayed.body, {
            status: replayed.status,
            headers: { 'Idempotent-Replay': 'true' },
          });
        }

        await IdempotencyStore.reserve({
          key: idempotencyKey,
          userId,
          endpoint,
          body: input,
        });
        reservedKey = idempotencyKey;
      }

      const output = await config.run({
        input,
        actor: actor as ActorContext,
        request,
        idempotencyKey,
      });

      // ── 7. envelope ────────────────────────────────────────────────────────
      const response = success(
        output,
        {},
        {
          headers: {
            'X-RateLimit-Remaining': String(rate.remaining),
            'X-RateLimit-Reset': String(rate.resetAt),
          },
        },
      );

      if (reservedKey) {
        await IdempotencyStore.complete(reservedKey, 200, await response.clone().json());
      }

      return response;
    } catch (error) {
      // A reservation whose work failed must be released, or a transient 500
      // would poison the key for seven days and refuse the client's retry —
      // the thing most likely to succeed.
      if (reservedKey) await IdempotencyStore.release(reservedKey).catch(() => {});

      return failure(toApiError(error));
    }
  };
}

async function parseInput<TInput>(request: Request, schema?: ZodType<TInput>): Promise<TInput> {
  if (!schema) return undefined as TInput;

  const raw =
    request.method === 'GET' || request.method === 'DELETE'
      ? Object.fromEntries(new URL(request.url).searchParams)
      : await request.json().catch(() => ({}));

  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    const issues = zodIssues(parsed.error);
    throw new ApiError('VALIDATION_FAILED', 'Some fields need correcting', {
      field: issues[0]?.path,
      details: { issues },
    });
  }
  return parsed.data;
}

function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;

  if (error instanceof ForbiddenError) {
    return new ApiError(error.code, error.message);
  }

  if (error instanceof ServiceError) {
    return new ApiError(error.code, error.message, { details: error.details });
  }

  // Anything else is a bug. Log it with the stack, return a code — never leak
  // an internal message to a guardian's phone.
  console.error('[api] unhandled', error);
  return new ApiError('INTERNAL_ERROR', 'Something went wrong');
}
