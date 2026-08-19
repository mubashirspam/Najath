import { resolveAccessPolicy } from '@najath/core';

import { handler } from '@/server/http/handler';

/**
 * The policy the mobile app caches and enforces its UI against.
 *
 * A convenience for the client, not the security boundary — every other route
 * re-checks the same permissions. Its job is to stop the app offering
 * affordances that would 403.
 */
export const GET = handler({
  run: ({ actor }) => resolveAccessPolicy(actor),
});
