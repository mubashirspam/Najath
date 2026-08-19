/**
 * Semantic-version comparison for the app version gate.
 *
 * Lives in core so the console, the API and any job agree. String comparison is
 * wrong here and the bug is silent: `'1.10.0' < '1.9.0'` lexically, which would
 * lock out the newer build — exactly the users who updated.
 */
export function compareVersions(left: string, right: string): number {
  const parse = (value: string) => value.split('.').map((part) => Number.parseInt(part, 10) || 0);

  const a = parse(left);
  const b = parse(right);

  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] ?? 0;
    const y = b[i] ?? 0;
    if (x !== y) return x < y ? -1 : 1;
  }
  return 0;
}

/** True when [version] is below [minimum] and the app should be blocked. */
export function isUnsupported(version: string, minimum: string): boolean {
  return compareVersions(version, minimum) < 0;
}
