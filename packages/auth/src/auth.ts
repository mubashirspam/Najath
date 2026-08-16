import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { admin as adminPlugin, bearer, phoneNumber } from 'better-auth/plugins';
import { db } from '@najath/db';
import { ac, roles } from './permissions';

export const auth = betterAuth({
  appName: 'Najath Quran Academy',
  database: drizzleAdapter(db, { provider: 'pg', usePlural: false }),
  secret: process.env.BETTER_AUTH_SECRET,
  baseURL: process.env.BETTER_AUTH_URL,

  /**
   * Staff sign in with email + password. Students have no credentials at all —
   * per the SRS, guardians are the only non-staff principal, and they
   * authenticate by phone OTP via the phoneNumber plugin below.
   */
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false,
    minPasswordLength: 10,
  },

  session: {
    expiresIn: 60 * 60 * 24 * 30,
    updateAge: 60 * 60 * 24,
    cookieCache: { enabled: true, maxAge: 5 * 60 },
  },

  user: {
    additionalFields: {
      role: { type: 'string', required: false, defaultValue: 'guardian', input: false },
    },
  },

  plugins: [
    // Mobile clients send `Authorization: Bearer <token>` instead of cookies.
    bearer(),

    phoneNumber({
      sendOTP: async ({ phoneNumber: to, code }) => {
        // TODO: wire MSG91 (MSG91_AUTH_KEY) — see packages/core.
        if (process.env.NODE_ENV !== 'production') {
          console.info(`[auth] OTP for ${to}: ${code}`);
          return;
        }
        throw new Error('MSG91 OTP transport not configured');
      },
      otpLength: 6,
      expiresIn: 5 * 60,
      allowedAttempts: 3,
      signUpOnVerification: {
        // Guardians are provisioned by staff; this placeholder exists only so
        // Better Auth can satisfy its unique-email constraint.
        getTempEmail: (phone) => `${phone.replace(/\D/g, '')}@guardian.najath.local`,
        getTempName: (phone) => phone,
      },
    }),

    adminPlugin({
      ac,
      roles,
      defaultRole: 'guardian',
      adminRoles: ['admin'],
    }),
  ],
});

export type Auth = typeof auth;
export type Session = typeof auth.$Infer.Session;
