import type { ZodError } from 'zod';
import type { FieldIssue } from '@najath/contracts';

/**
 * Zod's error shape → the flat `{ path, message }` list the app maps onto form
 * fields.
 *
 * A nested path joins with dots (`marks.0.status`) so the client can address a
 * row inside a batch submission, which is the case that actually needs it.
 */
export function zodIssues(error: ZodError): FieldIssue[] {
  return error.issues.map((issue) => ({
    path: issue.path.join('.') || '_',
    message: issue.message,
  }));
}
