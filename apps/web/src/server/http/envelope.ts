import { NextResponse } from 'next/server';
import { ERROR_STATUS, type ApiMeta, type ErrorCode, type FieldIssue } from '@najath/contracts';

/**
 * The two response shapes, in one place.
 *
 * Every route returns one of these — a bare `NextResponse.json(rows)` is a
 * review rejection, because the app's decoder unwraps `data` and would see the
 * array as a malformed envelope.
 */

/** Thrown by services; caught by the handler and turned into an error body. */
export class ApiError extends Error {
  constructor(
    readonly code: ErrorCode,
    message?: string,
    readonly options: {
      field?: string;
      details?: Record<string, unknown>;
      /** Overrides the code's default status. Rarely needed. */
      status?: number;
    } = {},
  ) {
    super(message ?? code);
    this.name = 'ApiError';
  }

  get status(): number {
    return this.options.status ?? ERROR_STATUS[this.code];
  }
}

/** Shorthand for the throw sites that read better as a helper. */
export const apiError = (
  code: ErrorCode,
  message?: string,
  options?: ConstructorParameters<typeof ApiError>[2],
) => new ApiError(code, message, options);

export function success<T>(data: T, meta: Partial<ApiMeta> = {}, init?: ResponseInit) {
  return NextResponse.json({ data, meta: { serverTime: new Date().toISOString(), ...meta } }, init);
}

export function failure(error: ApiError, headers?: HeadersInit) {
  return NextResponse.json(
    {
      error: {
        code: error.code,
        message: error.message,
        ...(error.options.field ? { field: error.options.field } : {}),
        ...(error.options.details ? { details: error.options.details } : {}),
      },
    },
    { status: error.status, headers },
  );
}

/** Zod issues → the `details.issues` shape the app's FailureMapper reads. */
export function validationError(issues: FieldIssue[]) {
  return new ApiError('VALIDATION_FAILED', 'Some fields need correcting', {
    field: issues[0]?.path,
    details: { issues },
  });
}
