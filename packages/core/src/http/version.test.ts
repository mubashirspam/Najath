import assert from 'node:assert/strict';
import { test } from 'node:test';

import { compareVersions, isUnsupported } from './version';

test('compares numerically, not lexically', () => {
  // The bug this exists to prevent: lexically '1.10.0' sorts before '1.9.0',
  // so a string compare locks out the users who just updated.
  assert.equal(compareVersions('1.10.0', '1.9.0'), 1);
  assert.equal(isUnsupported('1.10.0', '1.9.0'), false);
  assert.equal(isUnsupported('1.9.0', '1.10.0'), true);
});

test('equal versions are supported', () => {
  assert.equal(isUnsupported('2.3.1', '2.3.1'), false);
});

test('missing segments count as zero', () => {
  assert.equal(compareVersions('2', '2.0.0'), 0);
  assert.equal(isUnsupported('2.0', '2.0.1'), true);
});

test('non-numeric segments degrade to zero rather than throwing', () => {
  // A build number like '1.2.0-beta.3' must not crash the gate; the worst
  // outcome is treating it as 1.2.0, which is the safe direction.
  assert.equal(isUnsupported('1.2.0-beta', '1.2.0'), false);
});
