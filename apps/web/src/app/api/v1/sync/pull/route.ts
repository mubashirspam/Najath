import { z } from 'zod';
import { pullDelta, SYNC_ENTITIES } from '@najath/core';

import { handler } from '@/server/http/handler';

const input = z.object({
  /** Comma-separated, so the whole pull is one request rather than one per entity. */
  entities: z
    .string()
    .transform((value) =>
      value
        .split(',')
        .map((part) => part.trim())
        .filter(Boolean),
    )
    .pipe(z.array(z.enum(SYNC_ENTITIES)).min(1)),
  /** The cursor from the previous pull. Absent means "everything". */
  since: z.iso.datetime().optional(),
});

/**
 * Delta pull for the mobile mirror.
 *
 * Returns changed rows **and tombstones** per entity, plus the server's clock
 * to store as the next cursor. Scope is applied in the query — a teacher's
 * pull cannot return a student they do not teach.
 */
export const GET = handler({
  input,
  run: ({ input, actor }) =>
    pullDelta({
      actor,
      entities: input.entities,
      since: input.since ? new Date(input.since) : undefined,
    }),
});
