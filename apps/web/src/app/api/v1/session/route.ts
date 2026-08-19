import { auth } from '@najath/auth';
import { isUnsupported, loadActorContext, resolveAccessPolicy, shellFor } from '@najath/core';

import { ApiError, failure, success } from '@/server/http/envelope';

/**
 * What the mobile shell is built from.
 *
 * One request answers: who is this, what roles do they hold, what can they
 * reach, and which experience should the app open. Called on every cold start,
 * so it must not fan out into a query per module.
 *
 * Not on the standard `handler` pipeline: the version gate has to answer before
 * the actor is resolved, and an unsupported build should get a clear
 * instruction rather than a 401 it cannot act on.
 */
export async function GET(request: Request) {
  try {
    const minSupported = process.env.MIN_SUPPORTED_APP_VERSION;
    const appVersion = request.headers.get('X-App-Version');

    if (minSupported && appVersion && isUnsupported(appVersion, minSupported)) {
      throw new ApiError(
        'APP_VERSION_UNSUPPORTED',
        'This version of the app is no longer supported',
        { details: { minSupportedVersion: minSupported } },
      );
    }

    const session = await auth.api.getSession({ headers: request.headers });
    if (!session?.user) {
      throw new ApiError('UNAUTHENTICATED', 'Sign in to continue');
    }

    const actor = await loadActorContext(session.user.id);
    if (!actor) {
      throw new ApiError('NO_ROLES_ASSIGNED', 'This account has no roles assigned yet');
    }

    const policy = await resolveAccessPolicy(actor);

    return success({
      user: {
        id: session.user.id,
        name: session.user.name,
        email: session.user.email,
        image: session.user.image ?? null,
      },
      roles: policy.roles,
      activeRole: policy.activeRole,
      shell: shellFor(actor),
      permissions: policy.permissions,
      screens: policy.screens,
      scopes: policy.scopes,
      policyVersion: policy.version,
      settings: {
        minSupportedAppVersion: minSupported ?? null,
      },
    });
  } catch (error) {
    if (error instanceof ApiError) return failure(error);
    console.error('[api] /session', error);
    return failure(new ApiError('INTERNAL_ERROR', 'Something went wrong'));
  }
}
