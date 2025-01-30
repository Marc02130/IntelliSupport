import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { corsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../preview-message/rateLimit.ts'
import { enhanceContext } from '../preview-message/context.ts'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'

const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false
    }
  }
)

interface SendMessageRequest {
  message_id: string
  version_id?: string // Optional, if sending specific version
  customer_id: string
  channel: 'email' | 'sms' | 'chat' | 'notification'
  scheduled_for?: string // ISO timestamp for scheduled sending
  metadata?: Record<string, any>
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      throw new Error('Method not allowed')
    }

    const { message_id, version_id, customer_id, channel, scheduled_for, metadata } = 
      await req.json() as SendMessageRequest

    // Check rate limit
    const rateLimitInfo = await checkRateLimit(customer_id)

    // Get message content
    const { data: messageData, error: messageError } = await supabaseClient
      .from(version_id ? 'message_versions' : 'communication_history')
      .select('*')
      .eq('id', version_id || message_id)
      .single()

    if (messageError || !messageData) {
      throw new Error('Message not found')
    }

    // Get customer context
    const context = await enhanceContext(customer_id)
    
    if (!context.preferences) {
      throw new Error('Customer not found')
    }

    // Create delivery record
    const { data: delivery, error: deliveryError } = await supabaseClient
      .from('message_deliveries')
      .insert({
        message_id,
        version_id,
        customer_id,
        channel,
        scheduled_for: scheduled_for || new Date().toISOString(),
        content: messageData.content || messageData.message,
        status: scheduled_for ? 'scheduled' : 'pending',
        metadata: {
          ...metadata,
          customer_context: context,
          rate_limit: rateLimitInfo
        }
      })
      .select()
      .single()

    if (deliveryError) {
      throw new Error('Failed to create delivery record')
    }

    // If version was sent, mark it
    if (version_id) {
      await supabaseClient
        .from('message_versions')
        .update({ selected_for_send: true })
        .eq('id', version_id)
    }

    // Trigger immediate delivery if not scheduled
    if (!scheduled_for) {
      // Notify delivery service
      await fetch(`${Deno.env.get('DELIVERY_SERVICE_URL')}/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('DELIVERY_SERVICE_KEY')}`
        },
        body: JSON.stringify({
          delivery_id: delivery.id,
          channel,
          content: messageData.content || messageData.message,
          customer: context
        })
      })
    }

    return new Response(
      JSON.stringify({
        delivery_id: delivery.id,
        status: delivery.status,
        scheduled_for: delivery.scheduled_for,
        metadata: {
          rate_limit: rateLimitInfo
        }
      }),
      { 
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json'
        } 
      }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: error.message === 'Rate limit exceeded' ? 429 : 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  }
}) 