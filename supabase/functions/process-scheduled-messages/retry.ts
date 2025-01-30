import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false
    }
  }
)

export type DeliveryStatus = 
  | 'pending'
  | 'scheduled'
  | 'processing'
  | 'sent'
  | 'delivered'
  | 'failed'
  | 'bounced'
  | 'cancelled'

export async function handleRetry(deliveryId: string, error: Error) {
  const { data: delivery } = await supabaseClient
    .from('message_deliveries')
    .select('metadata')
    .eq('id', deliveryId)
    .single()

  const retryCount = (delivery?.metadata?.retry_count || 0) + 1
  const maxRetries = 3

  if (retryCount <= maxRetries) {
    // Schedule retry with exponential backoff
    const backoffMinutes = Math.pow(2, retryCount)
    const retryTime = new Date(Date.now() + (backoffMinutes * 60 * 1000))

    await supabaseClient
      .from('message_deliveries')
      .update({ 
        status: 'scheduled' as DeliveryStatus,
        scheduled_for: retryTime.toISOString(),
        metadata: {
          ...delivery?.metadata,
          retry_count: retryCount,
          last_error: error.message,
          retry_scheduled: true,
          last_retry: new Date().toISOString()
        }
      })
      .eq('id', deliveryId)
  } else {
    // Mark as permanently failed after max retries
    await supabaseClient
      .from('message_deliveries')
      .update({
        status: 'failed' as DeliveryStatus,
        error_details: {
          message: error.message,
          retry_exhausted: true,
          final_attempt: new Date().toISOString()
        }
      })
      .eq('id', deliveryId)
  }
} 