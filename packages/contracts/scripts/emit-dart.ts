/**
 * Emits the Dart mirror of `src/access.ts` into the Flutter core package.
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

import { ROLES, RESOURCES, SCREENS, type Role } from '../src/access.ts';

const OUT = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../../apps/mobile/packages/core/lib/src/access/screen_registry.dart',
);

const dartString = (s: string) => `'${s.replace(/'/g, "\\'")}'`;

const constName = (id: string) => id.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());

const roleEnum = (role: Role) => `AppRole.${role}`;

const lines: string[] = [];

lines.push(
  '// GENERATED FILE — DO NOT EDIT.',
  '//',
  '// Emitted from packages/contracts/src/access.ts by',
  '//   pnpm --filter @najath/contracts emit:dart',
  '// CI re-runs the emitter and fails if this file is out of date.',
  '',
  "import 'permission.dart';",
  '',
  '/// Roles a principal can hold. Mirrors `ROLES` in the contracts package.',
  'enum AppRole {',
  ...ROLES.map((r) => `  ${r},`),
  '}',
  '',
  '/// Parses a role name from the wire, falling back to the least privileged.',
  'AppRole appRoleFromName(String? name) {',
  '  return AppRole.values.firstWhere(',
  '    (r) => r.name == name,',
  '    orElse: () => AppRole.guardian,',
  '  );',
  '}',
  '',
  '/// Stable screen identifiers. These strings are stored in the database, so',
  '/// they are never renamed once shipped.',
  'class ScreenId {',
  '  ScreenId._();',
  '',
  ...SCREENS.map((s) => `  static const String ${constName(s.id)} = ${dartString(s.id)};`),
  '}',
  '',
  '/// A screen the admin console can grant or revoke per role.',
  'class ScreenDefinition {',
  '  const ScreenDefinition({',
  '    required this.id,',
  '    required this.label,',
  '    required this.requires,',
  '    required this.isNavDestination,',
  '    required this.defaultRoles,',
  '  });',
  '',
  '  final String id;',
  '  final String label;',
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
  lines.push(
    '    ScreenDefinition(',
    `      id: ScreenId.${constName(s.id)},`,
    `      label: ${dartString(s.label)},`,
    `      requires: Permission(${dartString(resource!)}, ${dartString(action!)}),`,
    `      isNavDestination: ${s.isNavDestination},`,
    `      defaultRoles: {${(s.defaultRoles as readonly Role[]).map(roleEnum).join(', ')}},`,
    '    ),',
  );
}

lines.push(
  '  ];',
  '',
  '  /// Top-level navigation destinations, in the order they should appear.',
  '  static List<ScreenDefinition> get navDestinations =>',
  '      all.where((s) => s.isNavDestination).toList();',
  '',
  '  static ScreenDefinition? byId(String id) {',
  '    for (final screen in all) {',
  '      if (screen.id == id) return screen;',
  '    }',
  '    return null;',
  '  }',
  '',
  '  /// Screens a role holds before any admin customisation. Used as the',
  '  /// fallback when the app has never managed to fetch a policy.',
  '  static Set<String> defaultScreensFor(AppRole role) => {',
  '    for (final screen in all)',
  '      if (screen.defaultRoles.contains(role)) screen.id,',
  '  };',
  '}',
  '',
  '/// Every `resource:action` pair the API recognises.',
  'class Resources {',
  '  Resources._();',
  '',
);

for (const [resource, actions] of Object.entries(RESOURCES)) {
  lines.push(
    `  static const String ${resource} = ${dartString(resource)};`,
    `  static const List<String> ${resource}Actions = [${(actions as readonly string[])
      .map(dartString)
      .join(', ')}];`,
  );
}

lines.push(
  '',
  '  static const Map<String, List<String>> all = {',
  ...Object.keys(RESOURCES).map((r) => `    ${r}: ${r}Actions,`),
  '  };',
  '}',
  '',
);

writeFileSync(OUT, lines.join('\n'));
console.info(`emitted ${OUT}`);
