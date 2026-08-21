import type { NextConfig } from 'next';

const nest =
  process.env.API_PROXY_TARGET?.replace(/\/$/, '') || 'http://127.0.0.1:3000';

const nextConfig: NextConfig = {
  output: 'standalone',
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${nest}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
