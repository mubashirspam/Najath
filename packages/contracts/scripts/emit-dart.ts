/**
 * Emits the Dart mirror of `src/access/` into the Flutter core package.
 *
 * The output is committed (not a `.g.dart`, which is gitignored) so
 * `flutter analyze` works on a fresh clone, and CI re-runs this and fails on a
 * diff — the same guard the Drizzle migrations use.
 *
 *   pnpm --filter @najath/contracts emit:dart
 */
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import { ROLES, RESOURCES, SCOPE_TYPES, type Role } from '../src/access/roles.ts';
import { SCREENS, SHELLS, shellForRole } from '../src/access/screens.ts';

const OUT = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../../apps/mobile/packages/core/lib/src/access/screen_registry.dart',
);

const str = (s: string) => `'${s.replace(/'/g, "\\'")}'`;
/** SCREAMING_SNAKE or snake_case → lowerCamelCase, for Dart identifiers. */
const camel = (id: string) =>
  id.toLowerCase().replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase());

const L: string[] = [];

L.push(
  '// GENERATED FILE — DO NOT EDIT.',
  '//',
  '// Emitted from packages/contracts/src/access/ by',
  '//   pnpm --filter @najath/contracts emit:dart',
  '// CI re-runs the emitter and fails if this file is out of date.',
  '',
  "import 'permission.dart';",
  '',
  '/// Roles a principal can hold. A user may hold several — a DEPT_HEAD is',
  '/// usually also a TEACHER, and a TEACHER may be a PARENT of a student in the',
  '/// same college.',
  'enum AppRole {',
  ...ROLES.map((r) => `  ${camel(r)}(${str(r)}),`),
  '  ;',
  '',
  '  const AppRole(this.wire);',
  '',
  '  /// The value the API sends, e.g. `SUPER_ADMIN`.',
  '  final String wire;',
  '}',
  '',
  '/// Parses a role from the wire, falling back to the least privileged.',
  'AppRole appRoleFromWire(String? wire) {',
  '  return AppRole.values.firstWhere(',
  '    (r) => r.wire == wire,',
  '    orElse: () => AppRole.parent,',
  '  );',
  '}',
  '',
  '/// The mobile app is one binary with three shells, resolved from the active',
  '/// role.',
  'enum AppShell {',
  ...SHELLS.map((s) => `  ${camel(s)},`),
  '}',
  '',
  'AppShell shellForRole(AppRole role) {',
  '  switch (role) {',
);

for (const role of ROLES) {
  L.push(
    `    case AppRole.${camel(role)}:`,
    `      return AppShell.${camel(shellForRole(role as Role))};`,
  );
}

L.push(
  '  }',
  '}',
  '',
  '/// How far a grant reaches. Mirrors `SCOPE_TYPES`.',
  'enum ScopeType {',
  ...SCOPE_TYPES.map((s) => `  ${camel(s)}(${str(s)}),`),
  '  ;',
  '',
  '  const ScopeType(this.wire);',
  '  final String wire;',
  '}',
  '',
  '/// Stable screen identifiers. Stored in the database, never renamed.',
  'class ScreenId {',
  '  ScreenId._();',
  '',
  ...SCREENS.map((s) => `  static const String ${camel(s.id)} = ${str(s.id)};`),
  '}',
  '',
  '/// A screen the admin console can grant or revoke per role.',
  'class ScreenDefinition {',
  '  const ScreenDefinition({',
  '    required this.id,',
  '    required this.label,',
  '    required this.shell,',
  '    required this.requires,',
  '    required this.isNavDestination,',
  '    required this.defaultRoles,',
  '  });',
  '',
  '  final String id;',
  '  final String label;',
  '  final AppShell shell;',
  '',
  '  /// The permission this screen cannot function without.',
  '  final Permission requires;',
  '',
  '  final bool isNavDestination;',
  '  final Set<AppRole> defaultRoles;',
  '}',
  '',
  'class ScreenRegistry {',
  '  ScreenRegistry._();',
  '',
  '  static const List<ScreenDefinition> all = [',
);

for (const s of SCREENS) {
  const [resource, action] = s.requires.split(':');
  L.push(
    '    ScreenDefinition(',
    `      id: ScreenId.${camel(s.id)},`,
    `      label: ${str(s.label)},`,
    `      shell: AppShell.${camel(s.shell)},`,
    `      requires: Permission(${str(resource!)}, ${str(action!)}),`,
    `      isNavDestination: ${s.isNavDestination},`,
    `      defaultRoles: {${(s.defaultRoles as readonly Role[])
      .map((r) => `AppRole.${camel(r)}`)
      .join(', ')}},`,
    '    ),',
  );
}

L.push(
  '  ];',
  '',
  '  static ScreenDefinition? byId(String id) {',
  '    for (final screen in all) {',
  '      if (screen.id == id) return screen;',
  '    }',
  '    return null;',
  '  }',
  '',
  '  /// Screens belonging to one shell, in declaration order.',
  '  static List<ScreenDefinition> forShell(AppShell shell) =>',
  '      all.where((s) => s.shell == shell).toList();',
  '',
  '  /// Top-level tabs of one shell.',
  '  static List<ScreenDefinition> navDestinations(AppShell shell) =>',
  '      all.where((s) => s.shell == shell && s.isNavDestination).toList();',
  '',
  '  /// Screens a role holds before any admin customisation. The fallback when',
  '  /// the app has never managed to fetch a policy.',
  '  static Set<String> defaultScreensFor(AppRole role) => {',
  '    for (final screen in all)',
  '      if (screen.defaultRoles.contains(role)) screen.id,',
  '  };',
  '}',
  '',
  '/// Every resource the API recognises, and the actions it supports.',
  'class Resources {',
  '  Resources._();',
  '',
);

for (const [resource, actions] of Object.entries(RESOURCES)) {
  L.push(
    `  static const String ${resource} = ${str(resource)};`,
    `  static const List<String> ${resource}Actions = [${(actions as readonly string[])
      .map(str)
      .join(', ')}];`,
  );
}

L.push(
  '',
  '  static const Map<String, List<String>> all = {',
  ...Object.keys(RESOURCES).map((r) => `    ${r}: ${r}Actions,`),
  '  };',
  '}',
  '',
);

writeFileSync(OUT, L.join('\n'));
console.info(`emitted ${OUT}`);
