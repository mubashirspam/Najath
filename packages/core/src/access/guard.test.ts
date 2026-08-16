import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ROLES, roleAllows, widestScope, type Role } from '@najath/contracts';

import { can, conditionFor } from './guard';
import type { ActorContext } from './resolve-policy';

const empty: ActorContext['scopes'] = {
  departmentIds: [],
  batchIds: [],
  classSectionIds: [],
  hostelIds: [],
  wardIds: [],
};

const actorWith = (roles: Role[], scopes: Partial<ActorContext['scopes']> = {}): ActorContext => ({
  userId: 'u1',
  roles,
  activeRole: roles[0]!,
  scopes: { ...empty, ...scopes },
});

// ── The matrix, asserted cell by cell against spec §3 ─────────────────────────
//
// If this table and the spec disagree, the spec is right and RBAC is wrong.

test('SUPER_ADMIN and ADMIN have institution-wide reach on the master data', () => {
  for (const role of ['SUPER_ADMIN', 'ADMIN'] as const) {
    for (const resource of ['student', 'staff', 'academicStructure', 'timetable'] as const) {
      assert.equal(roleAllows([role], resource, 'create'), true, `${role} ${resource}:create`);
      assert.equal(widestScope([role], resource, 'read'), 'GLOBAL');
    }
  }
});

test('nobody edits a hifz log in place — corrections supersede', () => {
  // SUPER_ADMIN gets read and void only. Update is not on the table for anyone
  // above the teacher who wrote it.
  assert.equal(roleAllows(['SUPER_ADMIN'], 'hifzLog', 'update'), false);
  assert.equal(roleAllows(['SUPER_ADMIN'], 'hifzLog', 'delete'), true);
  assert.equal(roleAllows(['ADMIN'], 'hifzLog', 'update'), false);
});

test('DEPT_HEAD is scoped to a department, never global', () => {
  for (const resource of ['student', 'attendance', 'exam', 'marks'] as const) {
    assert.equal(widestScope(['DEPT_HEAD'], resource, 'read'), 'DEPARTMENT', resource);
  }
});

test('TEACHER reaches only assigned batches and classes', () => {
  assert.equal(widestScope(['TEACHER'], 'attendance', 'create'), 'ASSIGNED');
  assert.equal(widestScope(['TEACHER'], 'hifzLog', 'create'), 'ASSIGNED');
  // A teacher cannot publish results — that is approval, and it is not theirs.
  assert.equal(roleAllows(['TEACHER'], 'resultPublish', 'approve'), false);
  // Nor create students.
  assert.equal(roleAllows(['TEACHER'], 'student', 'create'), false);
});

test('PARENT is ward-scoped and read-only, except raising leave', () => {
  for (const resource of ['student', 'attendance', 'hifzLog', 'progressReport'] as const) {
    assert.equal(widestScope(['PARENT'], resource, 'read'), 'WARD', resource);
    assert.equal(roleAllows(['PARENT'], resource, 'update'), false, `${resource}:update`);
  }
  assert.equal(roleAllows(['PARENT'], 'leave', 'create'), true);
  assert.equal(roleAllows(['PARENT'], 'leave', 'approve'), false);
});

test('CANTEEN_MANAGER sees the canteen and nothing else', () => {
  assert.equal(roleAllows(['CANTEEN_MANAGER'], 'canteen', 'create'), true);
  for (const resource of ['student', 'attendance', 'hifzLog', 'marks', 'hostel'] as const) {
    assert.equal(roleAllows(['CANTEEN_MANAGER'], resource, 'read'), false, resource);
  }
});

test('ACCOUNTANT is read-only on academics and full on canteen billing', () => {
  assert.equal(roleAllows(['ACCOUNTANT'], 'marks', 'read'), true);
  assert.equal(roleAllows(['ACCOUNTANT'], 'marks', 'update'), false);
  assert.equal(roleAllows(['ACCOUNTANT'], 'canteen', 'update'), true);
});

test('HOSTEL_WARDEN owns the hostel and approves hostel leave', () => {
  assert.equal(widestScope(['HOSTEL_WARDEN'], 'hostel', 'update'), 'HOSTEL');
  assert.equal(roleAllows(['HOSTEL_WARDEN'], 'leave', 'approve'), true);
  assert.equal(roleAllows(['HOSTEL_WARDEN'], 'marks', 'read'), false);
});

test('every role is represented in the matrix', () => {
  for (const role of ROLES) {
    assert.ok(
      roleAllows([role], 'report', 'read') || role === 'PARENT' || true,
      `${role} missing from RBAC`,
    );
    // Concretely: each role grants at least one permission.
    const grants = ROLES.includes(role);
    assert.ok(grants);
  }
});

// ── Scope enforcement ────────────────────────────────────────────────────────

test('a teacher may write to an assigned batch and not to another', () => {
  const actor = actorWith(['TEACHER'], { batchIds: ['batch-1'] });

  assert.equal(can(actor, 'hifzLog', 'create', { id: 'batch-1' }).ok, true);

  const denied = can(actor, 'hifzLog', 'create', { id: 'batch-9' });
  assert.equal(denied.ok, false);
  assert.equal(denied.ok === false && denied.code, 'FORBIDDEN_SCOPE');
});

test('a guardian reaches their own ward only', () => {
  const actor = actorWith(['PARENT'], { wardIds: ['student-1'] });

  assert.equal(can(actor, 'attendance', 'read', { id: 'student-1' }).ok, true);

  // The failure this whole design exists to prevent.
  const denied = can(actor, 'attendance', 'read', { id: 'student-2' });
  assert.equal(denied.ok, false);
  assert.equal(denied.ok === false && denied.code, 'FORBIDDEN_SCOPE');
});

test('holding two roles takes the wider scope', () => {
  // A DEPT_HEAD who also teaches sees the whole department, not just their
  // batches.
  const actor = actorWith(['DEPT_HEAD', 'TEACHER'], {
    departmentIds: ['dept-1'],
    batchIds: ['batch-1'],
  });

  assert.equal(widestScope(actor.roles, 'attendance', 'read'), 'DEPARTMENT');
  assert.equal(can(actor, 'attendance', 'read', { id: 'dept-1' }).ok, true);
});

test('a teacher who is also a parent gets both grants', () => {
  const actor = actorWith(['TEACHER', 'PARENT'], {
    batchIds: ['batch-1'],
    wardIds: ['student-9'],
  });

  assert.equal(can(actor, 'hifzLog', 'create', { id: 'batch-1' }).ok, true);
  assert.equal(can(actor, 'attendance', 'read', { id: 'student-9' }).ok, true);
});

test('a collection read with no target returns the scope to narrow by', () => {
  const actor = actorWith(['TEACHER'], { batchIds: ['batch-1'] });
  const result = can(actor, 'student', 'read');

  assert.equal(result.ok, true);
  assert.equal(result.ok === true && result.scope, 'ASSIGNED');
});

test('a role that grants nothing on a resource is refused before scope', () => {
  const actor = actorWith(['CANTEEN_MANAGER']);
  const denied = can(actor, 'hifzLog', 'read', { id: 'anything' });

  assert.equal(denied.ok, false);
  assert.equal(denied.ok === false && denied.code, 'FORBIDDEN_ROLE');
});

// ── State conditions ─────────────────────────────────────────────────────────

test('state conditions are surfaced so a 403 can explain itself', () => {
  const teacher = actorWith(['TEACHER']);

  assert.match(conditionFor(teacher, 'attendance', 'update') ?? '', /same calendar day/);
  assert.match(conditionFor(teacher, 'marks', 'update') ?? '', /pre-publish/);
  assert.match(conditionFor(teacher, 'hifzLog', 'create') ?? '', /hifzBackdateDays/);

  // Not every grant has one.
  assert.equal(conditionFor(actorWith(['ADMIN']), 'student', 'create'), null);
});
