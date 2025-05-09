import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,

  // ← add this:
  output: "export",
  // (optional) if you want
  // trailingSlash: true,
};

export default nextConfig;
