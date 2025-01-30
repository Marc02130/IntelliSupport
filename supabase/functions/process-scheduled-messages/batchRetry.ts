import { DeliveryStatus } from './retry.ts'

export async function handleBatchRetry(batchId: string, error: Error) {
  const { data: batch } = await supabaseClient
    .from('batch_runs')
    .select('metadata')
    .eq('id', batchId)
    .single()

  const retryCount = (batch?.metadata?.retry_count || 0) + 1
  const maxRetries = 3

  if (retryCount <= maxRetries) {
    // Get all failed deliveries in batch
    const { data: failedDeliveries } = await supabaseClient
      .from('message_deliveries')
      .select('id')
      .eq('batch_id', batchId)
      .eq('status', 'failed')

    if (failedDeliveries?.length) {
      const backoffMinutes = Math.pow(2, retryCount)
      const retryTime = new Date(Date.now() + (backoffMinutes * 60 * 1000))

      // Update all failed deliveries
      await supabaseClient
        .from('message_deliveries')
        .update({
          status: 'scheduled' as DeliveryStatus,
          scheduled_for: retryTime.toISOString(),
          metadata: {
            retry_count: retryCount,
            last_error: error.message,
            retry_scheduled: true,
            last_retry: new Date().toISOString(),
            batch_retry: true
          }
        })
        .eq('batch_id', batchId)
        .in('status', ['failed', 'bounced'])

      // Update batch status
      await supabaseClient
        .from('batch_runs')
        .update({
          status: 'retrying',
          metadata: {
            ...batch?.metadata,
            retry_count: retryCount,
            last_error: error.message,
            retry_scheduled: true,
            last_retry: new Date().toISOString()
          }
        })
        .eq('id', batchId)
    }
  }
} 