import { createClient } from '@supabase/supabase-js'
import { OpenAI } from 'openai'

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
}

Deno.serve(async (req) => {
  try {
    const { customer_ids, context_type, organization_id, max_batch_size = 100 } = await req.json() as BatchRequest

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
            .from('communication_history')
            .insert({
              customer_id: customer.customer_id,
              message_text: messageData.message,
              template_id: null, // TODO: Store template if needed
              effectiveness_metrics: {
                generation_metadata: messageData.metadata
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