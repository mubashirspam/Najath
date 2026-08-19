import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { bearer, phoneNumber } from 'better-auth/plugins';
import { db, schema } from '@najath/db';

/**
 * Better Auth owns authentication only.
 *
 * **Authorization is not here.** Roles are many-to-many and scoped — a
 * DEPT_HEAD of one department who also teaches two batches — which no
 * `role` column on a user row can express. They live in `user_roles`, and
 * `@najath/core` resolves them. Putting a role here as well would create a
 * second source of truth that silently disagrees.
 */
export const auth = betterAuth({
  appName: 'Najath',
  secret: process.env.BETTER_AUTH_SECRET,
  baseURL: process.env.BETTER_AUTH_URL,

  database: drizzleAdapter(db, {
    provider: 'pg',
    // Our tables are plural and carry institution-specific columns, so the
    // mapping is explicit rather than inferred.
    schema: {
      user: schema.users,
      session: schema.sessions,
      account: schema.accounts,
      verification: schema.verifications,
    },
  }),

  /**
   * Staff sign in with email and password. Students have no credentials at all
   * — guardians are the only non-staff principal (spec §2.3) and they use the
   * phone OTP below.
   */
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false,
    minPasswordLength: 10,
  },

  session: {
    // 60 days, matching the mobile refresh window. The bearer token is what
    // the app holds; the console uses the cookie.
    expiresIn: 60 * 60 * 24 * 60,
    updateAge: 60 * 60 * 24,
    cookieCache: { enabled: true, maxAge: 5 * 60 },
  },

  user: {
    additionalFields: {
      phone: { type: 'string', required: false, input: false },
      locale: { type: 'string', required: false, defaultValue: 'en' },
      status: { type: 'string', required: false, defaultValue: 'active', input: false },
    },
  },

  plugins: [
    // Mobile clients send `Authorization: Bearer <token>` instead of cookies.
    bearer(),

    phoneNumber({
      sendOTP: async ({ phoneNumber: to, code }) => {
        // TODO(M01-API-02): wire MSG91. A real key sends a real SMS to a real
        // guardian, so local development logs instead.
        if (process.env.NODE_ENV !== 'production') {
          console.info(`[auth] OTP for ${to}: ${code}`);
          return;
        }
        throw new Error('MSG91 OTP transport not configured');
      },
      otpLength: 6,
      expiresIn: 5 * 60,
      // Five attempts then a 30-minute lockout — enforced on the phone number,
      // not the device, or a second handset defeats it.
      allowedAttempts: 5,
      signUpOnVerification: {
        // Guardians are provisioned by the office; this placeholder exists only
        // so Better Auth can satisfy its unique-email constraint. `AppUserDto`
        // hides it rather than showing it in a profile header.
        getTempEmail: (phone) => `${phone.replace(/\D/g, '')}@guardian.najath.local`,
        getTempName: (phone) => phone,
      },
    }),
  ],
});

export type Auth = typeof auth;
export type BetterAuthSession = typeof auth.$Infer.Session;
