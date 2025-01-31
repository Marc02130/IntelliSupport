import { corsHeaders } from '../_shared/cors.ts'
import { getSupabaseClient } from '../preview-message/context.ts'

interface StatusRequest {
  batch_id: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { batch_id } = await req.json() as StatusRequest
    const userId = req.headers.get('x-user-id')

    if (!userId) {
      throw new Error('Missing user ID')
    }

    const { data: job, error } = await getSupabaseClient()
      .from('batch_jobs')
      .select('*')
      .eq('id', batch_id)
      .eq('user_id', userId)
      .single()

    if (error || !job) {
      throw new Error('Batch job not found')
    }

    return new Response(
      JSON.stringify({
        batch_id: job.id,
        status: job.status,
        total: job.total_messages,
        processed: job.processed_count,
        progress: (job.processed_count / job.total_messages) * 100,
        results: job.results,
        errors: job.errors,
        started_at: job.started_at,
        completed_at: job.completed_at
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