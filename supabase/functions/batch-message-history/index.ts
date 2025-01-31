import { corsHeaders } from '../_shared/cors.ts'
import { getSupabaseClient } from '../preview-message/context.ts'

interface HistoryRequest {
  limit?: number
  offset?: number
  status?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { limit = 10, offset = 0, status } = await req.json() as HistoryRequest
    const userId = req.headers.get('x-user-id')

    if (!userId) {
      throw new Error('Missing user ID')
    }

    let query = getSupabaseClient()
      .from('batch_jobs')
      .select('*', { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (status) {
      query = query.eq('status', status)
    }

    const { data: jobs, error, count } = await query

    if (error) {
      throw error
    }

    return new Response(
      JSON.stringify({
        jobs,
        total: count,
        limit,
        offset,
        has_more: count ? offset + limit < count : false
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