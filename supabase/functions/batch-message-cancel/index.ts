import { corsHeaders } from '../_shared/cors.ts'
import { getSupabaseClient } from '../preview-message/context.ts'

interface CancelRequest {
  batch_id: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { batch_id } = await req.json() as CancelRequest
    const userId = req.headers.get('x-user-id')

    if (!userId) {
      throw new Error('Missing user ID')
    }

    // Get current job status
    const { data: job } = await getSupabaseClient()
      .from('batch_jobs')
      .select('status')
      .eq('id', batch_id)
      .eq('user_id', userId)
      .single()

    if (!job) {
      throw new Error('Batch job not found')
    }

    if (job.status !== 'processing') {
      throw new Error(`Cannot cancel job in ${job.status} status`)
    }

    // Update job status
    const { error } = await getSupabaseClient()
      .from('batch_jobs')
      .update({
        status: 'cancelled',
        completed_at: new Date().toISOString(),
        errors: [{
          type: 'cancelled',
          message: 'Job cancelled by user'
        }]
      })
      .eq('id', batch_id)
      .eq('user_id', userId)

    if (error) {
      throw error
    }

    return new Response(
      JSON.stringify({
        batch_id,
        status: 'cancelled',
        message: 'Job cancelled successfully'
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