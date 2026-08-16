/**
 * The canonical access-control registry.
 *
 * Single source of truth for three consumers:
 *   1. the admin console, which renders the role × screen matrix,
 *   2. the API, which resolves a principal's effective policy,
 *   3. the Flutter app, whose Dart mirror is emitted from here by
 *      `pnpm --filter @najath/contracts emit:dart` and checked in CI.
 *
 * Adding a role, resource or screen means editing these files and re-running
 * the emitter. Never edit the Dart file by hand.
 */
export * from './roles';
export * from './screens';

import type { Permission, Role } from './roles';
import type { ScreenId } from './screens';

/**
 * The effective policy handed to a client.
 *
 * `scopes` is what makes a permission actionable: `attendance:create` alone
 * does not say which batches. The server still re-checks every request — this
 * exists so the UI does not offer what would 403.
 */
export interface AccessPolicy {
  roles: Role[];
  activeRole: Role;
  permissions: Permission[];
  screens: ScreenId[];
  scopes: {
    departmentIds: string[];
    batchIds: string[];
    classSectionIds: string[];
    hostelIds: string[];
    /** Student ids reachable through student_guardians. */
    wardIds: string[];
  };
  version: number;
}
