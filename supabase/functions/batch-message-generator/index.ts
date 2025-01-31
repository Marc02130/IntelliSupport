import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { corsHeaders } from '../_shared/cors.ts'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'
import { enhanceContext, getSupabaseClient } from '../preview-message/context.ts'
import { checkBatchLimit } from './rateLimit.ts'

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

console.log('Environment:', {
  openaiKey: !!Deno.env.get('OPENAI_API_KEY'),
  dbUrl: !!Deno.env.get('DB_URL'),
  serviceKey: !!Deno.env.get('SERVICE_ROLE_KEY')
})

interface BatchRequest {
  messages: Array<{
    message_text: string
    customer_id: string
    style?: string
  }>
  batch_id: string
}

const BATCH_SIZE = 10 // Process in chunks of 10
const MAX_MESSAGES = 100 // Max messages per batch
const supabaseClient = getSupabaseClient()

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const startTime = Date.now()
    const { messages, batch_id } = await req.json() as BatchRequest
    const userId = req.headers.get('x-user-id')
    
    if (!userId) {
      throw new Error('Missing user ID')
    }
    
    // Check rate limits
    const rateLimitInfo = await checkBatchLimit(userId)
    if (!rateLimitInfo.allowed) {
      throw new Error('Rate limit exceeded')
    }
    
    // Validate batch size
    if (messages.length > MAX_MESSAGES) {
      throw new Error(`Batch size exceeds limit of ${MAX_MESSAGES}`)
    }

    // Create batch job record
    await supabaseClient.from('batch_jobs').insert({
      id: batch_id,
      total_messages: messages.length,
      user_id: userId,
      status: 'processing'
    })

    // Process in chunks
    const chunks = []
    for (let i = 0; i < messages.length; i += BATCH_SIZE) {
      chunks.push(messages.slice(i, i + BATCH_SIZE))
    }

    let processed = 0
    const results = []
    const errors = []

    for (const chunk of chunks) {
      const chunkResults = await Promise.all(chunk.map(async (message) => {
        try {
          // Get context and generate message in parallel
          const [context, completion] = await Promise.all([
            enhanceContext(message.customer_id),
            openai.chat.completions.create({
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
                  content: PROMPT_TEMPLATES.IMPROVEMENT.replace('{draft}', message.message_text)
                }
              ]
            })
          ])

          processed++
          await supabaseClient.from('batch_jobs').update({
            processed_count: processed
          }).eq('id', batch_id)

          return {
            success: true,
            customer_id: message.customer_id,
            generated_text: completion.choices[0].message.content
          }
        } catch (error) {
          errors.push({
            customer_id: message.customer_id,
            error: error.message
          })
          return {
            success: false,
            customer_id: message.customer_id,
            error: error.message
          }
        }
      }))

      results.push(...chunkResults)
    }

    // Update completion status
    await supabaseClient.from('batch_jobs').update({
      status: errors.length ? 'completed_with_errors' : 'completed',
      completed_at: new Date().toISOString(),
      results,
      errors: errors.length ? errors : null
    }).eq('id', batch_id)

    return new Response(
      JSON.stringify({
        batch_id,
        total: messages.length,
        processed,
        results,
        errors,
        rate_limit: rateLimitInfo,
        duration_ms: Date.now() - startTime
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )

  } catch (error) {
    // Update error status
    if (req.batch_id) {
      await supabaseClient.from('batch_jobs').update({
        status: 'failed',
        error: error.message
      }).eq('id', req.batch_id)
    }

    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )
  }
}) 