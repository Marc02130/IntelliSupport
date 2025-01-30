import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false
    }
  }
)

export async function enhanceContext(customerId: string) {
  // Get customer preferences and recent communications
  const { data: customer } = await supabaseClient
    .from('customer_preferences')
    .select(`
      preferred_style,
      communication_frequency,
      metadata,
      users!inner (
        full_name,
        organization_id
      )
    `)
    .eq('customer_id', customerId)
    .single()

  // Get recent communications
  const { data: communications } = await supabaseClient
    .from('communication_history')
    .select('*')
    .eq('customer_id', customerId)
    .order('sent_at', { ascending: false })
    .limit(5)

  return {
    preferences: customer,
    communications,
    metadata: {
      enhanced_at: new Date().toISOString(),
      source: 'preview-message-context'
    }
  }
} 