import { serve } from 'https://deno.fresh.dev/std@0.168.0/http/server.ts'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { MODELS, PROMPT_TEMPLATES } from './config.ts'
import { Database } from '../_shared/database.types'

// Initialize OpenAI with environment variable
const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

// Initialize Supabase client
const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false
    }
  }
)

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

serve(async (req) => {
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
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: systemMessage
        },
        {
          role: "user",
          content: `Generate a message for context: ${JSON.stringify(customer_context)}\nType: ${context_type}`
        }
      ]
    })

    // Extract and format the generated message
    const generatedMessage = completion.choices[0].message.content

    // Update log with success
    if (logEntry?.id) {
      const { error: updateError } = await supabaseClient
        .from('message_generation_logs')
        .update({
          generated_message: generatedMessage,
          model_used: "gpt-4",
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
          model: "gpt-4",
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
    // Log error
    if (customer_context?.customer_id) {
      await supabaseClient
        .from('message_generation_logs')
        .insert({
          customer_id: customer_context.customer_id,
          context_type: context_type || 'unknown',
          input_context: customer_context,
          status: 'failed',
          error_message: error.message,
          started_at: new Date().toISOString(),
          completed_at: new Date().toISOString(),
          generation_time: Date.now() - startTime,
          success: false
        })
    }

    // Return error response
    return new Response(
      JSON.stringify({
        error: error.message,
        metadata: {
          customer_id: customer_context?.customer_id,
          context_type,
          timestamp: new Date().toISOString()
        }
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})