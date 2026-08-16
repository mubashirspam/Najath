import { eq } from 'drizzle-orm';
import {
  ROLES,
  SCREENS,
  defaultScreensForRole,
  screenById,
  type AccessPolicy,
  type Permission,
  type Role,
  type ScreenId,
} from '@najath/contracts/access';
import { db, schema } from '@najath/db';

/**
 * Resolves what one principal may do and see.
 *
 * Layered, most general first:
 *
 *   1. the registry defaults for the role,
 *   2. the admin console's role-level screen matrix,
 *   3. per-role permission overrides,
 *   4. per-user screen overrides.
 *
 * A screen survives only if it is allowed *and* the role still holds the
 * permission it declares. That second condition is what makes revoking a
 * permission close every screen depending on it, without anyone having to
 * remember which ones those were.
 */
export async function resolveAccessPolicy(params: {
  userId: string;
  role: string | null | undefined;
}): Promise<AccessPolicy> {
  const role = normaliseRole(params.role);

  const [screenRows, permissionRows, userRows, versionRow] = await Promise.all([
    db.select().from(schema.roleScreenAccess).where(eq(schema.roleScreenAccess.role, role)),
    db
      .select()
      .from(schema.rolePermissionOverride)
      .where(eq(schema.rolePermissionOverride.role, role)),
    db
      .select()
      .from(schema.userScreenOverride)
      .where(eq(schema.userScreenOverride.userId, params.userId)),
    db.select().from(schema.accessPolicyVersion).limit(1),
  ]);

  // 1 + 2: start from the defaults, then apply the admin matrix.
  const screens = new Set<ScreenId>(defaultScreensForRole(role));
  for (const row of screenRows) {
    const screen = screenById(row.screenId);
    if (!screen) continue; // a screen removed from the registry since the edit
    if (row.allowed) screens.add(screen.id as ScreenId);
    else screens.delete(screen.id as ScreenId);
  }

  // 4: per-user overrides win over the role matrix.
  for (const row of userRows) {
    const screen = screenById(row.screenId);
    if (!screen) continue;
    if (row.allowed) screens.add(screen.id as ScreenId);
    else screens.delete(screen.id as ScreenId);
  }

  // 3: permissions implied by the screens the principal ended up with, plus
  // explicit grants, minus explicit revocations.
  const permissions = new Set<Permission>();
  for (const screen of SCREENS) {
    if (screens.has(screen.id as ScreenId)) permissions.add(screen.requires);
  }
  for (const row of permissionRows) {
    if (row.granted) permissions.add(row.permission as Permission);
    else permissions.delete(row.permission as Permission);
  }

  // Re-check: a screen whose permission was revoked in step 3 is not reachable,
  // whatever the matrix says.
  for (const id of [...screens]) {
    const screen = screenById(id);
    if (!screen || !permissions.has(screen.requires)) screens.delete(id);
  }

  return {
    role,
    permissions: [...permissions],
    screens: [...screens],
    version: versionRow[0]?.version ?? 1,
  };
}

/** Bumps the global version so every cached client policy is refetched. */
export async function bumpAccessPolicyVersion(): Promise<number> {
  const [row] = await db.select().from(schema.accessPolicyVersion).limit(1);

  if (!row) {
    const [created] = await db
      .insert(schema.accessPolicyVersion)
      .values({ id: 1, version: 1 })
      .returning();
    return created?.version ?? 1;
  }

  const [updated] = await db
    .update(schema.accessPolicyVersion)
    .set({ version: row.version + 1, updatedAt: new Date() })
    .where(eq(schema.accessPolicyVersion.id, row.id))
    .returning();

  return updated?.version ?? row.version + 1;
}

/**
 * Records one cell of the admin console's matrix and bumps the version.
 */
export async function setRoleScreenAccess(params: {
  role: Role;
  screenId: ScreenId;
  allowed: boolean;
  updatedBy: string;
}): Promise<number> {
  await db
    .insert(schema.roleScreenAccess)
    .values({
      role: params.role,
      screenId: params.screenId,
      allowed: params.allowed,
      updatedBy: params.updatedBy,
    })
    .onConflictDoUpdate({
      target: [schema.roleScreenAccess.role, schema.roleScreenAccess.screenId],
      set: {
        allowed: params.allowed,
        updatedBy: params.updatedBy,
        updatedAt: new Date(),
      },
    });

  return bumpAccessPolicyVersion();
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

function normaliseRole(role: string | null | undefined): Role {
  return (ROLES as readonly string[]).includes(role ?? '') ? (role as Role) : 'guardian';
}
