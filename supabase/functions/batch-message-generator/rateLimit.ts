import { getSupabaseClient } from '../preview-message/context.ts'

const BATCH_LIMIT = 100 // Max messages per batch
const RATE_WINDOW = 60 * 60 * 1000 // 1 hour window
const MAX_BATCHES = 10 // Max batches per hour

export async function checkBatchLimit(userId: string): Promise<{
  allowed: boolean
  remaining: number
  reset: number
}> {
  const supabase = getSupabaseClient()
  const now = Date.now()
  const windowStart = now - RATE_WINDOW

  const { count } = await supabase
    .from('batch_jobs')
    .select('id', { count: 'exact' })
    .gte('created_at', new Date(windowStart).toISOString())
    .eq('user_id', userId)

  return {
    allowed: (count || 0) < MAX_BATCHES,
    remaining: Math.max(0, MAX_BATCHES - (count || 0)),
    reset: now + RATE_WINDOW
  }
} 