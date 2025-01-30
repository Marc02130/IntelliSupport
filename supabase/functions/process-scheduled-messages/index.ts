import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { handleRetry, DeliveryStatus } from './retry.ts'
import { notifyWebhook } from './webhook.ts'
import { handleBatchRetry } from './batchRetry.ts'

const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false
    }
  }
)

serve(async (req) => {
  try {
    // Get messages scheduled for delivery
    const { data: scheduledMessages, error: queryError } = await supabaseClient
      .from('message_deliveries')
      .select(`
        id,
        content,
        channel,
        customer_id,
        metadata,
        scheduled_for,
        organization_id,
        batch_id
      `)
      .eq('status', 'scheduled')
      .lte('scheduled_for', new Date().toISOString())
      .limit(100) // Process in batches

    if (queryError) throw queryError

    // Process each scheduled message
    const results = await Promise.all(
      scheduledMessages.map(async (message) => {
        try {
          // Update status to processing
          await supabaseClient
            .from('message_deliveries')
            .update({ status: 'processing' as DeliveryStatus })
            .eq('id', message.id)

          // Send to delivery service
          const response = await fetch(`${Deno.env.get('DELIVERY_SERVICE_URL')}/send`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${Deno.env.get('DELIVERY_SERVICE_KEY')}`
            },
            body: JSON.stringify({
              delivery_id: message.id,
              channel: message.channel,
              content: message.content,
              customer_id: message.customer_id,
              metadata: message.metadata
            })
          })

          if (!response.ok) {
            throw new Error(`Delivery service error: ${response.statusText}`)
          }

          // Update delivery status
          await supabaseClient
            .from('message_deliveries')
            .update({ 
              status: 'sent' as DeliveryStatus,
              sent_at: new Date().toISOString(),
              delivery_metadata: await response.json()
            })
            .eq('id', message.id)

          // Notify webhook
          await notifyWebhook(message.organization_id, {
            delivery_id: message.id,
            status: 'sent',
            customer_id: message.customer_id,
            metadata: message.metadata
          })

          return {
            delivery_id: message.id,
            status: 'success'
          }

        } catch (error) {
          console.error(`Error processing message ${message.id}:`, error)

          // Handle individual retry
          await handleRetry(message.id, error)

          // If part of batch, handle batch retry
          if (message.batch_id) {
            await handleBatchRetry(message.batch_id, error)
          }

          // Notify webhook of failure
          await notifyWebhook(message.organization_id, {
            delivery_id: message.id,
            status: 'failed',
            customer_id: message.customer_id,
            error: {
              message: error.message,
              code: error.code
            }
          })

          return {
            delivery_id: message.id,
            status: 'error',
            error: error.message
          }
        }
      })
    )

    return new Response(
      JSON.stringify({
        processed: results.length,
        successful: results.filter(r => r.status === 'success').length,
        failed: results.filter(r => r.status === 'error').length,
        results
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Scheduled message processing failed:', error)
    return new Response(
      JSON.stringify({ error: 'Processing failed', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
}) 