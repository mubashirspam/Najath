import { defineConfig } from '@trigger.dev/sdk';

export default defineConfig({
  // TODO: replace with the real ref from https://cloud.trigger.dev
  // (or run: pnpm dlx trigger.dev@latest init -p <ref> --override-config)
  project: process.env.TRIGGER_PROJECT_REF ?? 'proj_najath_placeholder',
  runtime: 'node',
  logLevel: 'log',
  maxDuration: 300,
  dirs: ['./src/trigger'],
  retries: {
    enabledInDev: false,
    default: {
      maxAttempts: 3,
      minTimeoutInMs: 1_000,
      maxTimeoutInMs: 10_000,
      factor: 2,
      randomize: true,
    },
  },
});
