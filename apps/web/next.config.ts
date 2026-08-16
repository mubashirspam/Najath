import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Workspace packages ship raw TypeScript from src/, so Next has to compile them.
  transpilePackages: [
    "@najath/db",
    "@najath/contracts",
    "@najath/core",
    "@najath/auth",
    "@najath/ui",
  ],
  outputFileTracingRoot: new URL("../../", import.meta.url).pathname,
};

export default nextConfig;
