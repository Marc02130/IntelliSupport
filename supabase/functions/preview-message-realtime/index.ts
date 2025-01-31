import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { corsHeaders } from '../_shared/cors.ts'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'
import { enhanceContext, getSupabaseClient } from '../preview-message/context.ts'
import { getCachedPreview, setCachedPreview } from './cache.ts'

console.log('Starting function initialization')

interface PreviewRequest {
  message_text: string
  customer_id: string
  style?: string
}

interface BatchMessage {
  message_text: string
  customer_id: string
  style?: string
}

interface BatchMetrics {
  durations: number[]
  cacheHits: number
  cacheMisses: number
  rateLimitHits: number
  contextDurations: number[]
  openaiDurations: number[]
  errors: Array<{
    message: string
    type: 'openai' | 'context' | 'cache' | 'db' | 'other'
    messageId?: string
    timestamp: string
  }>
}

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

let clientPromise: Promise<ReturnType<typeof getSupabaseClient>>

// Initialize client lazily
async function getClient() {
  console.log('getClient called')
  if (!clientPromise) {
    console.log('Initializing new client')
    clientPromise = getSupabaseClient()
    const client = await clientPromise
    console.log('Testing client connection')
    try {
      await client.from('message_previews').select('id').limit(1)
      console.log('Client connection successful')
    } catch (error) {
      console.error('Client connection failed:', error)
      throw error
    }
  }
  return await clientPromise
}

async function processBatch(
  userId: string,
  request: { messages: BatchMessage[] }
): Promise<{ batch_id: string }> {
  // Validate batch size
  if (request.messages.length > 100) {
    throw new Error('Batch size cannot exceed 100 messages')
  }

  // Create batch job
  const { data: batch, error: batchError } = await getSupabaseClient()
    .from('batch_jobs')
    .insert({
      id: crypto.randomUUID(),
      user_id: userId,
      total_messages: request.messages.length,
      queued_count: request.messages.length,
      status: 'processing',
      started_at: new Date().toISOString()
    })
    .select()
    .single()

  if (batchError || !batch) {
    throw new Error(`Failed to create batch job: ${batchError?.message}`)
  }

  // Initialize metrics
  const metrics: BatchMetrics = {
    durations: [],
    cacheHits: 0,
    cacheMisses: 0,
    rateLimitHits: 0,
    contextDurations: [],
    openaiDurations: [],
    errors: []
  }

  // Process messages in parallel with concurrency limit
  const concurrency = 5
  const chunks = chunk(request.messages, concurrency)
  
  // Process chunks sequentially
  for (const messageChunk of chunks) {
    try {
      // Update processing count
      await getSupabaseClient()
        .from('batch_jobs')
        .update({
          queued_count: batch.queued_count - messageChunk.length,
          processing_count: messageChunk.length
        })
        .eq('id', batch.id)

      // Process messages in chunk concurrently
      const results = await Promise.allSettled(
        messageChunk.map(msg => processMessage(batch.id, userId, msg, metrics))
      )

      // Update batch progress and metrics
      const succeeded = results.filter(r => r.status === 'fulfilled').length
      const failed = results.filter(r => r.status === 'rejected').length

      await updateBatchProgress(batch.id, succeeded, failed, metrics)
    } catch (error) {
      console.error('Chunk processing failed:', error)
      if (error.message.includes('rate limit')) {
        metrics.rateLimitHits++
      }
    }
  }

  return { batch_id: batch.id }
}

async function processMessage(
  batchId: string,
  userId: string,
  message: BatchMessage,
  metrics: BatchMetrics
) {
  const startTime = Date.now()
  const timings: Record<string, number> = {}
  const previewId = crypto.randomUUID()

  try {
    // Check cache first
    const cached = await getCachedPreview(message.message_text, message.customer_id, message.style)
    if (cached) {
      metrics.cacheHits++
    } else {
      metrics.cacheMisses++
    }

    const { data: preview, error } = await getSupabaseClient()
      .from('message_previews')
      .insert({
        id: previewId,
        user_id: userId,
        message_text: message.message_text,
        customer_id: message.customer_id,
        style: message.style,
        status: 'processing',
        metadata: { request_metrics: metrics }
      })
      .select()
      .single()

    if (error || !preview) {
      throw new Error(`Failed to create preview: ${error?.message}`)
    }

    await generatePreview(
      preview.id,
      message.message_text,
      message.customer_id,
      message.style
    )

    metrics.durations.push(Date.now() - startTime)
  } catch (error) {
    metrics.errors.push({
      message: error.message,
      type: error.message.includes('rate limit') ? 'openai' :
            error.message.includes('context') ? 'context' :
            error.message.includes('cache') ? 'cache' :
            error.message.includes('database') ? 'db' : 'other',
      messageId: message.message_text.slice(0, 50),
      timestamp: new Date().toISOString()
    })
    throw error
  }
}

async function updateBatchProgress(
  batchId: string,
  succeeded: number,
  failed: number,
  metrics: BatchMetrics
) {
  // Calculate metrics
  const avgDuration = Math.round(
    metrics.durations.reduce((a, b) => a + b, 0) / metrics.durations.length
  )
  const p95Duration = Math.round(
    metrics.durations.sort((a, b) => a - b)[
      Math.floor(metrics.durations.length * 0.95)
    ]
  )

  await getSupabaseClient()
    .from('batch_jobs')
    .update({
      processed_count: succeeded,
      processing_count: 0,
      status: failed > 0 ? 'completed_with_errors' : 'completed',
      completed_at: new Date().toISOString(),
      avg_duration_ms: avgDuration,
      p95_duration_ms: p95Duration,
      cache_hits: metrics.cacheHits,
      cache_misses: metrics.cacheMisses,
      rate_limit_hits: metrics.rateLimitHits,
      updated_at: new Date().toISOString(),
      results: { succeeded, failed },
      errors: failed > 0 ? { count: failed, details: metrics.errors } : null
    })
    .eq('id', batchId)
}

function chunk<T>(array: T[], size: number): T[][] {
  return Array.from({ length: Math.ceil(array.length / size) }, (_, i) =>
    array.slice(i * size, i * size + size)
  )
}

Deno.serve(async (req) => {
  console.log('Request received:', req.method, new URL(req.url).pathname)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const client = await getClient()
    const url = new URL(req.url)
    const metrics: Record<string, number> = {}
    const requestStartTime = Date.now()
    const previewId = crypto.randomUUID()
    console.log('Generated preview ID:', previewId)
    
    // Start client init and request parsing in parallel
    const [{ message_text, customer_id, style }, userId] = await Promise.all([
      req.json() as Promise<PreviewRequest>,
      (async () => {
        const id = req.headers.get('x-user-id')
        if (!id) throw new Error('Missing user ID')
        return id
      })()
    ])
    metrics.parse_time = Date.now() - requestStartTime
    
    // Run all async operations in parallel
    const [cached, preview, context] = await Promise.all([
      getCachedPreview(message_text, customer_id, style),
      client
        .from('message_previews')
        .insert({
          id: previewId,
          user_id: userId,
          message_text,
          customer_id,
          style,
          status: 'processing',
          metadata: { request_metrics: metrics }
        })
        .select()
        .single(),
      enhanceContext(customer_id, {
        limit: 2,
        includeMetrics: false
      }).catch(err => {
        console.error('Context retrieval failed:', err)
        return null
      }),
    ])

    console.log('Preview result:', {
      cached,
      preview: {
        data: preview.data,
        error: preview.error,
        status: preview.status
      },
      context
    })

    if (preview.error) {
      console.error('Insert error details:', {
        error: preview.error,
        previewId,
        userId,
        customerId: customer_id
      })
    }

    if (!preview.data || preview.error) {
      console.error('Preview creation failed:', preview.error)
      throw new Error('Failed to create preview')
    }

    // If context failed, continue with basic context
    const baseContext = context || `Style: ${style || 'professional'}`

    // Use cached result if available
    if (cached) {
      metrics.cache_hit = true
      // Update preview in background
      client
        .from('message_previews')
        .update({
          preview_text: cached,
          status: 'completed',
          duration_ms: Date.now() - requestStartTime,
          metadata: { ...preview.data.metadata, metrics },
          updated_at: new Date().toISOString()
        })
        .eq('id', preview.id)
        .then(() => console.log('Preview updated'))
        .catch(err => console.error('Failed to update preview:', err))
      
      return new Response(
        JSON.stringify({
          preview_id: preview.id,
          status: 'completed',
          preview_text: cached,
          duration_ms: Date.now() - requestStartTime
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
      )
    }

    // Log all variables being passed to generatePreview
    console.log('generatePreview params:', {
      preview_id: preview.id,
      message_text,
      customer_id,
      style,
      baseContext
    })

    // Generate preview in background with pre-fetched context
    generatePreview(preview.id, message_text, customer_id, style, baseContext).catch(error => {
      console.error('Preview generation failed:', error)
    })

    return new Response(
      JSON.stringify({
        preview_id: preview.id,
        status: 'processing',
        duration_ms: Date.now() - requestStartTime
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )
  }
})

async function generatePreview(
  previewId: string,
  messageText: string,
  customerId: string,
  style?: string,
  contextString?: string
) {
  try {
    const startTime = Date.now()
    const metrics: Record<string, number> = {}
    const client = await getSupabaseClient()
    
    // Check cache first
    const cacheStartTime = Date.now()
    const cached = await getCachedPreview(messageText, customerId, style)
    metrics.cache_lookup_time = Date.now() - cacheStartTime

    if (cached) {
      console.log('Using cached preview')
      metrics.cache_hit = true
      metrics.total_duration = Date.now() - startTime
      await client
        .from('message_previews')
        .update({
          preview_text: cached,
          status: 'completed',
          duration_ms: metrics.total_duration,
          metadata: { metrics },
          updated_at: new Date().toISOString()
        })
        .eq('id', previewId)
      return
    }

    // Track OpenAI call time
    const openaiStartTime = Date.now()
    console.log('Starting OpenAI request:', {
      previewId,
      messageText: messageText.slice(0, 50),
      startTime: openaiStartTime
    })

    const stream = await openai.chat.completions.create({
      model: MODELS.GPT35,
      temperature: 0.7,
      max_tokens: 150,
      messages: [
        {
          role: "system",
          content: `You are a concise assistant improving message clarity.
                    Style: ${style || 'professional'}
                    Context: ${contextString || ''}`
        },
        {
          role: "user",
          content: `Improve this message, keeping it brief and clear: "${messageText}"`
        }
      ],
      stream: true
    })
    metrics.openai_duration = Date.now() - openaiStartTime
    console.log('OpenAI request completed:', {
      previewId,
      duration: metrics.openai_duration
    })
    
    const previewText = await streamToText(stream)
    
    // Track cache update time
    const cacheUpdateStartTime = Date.now()
    await setCachedPreview(messageText, customerId, previewText, style)
    metrics.cache_update_time = Date.now() - cacheUpdateStartTime

    // Track total time
    metrics.total_duration = Date.now() - startTime

    console.log('Generation metrics:', {
      cache_lookup_time: metrics.cache_lookup_time,
      openai_duration: metrics.openai_duration,
      cache_update_time: metrics.cache_update_time,
      total_duration: metrics.total_duration
    })

    await client
      .from('message_previews')
      .update({
        preview_text: previewText,
        status: 'completed',
        duration_ms: metrics.total_duration,
        metadata: { metrics },
        updated_at: new Date().toISOString()
      })
      .eq('id', previewId)

  } catch (error) {
    console.error('Preview generation failed:', {
      error: error.message,
      previewId,
      messageText: messageText.slice(0, 50)
    })

    const client = await getSupabaseClient()
    await client
      .from('message_previews')
      .update({
        status: 'error',
        error: error.message,
        metadata: { 
          error_time: Date.now(),
          error_type: error.message.includes('rate limit') ? 'openai_rate_limit' :
                     error.message.includes('timeout') ? 'openai_timeout' :
                     'other'
        },
        updated_at: new Date().toISOString()
      })
      .eq('id', previewId)
  }
}

async function streamToText(stream: ReadableStream): Promise<string> {
  const chunks: Uint8Array[] = []
  const decoder = new TextDecoder()
  const reader = stream.getReader()

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    chunks.push(value)
  }

  return chunks.map(chunk => decoder.decode(chunk)).join('')
} 