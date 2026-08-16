import {
  grantFor,
  roleAllows,
  widestScope,
  type Action,
  type Resource,
  type ScopeType,
} from '@najath/contracts';

import { scopeContains, type ActorContext } from './resolve-policy';

export type GuardResult =
  | { ok: true; scope: ScopeType }
  | { ok: false; code: 'FORBIDDEN_ROLE' | 'FORBIDDEN_SCOPE'; reason: string };

/**
 * The authorization check every mutating route runs, after Zod and before the
 * service.
 *
 * Answers two of the three questions from the handbook — role and scope. The
 * third, **state**, cannot be answered here because it needs the record: a
 * teacher may edit attendance only on the same day, marks lock after
 * `verified`, a report is immutable once published. Those live in the service,
 * and the grant's `condition` field names them so they are discoverable rather
 * than folklore.
 */
export function can(
  actor: ActorContext,
  resource: Resource,
  action: Action,
  target?: { scopeType?: ScopeType; id?: string },
): GuardResult {
  if (!roleAllows(actor.roles, resource, action)) {
    return {
      ok: false,
      code: 'FORBIDDEN_ROLE',
      reason: `no role of ${actor.roles.join('/')} grants ${resource}:${action}`,
    };
  }

  const widest = widestScope(actor.roles, resource, action);
  if (!widest) {
    return { ok: false, code: 'FORBIDDEN_ROLE', reason: `no scope for ${resource}:${action}` };
  }

  // A collection read has no single target; the caller narrows the query by
  // `actor.scopes`, which is already the union across roles.
  if (!target?.id) return { ok: true, scope: widest };

  if (target.scopeType) {
    return scopeContains(actor, target.scopeType, target.id)
      ? { ok: true, scope: target.scopeType }
      : {
          ok: false,
          code: 'FORBIDDEN_SCOPE',
          reason: `${target.id} is outside this actor's ${target.scopeType} scope`,
        };
  }

  // Check every grant, not just the widest one.
  //
  // Roles are a disjunction: a teacher who is also a parent of a student in the
  // same college reaches that child through their PARENT grant even though the
  // child sits in another teacher's batch. Taking only the widest scope —
  // ASSIGNED beats WARD — would deny them their own child's attendance.
  const scopes = actor.roles
    .map((role) => grantFor(role, resource))
    .filter((grant) => grant?.actions.includes(action))
    .map((grant) => grant!.scope);

  const matched = scopes.find((scope) => scopeContains(actor, scope, target.id!));
  if (matched) return { ok: true, scope: matched };

  return {
    ok: false,
    code: 'FORBIDDEN_SCOPE',
    reason: `${target.id} is outside this actor's ${scopes.join('/')} scope`,
  };
}

/** Throwing form, for services that would rather not branch. */
export class ForbiddenError extends Error {
  constructor(
    readonly code: 'FORBIDDEN_ROLE' | 'FORBIDDEN_SCOPE',
    reason: string,
  ) {
    super(reason);
    this.name = 'ForbiddenError';
  }
}

export function assertCan(
  actor: ActorContext,
  resource: Resource,
  action: Action,
  target?: { scopeType?: ScopeType; id?: string },
): ScopeType {
  const result = can(actor, resource, action, target);
  if (!result.ok) throw new ForbiddenError(result.code, result.reason);
  return result.scope;
}

/**
 * The state conditions attached to a grant, for the service to enforce.
 *
 * Returns the human-readable rule so a 403 can explain itself — "same calendar
 * day only" is a far better answer than "forbidden".
 */
export function conditionFor(
  actor: ActorContext,
  resource: Resource,
  action: Action,
): string | null {
  for (const role of actor.roles) {
    const grant = grantFor(role, resource);
    if (grant?.actions.includes(action) && grant.condition) return grant.condition;
  }
  return null;
}
