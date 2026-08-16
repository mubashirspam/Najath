# M01 · Authentication & Session

**Phase P0.** Single sign-in across the console and the app, multi-role context
switching, device registration.

Everything else is blocked on this. It is also the module where a mistake is a
security incident rather than a bug — a wrong `student_guardians` resolution
shows one family another family's child.

## Surfaces

| Surface | Scope                                                                    |
| ------- | ------------------------------------------------------------------------ |
| API     | Email+password, phone OTP, refresh rotation, `/session`, device registry |
| Console | Staff login, role-scoped nav, academic-year context                      |
| App     | Splash → hydration → route resolution, segmented login, role switcher    |

## Tasks

### API

| ID           | Task                                                                 | Depends      | Acceptance                                                                           |
| ------------ | -------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------ |
| `M01-API-01` | `POST /auth/sign-in/email` — staff, optional OTP second factor       | `P0-DB-02`   | Wrong password and unknown email return the same code and timing                     |
| `M01-API-02` | `POST /auth/otp/request` — guardian phone                            | `P0-DB-02`   | 5 failures → 30-min lockout **on the phone number**, not the device                  |
| `M01-API-03` | `POST /auth/otp/verify` → session; resolves every ward on that phone | `M01-API-02` | A guardian on two students' `student_guardians` rows gets both wards                 |
| `M01-API-04` | `POST /auth/refresh` — rotating, reuse detection                     | `M01-API-01` | Replaying a used refresh token revokes the whole family and logs a security event    |
| `M01-API-05` | `POST /auth/devices` — FCM token, platform, app version              | `M01-API-01` | Re-registering the same token updates rather than duplicates                         |
| `M01-API-06` | `GET /session` → user, roles, scopes, wards, settings, min version   | `P0-API-03`  | A teacher-who-is-a-parent returns both role sets and both scope sets                 |
| `M01-API-07` | `POST /auth/sign-out` — revoke session + FCM token                   | `M01-API-05` | The device stops receiving push immediately                                          |
| `M01-API-08` | Guardian invite: SMS with app link, phone number is the credential   | `P0-DB-02`   | ⛔ **BLOCKED — Q17** (bulk SMS from the phone register, or in-person at the office?) |

### App

| ID           | Task                                                             | Depends         | Acceptance                                                                           |
| ------------ | ---------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------ |
| `M01-APP-01` | Splash → session hydration → route resolution                    | `P0-APP-06`     | Cold start on a deep link does not bounce to login before the token is read          |
| `M01-APP-02` | Login screen, segmented `Staff` / `Parent`                       | `M01-API-01,03` | Staff sees email+password; Parent sees phone+OTP. No student path exists.            |
| `M01-APP-03` | OTP entry with resend cooldown and lockout messaging             | `M01-API-02`    | Lockout says how long is left, not just "too many attempts"                          |
| `M01-APP-04` | Guardian onboarding — first login links every ward on that phone | `M01-API-03`    | One ward → skip the switcher entirely. Three wards → ward grid.                      |
| `M01-APP-05` | Role switcher bottom sheet, shown only when `roles.length > 1`   | `P0-APP-07`     | Switching rebuilds the router and clears feature providers, **without re-auth**      |
| `M01-APP-06` | `selectedWardProvider`, persisted to secure prefs                | `M01-APP-04`    | Switching wards never leaks a sibling's cached data — every provider is family-keyed |
| `M01-APP-07` | Biometric unlock toggle guarding the stored refresh token        | `M01-API-04`    | Disabling biometrics clears the stored token rather than leaving it unguarded        |
| `M01-APP-08` | Logout — clears the drift DB **for that user only**, revokes FCM | `M01-API-07`    | A shared device keeps the other user's cached data intact                            |
| `M01-APP-09` | Forgot password (staff)                                          | `M01-API-01`    | Reset link expires; used links fail closed                                           |

### Console

| ID           | Task                                                      | Depends      | Acceptance                                                      |
| ------------ | --------------------------------------------------------- | ------------ | --------------------------------------------------------------- |
| `M01-ADM-01` | Staff login + session                                     | `M01-API-01` | Cookie session, not bearer                                      |
| `M01-ADM-02` | Role-scoped navigation                                    | `P0-API-03`  | A `CANTEEN_MANAGER` cannot see or route to the students section |
| `M01-ADM-03` | Guardian account management — re-invite, revoke, transfer | `M01-API-08` | Transferring a ward audits both the old and new guardian        |

## Rules that bite

- **Students have no credentials.** There is no student sign-in path and
  `students.user_id` is never populated. Any request resolving student data for
  a non-staff user goes through `student_guardians`.
- **Role assignment is many-to-many.** A DEPT_HEAD is usually also a TEACHER; a
  TEACHER may be a PARENT of a student in the same college. Anything that assumes
  one role per user is wrong.
- Changing a primary guardian's phone number **revokes sessions on the old
  number** and re-invites the new one.
- App version gate: below `minSupportedAppVersion`, a blocking update screen.
  This is the only lever for retiring a broken sync client in the field.

## API surface

```
POST /api/v1/auth/sign-in/email
POST /api/v1/auth/otp/request        { phone }
POST /api/v1/auth/otp/verify         { phone, code }
POST /api/v1/auth/refresh
POST /api/v1/auth/devices            { fcmToken, platform, appVersion }
GET  /api/v1/session                 → { user, roles, scopes, wards[], settings }
POST /api/v1/auth/sign-out
```
