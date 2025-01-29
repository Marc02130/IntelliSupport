export const config = {
  // WebSocket endpoints
  ws: {
    preview: import.meta.env.DEV 
      ? 'ws://localhost:54321/functions/v1/preview-message'
      : `wss://${import.meta.env.VITE_SUPABASE_PROJECT_ID}.supabase.co/functions/v1/preview-message`
  },
  
  // HTTP endpoints
  api: {
    generate: '/functions/v1/generate-message',
    batch: '/functions/v1/batch-messages'
  }
} 