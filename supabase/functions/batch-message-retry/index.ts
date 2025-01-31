import { corsHeaders } from '../_shared/cors.ts'
import { getSupabaseClient } from '../preview-message/context.ts'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'
import { enhanceContext } from '../preview-message/context.ts'

interface RetryRequest {
  batch_id: string
}

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { batch_id } = await req.json() as RetryRequest
    const userId = req.headers.get('x-user-id')

    if (!userId) {
      throw new Error('Missing user ID')
    }

    // Get job details
    const { data: job } = await getSupabaseClient()
      .from('batch_jobs')
      .select('*')
      .eq('id', batch_id)
      .eq('user_id', userId)
      .single()

    if (!job) {
      throw new Error('Batch job not found')
    }

    if (!['failed', 'completed_with_errors'].includes(job.status)) {
      throw new Error(`Cannot retry job in ${job.status} status`)
    }

    // Update status to processing
    await getSupabaseClient()
      .from('batch_jobs')
      .update({
        status: 'processing',
        started_at: new Date().toISOString(),
        completed_at: null,
        errors: null
      })
      .eq('id', batch_id)

    // Get failed messages
    const failedResults = job.results.filter(r => !r.success)
    let processed = job.results.filter(r => r.success).length
    const newResults = [...job.results.filter(r => r.success)]

    // Retry failed messages
    for (const result of failedResults) {
      try {
        const [context, completion] = await Promise.all([
          enhanceContext(result.customer_id),
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
                content: PROMPT_TEMPLATES.IMPROVEMENT.replace('{draft}', result.message_text)
              }
            ]
          })
        ])

        processed++
        await getSupabaseClient()
          .from('batch_jobs')
          .update({ processed_count: processed })
          .eq('id', batch_id)

        newResults.push({
          success: true,
          customer_id: result.customer_id,
          generated_text: completion.choices[0].message.content
        })
      } catch (error) {
        newResults.push({
          success: false,
          customer_id: result.customer_id,
          error: error.message
        })
      }
    }

    // Update final status
    const hasErrors = newResults.some(r => !r.success)
    await getSupabaseClient()
      .from('batch_jobs')
      .update({
        status: hasErrors ? 'completed_with_errors' : 'completed',
        completed_at: new Date().toISOString(),
        results: newResults,
        errors: hasErrors ? newResults.filter(r => !r.success) : null
      })
      .eq('id', batch_id)

    return new Response(
      JSON.stringify({
        batch_id,
        status: hasErrors ? 'completed_with_errors' : 'completed',
        total: newResults.length,
        processed,
        success: newResults.filter(r => r.success).length,
        failed: newResults.filter(r => !r.success).length
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