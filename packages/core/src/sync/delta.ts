import { and, gt, inArray, or, type SQL } from 'drizzle-orm';
import { db, schema } from '@najath/db';

import type { ActorContext } from '../access/resolve-policy';
import { ServiceError } from '../http/idempotency';

/**
 * Entities a client may pull. A closed set, because an open one lets a client
 * name a table and read past its scope.
 */
export const SYNC_ENTITIES = [
  'students',
  'enrollments',
  'batches',
  'classSections',
  'departments',
  /** A no-op entity used to prove the harness end to end (P0-API-06). */
  'ping',
] as const;

export type SyncEntity = (typeof SYNC_ENTITIES)[number];

export interface EntityDelta {
  entity: SyncEntity;
  /** Rows created or updated since the cursor. */
  changed: Record<string, unknown>[];
  /**
   * Ids that no longer exist for this actor.
   *
   * Not optional. Without tombstones a student transferred out stays on the
   * teacher's roster forever and is marked absent every day.
   */
  tombstones: string[];
}

export interface SyncPullResult {
  entities: EntityDelta[];
  /**
   * The **server's** clock, to be echoed back as the next cursor.
   *
   * Never the client's: a device minutes fast would ask for a window that
   * skips rows, and the loss would be silent.
   */
  cursor: string;
}

/**
 * Delta pull, scoped to what the actor may actually see.
 *
 * Scope is applied **in the query**, not as a filter on the results. Fetching
 * everything and narrowing in memory is how one family's child ends up in
 * another family's response.
 */
export async function pullDelta(params: {
  actor: ActorContext;
  entities: SyncEntity[];
  since?: Date;
}): Promise<SyncPullResult> {
  const { actor, entities } = params;
  // A first pull has no cursor and takes everything the scope allows.
  const since = params.since ?? new Date(0);
  const cursor = new Date();

  const deltas: EntityDelta[] = [];

  for (const entity of entities) {
    switch (entity) {
      case 'ping':
        deltas.push({
          entity,
          changed: [{ id: 'ping', at: cursor.toISOString() }],
          tombstones: [],
        });
        break;

      case 'departments':
        deltas.push({
          entity,
          changed: await db
            .select()
            .from(schema.departments)
            .where(gt(schema.departments.updatedAt, since)),
          tombstones: [],
        });
        break;

      case 'batches':
        deltas.push({
          entity,
          changed: await scopedBatches(actor, since),
          tombstones: [],
        });
        break;

      case 'classSections':
        deltas.push({
          entity,
          changed: await scopedClassSections(actor, since),
          tombstones: [],
        });
        break;

      case 'enrollments': {
        const rows = await scopedEnrollments(actor, since);
        deltas.push({
          entity,
          // A dropped or transferred enrollment is a tombstone, not an update:
          // the client must remove the row, not keep it with a new status.
          changed: rows.filter((r) => r.status === 'active'),
          tombstones: rows.filter((r) => r.status !== 'active').map((r) => r.id),
        });
        break;
      }

      case 'students':
        deltas.push({
          entity,
          changed: await scopedStudents(actor, since),
          tombstones: [],
        });
        break;

      default:
        throw new ServiceError('VALIDATION_FAILED', `Unknown sync entity: ${entity}`);
    }
  }

  return { entities: deltas, cursor: cursor.toISOString() };
}

/**
 * Combines scope predicates with OR.
 *
 * Separate from `or` because an empty list must never become "no predicate",
 * which reads as "everything" — the exact failure this module exists to avoid.
 * Call sites return early on empty instead.
 */
function anyOf(predicates: SQL[]): SQL {
  return predicates.length === 1 ? predicates[0]! : or(...predicates)!;
}

/** The enrollment ids this actor can see, which every academic scope hangs off. */
function enrollmentScope(actor: ActorContext) {
  const { batchIds, classSectionIds, departmentIds, wardIds } = actor.scopes;

  // A GLOBAL actor still goes through a query; the difference is that its
  // predicate is trivially true rather than absent.
  const isGlobal = actor.roles.some((role) => role === 'SUPER_ADMIN' || role === 'ADMIN');

  return { batchIds, classSectionIds, departmentIds, wardIds, isGlobal };
}

async function scopedEnrollments(actor: ActorContext, since: Date) {
  const scope = enrollmentScope(actor);
  const base = db.select().from(schema.enrollments);

  if (scope.isGlobal) {
    return base.where(gt(schema.enrollments.updatedAt, since));
  }

  const predicates: SQL[] = [];
  if (scope.batchIds.length) {
    predicates.push(inArray(schema.enrollments.batchId, scope.batchIds));
  }
  if (scope.classSectionIds.length) {
    predicates.push(inArray(schema.enrollments.classSectionId, scope.classSectionIds));
  }
  if (scope.departmentIds.length) {
    predicates.push(inArray(schema.enrollments.departmentId, scope.departmentIds));
  }
  if (scope.wardIds.length) {
    predicates.push(inArray(schema.enrollments.studentId, scope.wardIds));
  }

  // No scope means no rows — never "everything". A teacher with no assignments
  // yet should see an empty roster, not the institution.
  if (predicates.length === 0) return [];

  return base.where(and(gt(schema.enrollments.updatedAt, since), anyOf(predicates)));
}

async function scopedStudents(actor: ActorContext, since: Date) {
  const scope = enrollmentScope(actor);

  if (scope.isGlobal) {
    return db.select().from(schema.students).where(gt(schema.students.updatedAt, since));
  }

  // Students are reachable only through an enrollment the actor can see, or
  // through guardianship. Resolving the ids first keeps the scope in the query.
  const reachable = new Set<string>(scope.wardIds);
  const enrollments = await scopedEnrollments(actor, new Date(0));
  for (const row of enrollments) reachable.add(row.studentId);

  if (reachable.size === 0) return [];

  return db
    .select()
    .from(schema.students)
    .where(and(gt(schema.students.updatedAt, since), inArray(schema.students.id, [...reachable])));
}

async function scopedBatches(actor: ActorContext, since: Date) {
  const scope = enrollmentScope(actor);
  const base = db.select().from(schema.batches);

  if (scope.isGlobal) return base.where(gt(schema.batches.updatedAt, since));

  const predicates: SQL[] = [];
  if (scope.batchIds.length) predicates.push(inArray(schema.batches.id, scope.batchIds));
  if (scope.departmentIds.length) {
    predicates.push(inArray(schema.batches.departmentId, scope.departmentIds));
  }
  if (predicates.length === 0) return [];

  return base.where(and(gt(schema.batches.updatedAt, since), anyOf(predicates)));
}

async function scopedClassSections(actor: ActorContext, since: Date) {
  const scope = enrollmentScope(actor);
  const base = db.select().from(schema.classSections);

  if (scope.isGlobal) return base.where(gt(schema.classSections.updatedAt, since));

  const predicates: SQL[] = [];
  if (scope.classSectionIds.length) {
    predicates.push(inArray(schema.classSections.id, scope.classSectionIds));
  }
  if (scope.departmentIds.length) {
    predicates.push(inArray(schema.classSections.departmentId, scope.departmentIds));
  }
  if (predicates.length === 0) return [];

  return base.where(and(gt(schema.classSections.updatedAt, since), anyOf(predicates)));
}
