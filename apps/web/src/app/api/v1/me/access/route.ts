import { NextResponse } from 'next/server';
import { auth } from '@najath/auth';
import { loadActorContext, resolveAccessPolicy } from '@najath/core';

/**
 * The policy the mobile app caches and enforces its UI against.
 *
 * A convenience for the client, not the security boundary — every other route
 * re-checks the same permissions server-side. Its job is to stop the app
 * offering affordances that would 403.
 */
export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });

  if (!session?.user) {
    return NextResponse.json({ error: { code: 'UNAUTHENTICATED' } }, { status: 401 });
  }

  const actor = await loadActorContext(session.user.id);

  // Authenticated but holding no role at all. A real state — a guardian invited
  // before their ward's `student_guardians` row was written — and one the app
  // renders as "no sections enabled yet" rather than as an error.
  if (!actor) {
    return NextResponse.json(
      { error: { code: 'NO_ROLES_ASSIGNED', message: 'This account has no roles yet.' } },
      { status: 403 },
    );
  }

  const policy = await resolveAccessPolicy(actor);

  return NextResponse.json(
    { data: policy, meta: { serverTime: new Date().toISOString() } },
    // The app decides freshness from `version` and its own max age, so no
    // intermediary should hold a copy of one user's policy.
    { headers: { 'Cache-Control': 'private, no-store' } },
  );
}
