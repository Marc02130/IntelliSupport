import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

// Initialize clients
const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? ''
)

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

interface BatchRequest {
  customer_ids?: string[]
  context_type: string
  organization_id?: string
  max_batch_size?: number
  scheduled_for?: string
  channel?: 'email' | 'sms' | 'chat' | 'notification'
  batch_template?: {
    id: string
    variables?: Record<string, any>
  }
}

Deno.serve(async (req) => {
  try {
    const { customer_ids, context_type, organization_id, max_batch_size = 100, scheduled_for, channel, batch_template } = await req.json() as BatchRequest

    // Get customers to process
    const { data: customers, error: customerError } = await supabaseClient
      .from('customer_communication_insights')
      .select('*')
      .in('customer_id', customer_ids || [])
      .eq('organization_id', organization_id)
      .limit(max_batch_size)

    if (customerError) throw customerError

    // Process each customer
    const results = await Promise.all(
      customers.map(async (customer) => {
        try {
          // Get customer context
          const response = await fetch(
            `${Deno.env.get('DB_URL')}/functions/v1/generate-message`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${Deno.env.get('SERVICE_ROLE_KEY')}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                customer_context: {
                  customer_id: customer.customer_id,
                  customer_name: customer.full_name,
                  preferred_style: customer.preferred_style,
                  communication_frequency: customer.communication_frequency,
                  recommendations: customer.analysis_recommendations,
                  recent_communications: [], // TODO: Get recent communications
                  organization_id: customer.organization_id
                },
                context_type
              })
            }
          )

          if (!response.ok) {
            throw new Error(`Failed to generate message: ${response.statusText}`)
          }

          const messageData = await response.json()

          // Store generated message
          const { error: insertError } = await supabaseClient
            .from('message_deliveries')
            .insert({
              customer_id: customer.customer_id,
              content: messageData.message,
              channel: channel || 'email',
              scheduled_for: scheduled_for || new Date().toISOString(),
              status: scheduled_for ? 'scheduled' : 'pending',
              template_id: null, // TODO: Store template if needed
              metadata: {
                generation_metadata: messageData.metadata,
                batch_id: crypto.randomUUID(),
                template_variables: batch_template?.variables
              }
            })

          if (insertError) throw insertError

          return {
            customer_id: customer.customer_id,
            status: 'success',
            message: messageData.message
          }

        } catch (error) {
          console.error(`Error processing customer ${customer.customer_id}:`, error)
          return {
            customer_id: customer.customer_id,
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
      { 
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Batch processing failed:', error)
    return new Response(
      JSON.stringify({ error: 'Batch processing failed', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
}) 