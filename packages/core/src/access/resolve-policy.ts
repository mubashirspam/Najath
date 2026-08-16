import { eq, inArray } from 'drizzle-orm';
import {
  ROLES,
  SCREENS,
  defaultScreensForRole,
  permissionsForRole,
  screenById,
  shellForRole,
  type AccessPolicy,
  type Permission,
  type Role,
  type ScreenId,
} from '@najath/contracts';
import { db, schema } from '@najath/db';

/** Everything a request needs to answer "may this actor do this, to this?". */
export interface ActorContext {
  userId: string;
  roles: Role[];
  activeRole: Role;
  scopes: AccessPolicy['scopes'];
}

/**
 * Loads a principal's roles and the concrete ids each one reaches.
 *
 * `user_roles` gives the roles and their declared scope type. The *ids* come
 * from elsewhere — a teacher's batches from `staff_assignments`, a guardian's
 * wards from `student_guardians` — because those move without anyone touching
 * the role grant.
 */
export async function loadActorContext(userId: string): Promise<ActorContext | null> {
  const roleRows = await db
    .select()
    .from(schema.userRoles)
    .where(eq(schema.userRoles.userId, userId));

  const roles = roleRows
    .map((r) => r.role)
    .filter((r): r is Role => (ROLES as readonly string[]).includes(r));

  if (roles.length === 0) return null;

  const departmentIds = new Set<string>();
  const hostelIds = new Set<string>();
  for (const row of roleRows) {
    if (!row.scopeId) continue;
    if (row.scopeType === 'DEPARTMENT') departmentIds.add(row.scopeId);
    if (row.scopeType === 'HOSTEL') hostelIds.add(row.scopeId);
  }

  const needsAssignments = roles.includes('TEACHER') || roles.includes('DEPT_HEAD');
  const needsWards = roles.includes('PARENT');

  const [assignments, wards] = await Promise.all([
    needsAssignments
      ? db
          .select({
            batchId: schema.staffAssignments.batchId,
            classSectionId: schema.staffAssignments.classSectionId,
            departmentId: schema.staffAssignments.departmentId,
          })
          .from(schema.staffAssignments)
          .innerJoin(schema.staff, eq(schema.staff.id, schema.staffAssignments.staffId))
          .where(eq(schema.staff.userId, userId))
      : Promise.resolve([]),

    // The only path from a non-staff account to a student. Resolved once here
    // so every downstream query filters on ids instead of re-joining.
    needsWards
      ? db
          .select({ studentId: schema.studentGuardians.studentId })
          .from(schema.studentGuardians)
          .innerJoin(schema.guardians, eq(schema.guardians.id, schema.studentGuardians.guardianId))
          .where(eq(schema.guardians.userId, userId))
      : Promise.resolve([]),
  ]);

  const batchIds = new Set<string>();
  const classSectionIds = new Set<string>();
  for (const a of assignments) {
    if (a.batchId) batchIds.add(a.batchId);
    if (a.classSectionId) classSectionIds.add(a.classSectionId);
    if (a.departmentId) departmentIds.add(a.departmentId);
  }

  return {
    userId,
    roles,
    activeRole: preferredRole(roles),
    scopes: {
      departmentIds: [...departmentIds],
      batchIds: [...batchIds],
      classSectionIds: [...classSectionIds],
      hostelIds: [...hostelIds],
      wardIds: [...new Set(wards.map((w) => w.studentId))],
    },
  };
}

/**
 * The role a multi-role user lands on before choosing in the switcher.
 *
 * `ROLES` is declared most-privileged first, so someone who is both a DEPT_HEAD
 * and a TEACHER opens on the shell that shows them everything.
 */
function preferredRole(roles: readonly Role[]): Role {
  return ROLES.find((candidate) => roles.includes(candidate)) ?? 'PARENT';
}

/**
 * Resolves what a principal may do and see.
 *
 * Layered, most general first:
 *   1. the permissions the RBAC matrix gives each of their roles,
 *   2. the registry's default screens for those roles,
 *   3. the admin console's per-role screen overrides,
 *   4. per-user screen overrides.
 *
 * A screen survives only if it is allowed **and** the principal still holds the
 * permission it declares. That second condition is what makes revoking a
 * permission close every screen depending on it, without anyone having to
 * remember which ones those were.
 */
export async function resolveAccessPolicy(actor: ActorContext): Promise<AccessPolicy> {
  const [screenRows, userRows, versionRow] = await Promise.all([
    db
      .select()
      .from(schema.roleScreenAccess)
      .where(inArray(schema.roleScreenAccess.role, actor.roles)),
    db
      .select()
      .from(schema.userScreenOverride)
      .where(eq(schema.userScreenOverride.userId, actor.userId)),
    db.select().from(schema.accessPolicyVersion).limit(1),
  ]);

  // 1 — the union of every role's permissions.
  const permissions = new Set<Permission>();
  for (const role of actor.roles) {
    for (const permission of permissionsForRole(role)) permissions.add(permission);
  }

  // 2 — registry defaults.
  const screens = new Set<string>();
  for (const role of actor.roles) {
    for (const id of defaultScreensForRole(role)) screens.add(id);
  }

  // 3 — the admin matrix. A row exists only where an admin diverged from the
  // default, so an untouched institution runs entirely on the registry.
  for (const row of screenRows) {
    if (!screenById(row.screenId)) continue; // removed from the registry since
    if (row.allowed) screens.add(row.screenId);
    else screens.delete(row.screenId);
  }

  // 4 — per-user overrides win over the role matrix.
  for (const row of userRows) {
    if (!screenById(row.screenId)) continue;
    if (row.allowed) screens.add(row.screenId);
    else screens.delete(row.screenId);
  }

  // A screen whose permission the principal does not hold is unreachable,
  // whatever the matrix says.
  for (const id of [...screens]) {
    const screen = screenById(id);
    if (!screen || !permissions.has(screen.requires)) screens.delete(id);
  }

  return {
    roles: actor.roles,
    activeRole: actor.activeRole,
    permissions: [...permissions],
    screens: [...screens] as ScreenId[],
    scopes: actor.scopes,
    version: Number(versionRow[0]?.version ?? 1),
  };
}

/** The shell the mobile app opens for this principal. */
export function shellFor(actor: ActorContext) {
  return shellForRole(actor.activeRole);
}

/** Records one cell of the admin console's matrix, bumps the version, audits. */
export async function setRoleScreenAccess(params: {
  role: Role;
  screenId: ScreenId;
  allowed: boolean;
  updatedBy: string;
}): Promise<number> {
  return db.transaction(async (tx) => {
    await tx
      .insert(schema.roleScreenAccess)
      .values({
        role: params.role,
        screenId: params.screenId,
        allowed: params.allowed,
        updatedBy: params.updatedBy,
      })
      .onConflictDoUpdate({
        target: [schema.roleScreenAccess.role, schema.roleScreenAccess.screenId],
        set: { allowed: params.allowed, updatedBy: params.updatedBy, updatedAt: new Date() },
      });

    const [row] = await tx.select().from(schema.accessPolicyVersion).limit(1);
    const next = row ? Number(row.version) + 1 : 1;

    if (row) {
      await tx
        .update(schema.accessPolicyVersion)
        .set({ version: String(next), updatedAt: new Date() })
        .where(eq(schema.accessPolicyVersion.id, row.id));
    } else {
      await tx
        .insert(schema.accessPolicyVersion)
        .values({ id: 'singleton', version: String(next) });
    }

    // Same transaction as the change — an audit row written afterwards is one
    // that can go missing exactly when it matters.
    await tx.insert(schema.auditLog).values({
      actorId: params.updatedBy,
      entity: 'role_screen_access',
      action: params.allowed ? 'grant' : 'revoke',
      after: { role: params.role, screenId: params.screenId, allowed: params.allowed },
    });

    return next;
  });
}

/** The full matrix, for the admin console's grid. */
export async function loadAccessMatrix(): Promise<Record<Role, Record<string, boolean>>> {
  const rows = await db.select().from(schema.roleScreenAccess);
  const overrides = new Map(rows.map((r) => [`${r.role}:${r.screenId}`, r.allowed]));

  const matrix = {} as Record<Role, Record<string, boolean>>;
  for (const role of ROLES) {
    const defaults = new Set<string>(defaultScreensForRole(role));
    matrix[role] = Object.fromEntries(
      SCREENS.map((screen) => [
        screen.id,
        overrides.get(`${role}:${screen.id}`) ?? defaults.has(screen.id),
      ]),
    );
  }
  return matrix;
}

/**
 * Is a concrete id inside the actor's reach for this scope type?
 *
 * The guard calls this after the role check. A `GLOBAL` grant short-circuits;
 * everything else is an id membership test against what `loadActorContext`
 * resolved.
 */
export function scopeContains(actor: ActorContext, scopeType: string, id: string): boolean {
  switch (scopeType) {
    case 'GLOBAL':
      return true;
    case 'DEPARTMENT':
      return actor.scopes.departmentIds.includes(id);
    case 'ASSIGNED':
      return actor.scopes.batchIds.includes(id) || actor.scopes.classSectionIds.includes(id);
    case 'HOSTEL':
      return actor.scopes.hostelIds.includes(id);
    case 'WARD':
      return actor.scopes.wardIds.includes(id);
    case 'SELF':
      return actor.userId === id;
    default:
      return false;
  }
}
