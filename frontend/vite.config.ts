import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // Load environment variables based on the current mode (development, production, etc.)
  const env = loadEnv(mode, process.cwd(), '')

  return {
    base: '/Ziva-finances/',
    plugins: [react()],
    server: {
      proxy: {
        '/api': {
          target: env.VITE_RENDER_URL || 'http://localhost:3001',
          changeOrigin: true,
          secure: false,
        }
      }
    }
  }
})
