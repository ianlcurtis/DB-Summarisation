import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Get API URL from environment variable, Aspire service discovery, or default
const apiUrl = process.env.API_URL || 
               process.env.services__agent_api__https__0 || 
               process.env.services__agent_api__http__0 || 
               'http://localhost:5200'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: parseInt(process.env.PORT || '5173'),
    proxy: {
      '/api': {
        target: apiUrl,
        changeOrigin: true,
        secure: false
      },
      '/health': {
        target: apiUrl,
        changeOrigin: true,
        secure: false
      }
    }
  }
})
