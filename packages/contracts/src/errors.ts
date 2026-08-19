/**
 * The closed set of error codes.
 *
 * Shared by the API and the app: the server sends a code, the app maps it to a
 * localized string. **The server never sends user-facing Malayalam** — its
 * `message` is a developer-facing fallback.
 *
 * Codes are never renamed once shipped. An old build in the field still sends
 * and receives them, and `minSupportedAppVersion` is the only lever for
 * retiring one.
 */
export const ERROR_CODES = [
  // --- auth ---
  'UNAUTHENTICATED',
  'SESSION_EXPIRED',
  'INVALID_CREDENTIALS',
  'OTP_INVALID',
  'OTP_LOCKED_OUT',
  'APP_VERSION_UNSUPPORTED',

  // --- authorization ---
  'FORBIDDEN_ROLE',
  'FORBIDDEN_SCOPE',
  'NO_ROLES_ASSIGNED',

  // --- request ---
  'VALIDATION_FAILED',
  'NOT_FOUND',
  'RATE_LIMITED',
  'IDEMPOTENCY_KEY_REQUIRED',
  'IDEMPOTENCY_KEY_REUSED',

  // --- academic rules ---
  'ATTENDANCE_EDIT_WINDOW_CLOSED',
  'ATTENDANCE_HOLIDAY',
  'ATTENDANCE_ON_APPROVED_LEAVE',
  'HIFZ_RANGE_OVERLAP',
  'HIFZ_RANGE_INVALID',
  'HIFZ_BACKDATE_LIMIT',
  'HIFZ_BEYOND_FRONTIER',
  'DOURA_ROUND_ALREADY_OPEN',
  'MARKS_LOCKED_AFTER_VERIFY',
  'RESULT_NOT_PUBLISHED',
  'REPORT_IMMUTABLE_AFTER_PUBLISH',
  'LEAVE_OVERLAPS_EXISTING',
  'GUARDIAN_CANNOT_APPROVE_LEAVE',
  'STUDENT_NEEDS_PRIMARY_GUARDIAN',
  'BED_ALREADY_OCCUPIED',
  'ENROLLMENT_REQUIRED',

  // --- server ---
  'CONFLICT',
  'INTERNAL_ERROR',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/** One field-level problem, so a form can highlight the offending input. */
export interface FieldIssue {
  path: string;
  message: string;
}

export interface ApiErrorBody {
  code: ErrorCode;
  /** English, developer-facing. The app localizes from `code`. */
  message: string;
  /** Set when a single input is at fault. */
  field?: string;
  /** Whatever the client needs to act — never a stack trace. */
  details?: Record<string, unknown>;
}

export interface ApiErrorResponse {
  error: ApiErrorBody;
}

export interface ApiMeta {
  /** Always present. Clients compare it against their own clock before
   * trusting a device date. */
  serverTime: string;
  page?: number;
  pageSize?: number;
  total?: number;
  cursor?: string | null;
}

export interface ApiSuccessResponse<T> {
  data: T;
  meta: ApiMeta;
}

/** The HTTP status each code maps to. One place, so a route cannot disagree. */
export const ERROR_STATUS: Record<ErrorCode, number> = {
  UNAUTHENTICATED: 401,
  SESSION_EXPIRED: 401,
  INVALID_CREDENTIALS: 401,
  OTP_INVALID: 401,
  OTP_LOCKED_OUT: 429,
  APP_VERSION_UNSUPPORTED: 426,

  FORBIDDEN_ROLE: 403,
  FORBIDDEN_SCOPE: 403,
  NO_ROLES_ASSIGNED: 403,

  VALIDATION_FAILED: 422,
  NOT_FOUND: 404,
  RATE_LIMITED: 429,
  IDEMPOTENCY_KEY_REQUIRED: 400,
  IDEMPOTENCY_KEY_REUSED: 409,

  ATTENDANCE_EDIT_WINDOW_CLOSED: 403,
  ATTENDANCE_HOLIDAY: 409,
  ATTENDANCE_ON_APPROVED_LEAVE: 409,
  HIFZ_RANGE_OVERLAP: 409,
  HIFZ_RANGE_INVALID: 422,
  HIFZ_BACKDATE_LIMIT: 403,
  HIFZ_BEYOND_FRONTIER: 422,
  DOURA_ROUND_ALREADY_OPEN: 409,
  MARKS_LOCKED_AFTER_VERIFY: 403,
  RESULT_NOT_PUBLISHED: 403,
  REPORT_IMMUTABLE_AFTER_PUBLISH: 409,
  LEAVE_OVERLAPS_EXISTING: 409,
  GUARDIAN_CANNOT_APPROVE_LEAVE: 403,
  STUDENT_NEEDS_PRIMARY_GUARDIAN: 422,
  BED_ALREADY_OCCUPIED: 409,
  ENROLLMENT_REQUIRED: 422,

  CONFLICT: 409,
  INTERNAL_ERROR: 500,
};
