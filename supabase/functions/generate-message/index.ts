import { createClient } from '@supabase/supabase-js'
import { OpenAI } from 'openai'
import { Database } from '../_shared/database.types'

// Initialize Supabase client
const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  }
)

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

interface CustomerContext {
  customer_id: string
  customer_name: string
  preferred_style: string
  preferred_times: Record<string, any>
  communication_frequency: string
  recommendations: Record<string, any>
  recent_communications: Array<{
    message: string
    sent_at: string
    effectiveness: Record<string, any>
  }>
  organization_id: string
  additional_context: Record<string, any>
}

interface RequestBody {
  customer_context: CustomerContext
  context_type: string
}

Deno.serve(async (req) => {
  const startTime = Date.now()
  let customer_context: CustomerContext | undefined
  let context_type: string | undefined
  
  try {
    // Verify request method
    if (req.method !== 'POST') {
      throw new Error('Method not allowed')
    }

    // Parse request body
    const body: RequestBody = await req.json()
    customer_context = body.customer_context
    context_type = body.context_type

    // Validate required fields
    if (!customer_context || !context_type) {
      throw new Error('Missing required fields')
    }

    // Log generation attempt
    const { data: logEntry, error: logError } = await supabaseClient
      .from('message_generation_logs')
      .insert({
        customer_id: customer_context.customer_id,
        context_type,
        input_context: customer_context,
        status: 'processing',
        started_at: new Date().toISOString()
      })
      .select()
      .single()

    if (logError) {
      console.error('Error logging generation attempt:', logError)
    }

    // Format recent communications for context
    const recentCommunicationsContext = customer_context.recent_communications
      ?.map(comm => `Time: ${comm.sent_at}
        Message: ${comm.message}
        Effectiveness: ${JSON.stringify(comm.effectiveness)}`)
      .join('\n\n') || 'No recent communications'

    // Create system message with detailed context
    const systemMessage = `You are an AI assistant specializing in customer communications.
      Your task is to generate a message that matches the following parameters:

      Communication Style: ${customer_context.preferred_style}
      Context Type: ${context_type}
      Customer's Preferred Communication Frequency: ${customer_context.communication_frequency}
      
      Recent Communication History:
      ${recentCommunicationsContext}

      Additional Guidelines:
      - Match the specified communication style exactly
      - Consider the customer's previous interactions and their effectiveness
      - Keep the message professional but personalized
      - Focus on clarity and actionable content
      - Maintain consistent tone with previous successful communications`

    // Generate response using GPT-4
    const completion = await openai.chat.completions.create({
      model: Deno.env.get('OPENAI_MODEL') || "gpt-4-turbo-preview",
      messages: [
        {
          role: "system",
          content: systemMessage
        },
        {
          role: "user",
          content: `Generate a ${context_type} message for ${customer_context.customer_name}.
            Additional Context: ${JSON.stringify(customer_context.additional_context)}`
        }
      ],
      temperature: 0.7,
      max_tokens: 500
    })

    // Extract and format the generated message
    const generatedMessage = completion.choices[0].message.content

    // Update log with success
    if (logEntry?.id) {
      const { error: updateError } = await supabaseClient
        .from('message_generation_logs')
        .update({
          generated_message: generatedMessage,
          model_used: Deno.env.get('OPENAI_MODEL') || "gpt-4-turbo-preview",
          usage_metrics: completion.usage,
          status: 'completed',
          success: true,
          generation_time: Date.now() - startTime,
          completed_at: new Date().toISOString()
        })
        .eq('id', logEntry.id)

      if (updateError) {
        console.error('Error updating generation log:', updateError)
      }
    }

    // Return response
    return new Response(
      JSON.stringify({
        message: generatedMessage,
        metadata: {
          model: Deno.env.get('OPENAI_MODEL') || "gpt-4-turbo-preview",
          usage: completion.usage,
          context_used: {
            style: customer_context.preferred_style,
            context_type,
            communication_frequency: customer_context.communication_frequency,
            recent_communications_count: customer_context.recent_communications?.length || 0
          },
          generation_time: Date.now() - startTime,
          log_id: logEntry?.id
        }
      }),
      { 
        headers: { 
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache'
        } 
      }
    )

  } catch (error) {
    // Log error if we have context
    if (customer_context?.customer_id) {
      const { error: logError } = await supabaseClient
        .from('message_generation_logs')
        .insert({
          customer_id: customer_context.customer_id,
          context_type,
          input_context: customer_context,
          error_message: error.message,
          status: 'failed',
          success: false,
          generation_time: Date.now() - startTime,
          completed_at: new Date().toISOString()
        })

      if (logError) {
        console.error('Error logging generation failure:', logError)
      }
    }

    console.error('Error generating message:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Error generating message', 
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  }
})