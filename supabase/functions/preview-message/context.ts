import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

let supabaseClient: ReturnType<typeof createClient> | null = null
let clientInitPromise: Promise<ReturnType<typeof createClient>> | null = null

export const getSupabaseClient = () => {
  if (clientInitPromise) {
    return clientInitPromise
  }

  clientInitPromise = (async () => {
    if (supabaseClient) {
      return supabaseClient
    }

    const dbUrl = Deno.env.get('DB_URL')
    const serviceKey = Deno.env.get('SERVICE_ROLE_KEY')

    if (!dbUrl || !serviceKey) {
      throw new Error('Missing database environment variables')
    }

    supabaseClient = createClient(dbUrl, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
      },
      db: {
        schema: 'public'
      }
    })

    // Prime the connection
    await supabaseClient.from('customer_preferences').select('count').limit(1)

    return supabaseClient
  })()

  return clientInitPromise
}

// Initialize client immediately
const clientPromise = getSupabaseClient()

// Add caching for customer preferences
const PREFERENCES_CACHE: Record<string, {
  data: any,
  timestamp: number
}> = {}
const CACHE_TTL = 5 * 60 * 1000 // 5 minutes

export async function enhanceContext(customerId: string) {
  // Check cache first
  const cached = PREFERENCES_CACHE[customerId]
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return {
      preferences: cached.data,
      communications: [], 
      metadata: {
        enhanced_at: new Date().toISOString(),
        source: 'cache'
      }
    }
  }

  const metrics: Record<string, number> = {}
  const startTime = Date.now()

  const [client, validationResult] = await Promise.all([
    getSupabaseClient(),
    (async () => {
      const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      if (!UUID_REGEX.test(customerId)) {
        throw new Error('Invalid customer ID format')
      }
    })()
  ])

  metrics.init_time = Date.now() - startTime

  // First verify the user exists and is a customer
  const { data: user, error: userError } = await client
    .from('users')
    .select('id, role, organization_id')
    .eq('id', customerId)
    .single()

  if (!user || user.role !== 'customer') {
    throw new Error('Customer not found')
  }

  // Then get their preferences and history
  const dbStartTime = Date.now()
  const queries = [
    client
      .from('customer_preferences')
      .select('preferred_style,id')
      .eq('customer_id', customerId)
      .limit(1)
      .maybeSingle(), // Use maybeSingle() since preferences are optional
    client
      .from('communication_history')
      .select('message_text,sent_at')
      .eq('customer_id', customerId)
      .gt('sent_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
      .order('sent_at', { ascending: false })
      .limit(3)
  ]

  const networkStartTime = Date.now()
  const [preferences, history] = await Promise.all(queries)
  metrics.network_time = Date.now() - networkStartTime
  metrics.db_time = Date.now() - dbStartTime

  // Track data processing time
  const processStartTime = Date.now()
  metrics.process_time = Date.now() - processStartTime

  metrics.total_time = Date.now() - startTime
  metrics.overhead = metrics.total_time - (
    metrics.init_time +
    metrics.network_time +
    metrics.process_time
  )

  console.log('Context retrieval metrics:', {
    ...metrics,
    breakdown: {
      init: `${metrics.init_time}ms (${((metrics.init_time/metrics.total_time)*100).toFixed(1)}%)`,
      network: `${metrics.network_time}ms (${((metrics.network_time/metrics.total_time)*100).toFixed(1)}%)`,
      processing: `${metrics.process_time}ms (${((metrics.process_time/metrics.total_time)*100).toFixed(1)}%)`,
      overhead: `${metrics.overhead}ms (${((metrics.overhead/metrics.total_time)*100).toFixed(1)}%)`
    }
  })

  // Update cache with preferences (or empty object if none found)
  PREFERENCES_CACHE[customerId] = {
    data: preferences.data || {},
    timestamp: Date.now()
  }

  return {
    preferences: preferences.data || {},
    communications: history.data || [],
    metadata: {
      enhanced_at: new Date().toISOString(),
      source: 'preview-message-context',
      metrics
    }
  }
} 