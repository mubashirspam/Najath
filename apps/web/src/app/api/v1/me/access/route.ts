import { NextResponse } from 'next/server';
import { auth } from '@najath/auth';
import { resolveAccessPolicy } from '@najath/core';

/**
 * The policy the mobile app caches and enforces its UI against.
 *
 * This is a convenience for the client, not the security boundary — every other
 * route re-checks the same permissions server-side. Its job is to stop the app
 * offering affordances that would 403.
 */
export async function GET(request: Request) {
  const session = await auth.api.getSession({ headers: request.headers });

  if (!session?.user) {
    return NextResponse.json({ error: 'Not signed in' }, { status: 401 });
  }

  const policy = await resolveAccessPolicy({
    userId: session.user.id,
    role: (session.user as { role?: string }).role,
  });

  return NextResponse.json(policy, {
    headers: {
      // The app decides freshness from the version field and its own max-age,
      // so no intermediary should hold a copy of one user's policy.
      'Cache-Control': 'private, no-store',
    },
  });
}
