import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { checkRateLimit } from '../preview-message/rateLimit.ts'
import { enhanceContext } from '../preview-message/context.ts'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'
import { connect } from 'https://deno.land/x/redis@v0.29.0/mod.ts'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Environment variables:', {
  openaiKey: !!Deno.env.get('OPENAI_API_KEY'),
  openaiKeyLength: Deno.env.get('OPENAI_API_KEY')?.length
})

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

let redis: any = null

// Initialize Redis lazily
async function getRedisClient() {
  if (!redis) {
    try {
      redis = await connect({
        hostname: Deno.env.get('REDIS_HOST') || 'localhost',
        port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
        password: Deno.env.get('REDIS_PASSWORD'),
      })
    } catch (error) {
      console.error('Redis connection failed:', error)
      // Continue without Redis
    }
  }
  return redis
}

async function getCachedPreview(text: string, customerId: string, style?: string): Promise<string | null> {
  try {
    const client = await getRedisClient()
    if (!client) return null
    
    const key = `preview:${customerId}:${style}:${text}`
    return await client.get(key)
  } catch (error) {
    console.error('Cache get error:', error)
    return null
  }
}

async function setCachedPreview(text: string, customerId: string, preview: string, style?: string) {
  const key = `preview:${customerId}:${style}:${text}`
  await redis.set(key, preview, { ex: 60 * 60 * 24 }) // 24 hour cache
}

interface BatchRequest {
  ticket_ids: string[]
  template_id: string
  batch_id?: string
}

interface BatchMessage {
  message_text: string
  customer_id: string
  style?: string
}

interface BatchMetrics {
  total_messages: number
  completed: number
  failed: number
  start_time: number
  durations: number[]
  errors: Array<{
    message: string
    type: string
    messageId: string
    timestamp: string
  }>
}

const supabaseClient = createClient(
  Deno.env.get('SUPABASE_API_URL') ?? 'http://127.0.0.1:54321',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''
)

// Add debugging for the connection
console.log('Supabase client config:', {
  url: Deno.env.get('SUPABASE_API_URL') ?? 'http://127.0.0.1:54321',
  hasServiceKey: !!(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY'))
})

// Add after client initialization
try {
  // Test the connection
  const { data, error } = await supabaseClient
    .from('tickets')
    .select('id')
    .limit(1)

  if (error) {
    console.error('Database connection test failed:', error)
  } else {
    console.log('Database connection successful')
  }
} catch (error) {
  console.error('Failed to connect to database:', error)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { ticket_ids, template_id } = await req.json() as BatchRequest
    const userId = req.headers.get('authorization')?.split(' ')[1]

    if (!ticket_ids || !Array.isArray(ticket_ids) || ticket_ids.length === 0) {
      throw new Error('Invalid request: ticket_ids array is required and must not be empty')
    }

    if (!template_id) {
      throw new Error('Invalid request: template_id is required')
    }

    // Log the received payload for debugging
    console.log('Processing batch:', { ticket_ids, template_id })

    // Generate a batch ID if not provided
    const batch_id = crypto.randomUUID()

    // Convert tickets to messages
    const messages = await Promise.all(ticket_ids.map(async (ticketId) => {
      try {
        // Get ticket details from database
        const { data: ticket, error } = await supabaseClient
          .from('tickets')
          .select('*')
          .eq('id', ticketId)
          .single()

        if (error) throw error
        
        return {
          ticket_id: ticketId,
          message_text: '', // Will be generated from template
          customer_id: ticket.customer_id,
          style: 'default'
        }
      } catch (error) {
        console.error(`Error processing ticket ${ticketId}:`, error)
        throw error
      }
    }))

    return new Response(JSON.stringify({ 
      batch_id,
      message: 'Batch processing started',
      ticket_count: ticket_ids.length
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Error processing request:', error)
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}) 