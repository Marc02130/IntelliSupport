import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { corsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../preview-message/rateLimit.ts'
import { enhanceContext } from '../preview-message/context.ts'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'

console.log('Environment:', {
  keys: Object.keys(Deno.env.toObject()),
  values: Deno.env.toObject()
})

// Debug environment variables
console.log('Environment variables:', {
  dbUrl: !!Deno.env.get('DB_URL'),
  serviceKey: !!Deno.env.get('SERVICE_ROLE_KEY')
})

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

interface PreviewRequest {
  message_text: string
  customer_id: string
  style?: string
  context_type?: string
}

const TIMEOUT_MS = 3000 // 3 second requirement
const GPT_TIMEOUT_MS = 2000 // Specific timeout for GPT

// Timeout wrapper
async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  const timeout = new Promise((_, reject) => {
    setTimeout(() => reject(new Error(`Operation timed out after ${ms}ms`)), ms)
  })
  return Promise.race([promise, timeout]) as Promise<T>
}

// Add request debugging
Deno.serve(async (req) => {
  console.log('Request:', {
    method: req.method,
    headers: Object.fromEntries(req.headers.entries())
  })

  const supabaseClient = createClient(
    Deno.env.get('DB_URL') ?? '',
    Deno.env.get('SERVICE_ROLE_KEY') ?? '',
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      },
      global: {
        headers: {
          Authorization: req.headers.get('Authorization') ?? ''
        }
      }
    }
  )

  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const startTime = Date.now()
    
    console.log('Starting request at:', startTime)
    if (req.method !== 'POST') {
      throw new Error('Method not allowed')
    }

    const { message_text, customer_id, style, context_type } = await req.json() as PreviewRequest

    // Run rate limit and context fetch in parallel
    const [rateLimitInfo, context] = await Promise.all([
      checkRateLimit(customer_id),
      enhanceContext(customer_id)
    ])

    if (!context.preferences) {
      throw new Error('Customer not found')
    }

    console.log('GPT start:', Date.now() - startTime, 'ms')
    const gptStart = Date.now()
    const completion = await withTimeout(openai.chat.completions.create({
      model: MODELS.GPT35,
      max_tokens: 300,
      temperature: 0.7,
      messages: [
        {
          role: "system",
          content: PROMPT_TEMPLATES.SYSTEM_CONTEXT
        },
        {
          role: "user",
          content: PROMPT_TEMPLATES.IMPROVEMENT.replace('{draft}', message_text)
        }
      ]
    }), GPT_TIMEOUT_MS)
    const gptEnd = Date.now()
    console.log('GPT end:', gptEnd - gptStart, 'ms')

    // Log asynchronously with correct timings
    supabaseClient.from('message_generation_logs').insert({
      customer_id,
      context_type: context_type || 'preview',
      input_context: {
        message_text,
        style,
        customer_context: context
      },
      generated_message: completion.choices[0].message.content,
      model_used: MODELS.GPT35,
      status: 'completed',
      success: true,
      performance_metrics: {
        total_time: Date.now() - startTime,
        context_time: Date.now() - startTime - (gptEnd - gptStart),
        gpt_time: gptEnd - gptStart
      }
    }).then(() => {
      console.log('Logged message generation')
    }).catch(error => {
      console.error('Failed to log message:', error)
    })

    const endTime = Date.now()
    console.log('Generation time:', endTime - startTime, 'ms')

    return new Response(
      JSON.stringify({
        preview: completion.choices[0].message.content,
        metadata: {
          model: MODELS.GPT35,
          customer_style: context.preferences.preferred_style,
          usage: completion.usage,
          rate_limit: rateLimitInfo,
          performance: {
            total_ms: Date.now() - startTime,
            context_ms: Date.now() - startTime - (gptEnd - gptStart),
            gpt_ms: gptEnd - gptStart
          }
        }
      }),
      { 
        headers: { 
          ...corsHeaders,
          'X-Generation-Time': `${Date.now() - startTime}ms`,
          'Cache-Control': 'private, no-cache, no-store, must-revalidate',
          'Expires': '0',
          'Pragma': 'no-cache',
          'Content-Type': 'application/json'
        } 
      }
    )

  } catch (error) {
    console.error('Error:', error)
    const status = error.message.includes('timed out') ? 408 :
                  error.message === 'Rate limit exceeded' ? 429 : 
                  500
    return new Response(
      JSON.stringify({ 
        error: error.message,
        elapsed_ms: Date.now() - startTime
      }),
      { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )
  }
}) 