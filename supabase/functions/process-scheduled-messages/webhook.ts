import { DeliveryStatus } from './retry.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

interface WebhookPayload {
  delivery_id: string
  status: DeliveryStatus
  customer_id: string
  metadata?: Record<string, any>
  error?: {
    message: string
    code?: string
  }
}

async function trackWebhookDelivery(
  webhookId: string,
  eventType: string,
  payload: WebhookPayload,
  startTime: number
) {
  const duration = Date.now() - startTime
  
  return supabaseClient
    .from('webhook_deliveries')
    .insert({
      webhook_id: webhookId,
      event_type: eventType,
      payload,
      status: 'pending',
      created_at: new Date().toISOString(),
      duration_ms: duration
    })
}

async function updateWebhookDelivery(
  deliveryId: string,
  response: Response,
  error?: Error
) {
  const update = {
    status: error ? 'failed' : 'success',
    status_code: response?.status,
    response_body: await response?.text(),
    error_message: error?.message,
    completed_at: new Date().toISOString()
  }

  return supabaseClient
    .from('webhook_deliveries')
    .update(update)
    .eq('id', deliveryId)
}

async function handleWebhookRetry(
  webhookId: string,
  deliveryId: string,
  payload: WebhookPayload,
  config: {
    retryCount: number
    timeoutMs: number
    secret: string
    url: string
  }
) {
  const { data: delivery } = await supabaseClient
    .from('webhook_deliveries')
    .select('attempt_count')
    .eq('id', deliveryId)
    .single()

  const attemptCount = (delivery?.attempt_count || 0) + 1

  if (attemptCount <= config.retryCount) {
    // Exponential backoff with jitter
    const backoffMs = Math.min(
      1000 * Math.pow(2, attemptCount) + Math.random() * 1000,
      1000 * 60 * 60 // Max 1 hour
    )
    const nextRetry = new Date(Date.now() + backoffMs)

    await supabaseClient
      .from('webhook_deliveries')
      .update({
        status: 'retrying',
        attempt_count: attemptCount,
        next_retry_at: nextRetry.toISOString()
      })
      .eq('id', deliveryId)

    // Schedule retry
    setTimeout(async () => {
      try {
        const timestamp = Date.now().toString()
        const signature = await generateSignature(config.secret, timestamp, payload)
        
        const response = await fetch(config.url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Webhook-Timestamp': timestamp,
            'X-Webhook-Signature': signature,
            'X-Retry-Count': attemptCount.toString()
          },
          body: JSON.stringify(payload)
        })

        await updateWebhookDelivery(deliveryId, response)
      } catch (error) {
        await handleWebhookRetry(webhookId, deliveryId, payload, config)
      }
    }, backoffMs)
  } else {
    // Mark as permanently failed
    await supabaseClient
      .from('webhook_deliveries')
      .update({
        status: 'failed',
        error_message: 'Max retry attempts exceeded'
      })
      .eq('id', deliveryId)
  }
}

export async function notifyWebhook(
  organizationId: string, 
  payload: WebhookPayload
) {
  const { data: webhookConfig } = await supabaseClient
    .from('webhook_configurations')
    .select('id, url, secret, retry_count, timeout_ms')
    .eq('organization_id', organizationId)
    .contains('event_types', ['delivery_status'])
    .eq('is_active', true)
    .single()

  if (webhookConfig?.url) {
    try {
      const startTime = Date.now()
      const timestamp = Date.now().toString()
      const signature = await generateSignature(
        webhookConfig.secret,
        timestamp,
        payload
      )

      // Track delivery attempt
      const { data: delivery } = await trackWebhookDelivery(
        webhookConfig.id,
        'delivery_status',
        payload,
        startTime
      )

      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), webhookConfig.timeout_ms)

      try {
        const response = await fetch(webhookConfig.url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Webhook-Timestamp': timestamp,
            'X-Webhook-Signature': signature
          },
          body: JSON.stringify(payload),
          signal: controller.signal
        })

        clearTimeout(timeout)
        await updateWebhookDelivery(delivery.id, response)

        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
      } catch (error) {
        await handleWebhookRetry(webhookConfig.id, delivery.id, payload, {
          retryCount: webhookConfig.retry_count,
          timeoutMs: webhookConfig.timeout_ms,
          secret: webhookConfig.secret,
          url: webhookConfig.url
        })
      }
    } catch (error) {
      console.error('Webhook notification failed:', error)
    }
  }
}

async function generateSignature(
  secret: string, 
  timestamp: string, 
  payload: WebhookPayload
): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(`${timestamp}.${JSON.stringify(payload)}`)
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const signature = await crypto.subtle.sign('HMAC', key, data)
  return Array.from(new Uint8Array(signature))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
} 