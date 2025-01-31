import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

export const getSupabaseClient = () => {
  const dbUrl = Deno.env.get('DB_URL')
  const serviceKey = Deno.env.get('SERVICE_ROLE_KEY')

  if (!dbUrl || !serviceKey) {
    throw new Error('Missing database environment variables')
  }

  return createClient(dbUrl, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false
    }
  })
} 