import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { corsHeaders } from '../_shared/cors.ts'
import { checkRateLimit } from '../preview-message/rateLimit.ts'
import { enhanceContext } from '../preview-message/context.ts'
import { MODELS, PROMPT_TEMPLATES } from '../preview-message/config.ts'

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      persistSession: false
    }
  }
)

interface PreviewRequest {
  message_text: string
  customer_id: string
  style?: string
  context_type?: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      throw new Error('Method not allowed')
    }

    const { message_text, customer_id, style, context_type } = await req.json() as PreviewRequest

    // Check rate limit
    const rateLimitInfo = await checkRateLimit(customer_id)

    // Get enhanced context
    const context = await enhanceContext(customer_id)

    if (!context.preferences) {
      throw new Error('Customer not found')
    }

    // Generate preview
    const completion = await openai.chat.completions.create({
      model: MODELS.GPT4,
      messages: [
        {
          role: "system",
          content: PROMPT_TEMPLATES.SYSTEM_CONTEXT
        },
        {
          role: "user",
          content: PROMPT_TEMPLATES.IMPROVEMENT.replace('{draft}', message_text)
        }
      ]
    })

    // Log preview generation
    await supabaseClient.from('message_generation_logs').insert({
      customer_id,
      context_type: context_type || 'preview',
      input_context: {
        message_text,
        style,
        customer_context: context
      },
      generated_message: completion.choices[0].message.content,
      model_used: MODELS.GPT4,
      status: 'completed',
      success: true
    })

    return new Response(
      JSON.stringify({
        preview: completion.choices[0].message.content,
        metadata: {
          model: MODELS.GPT4,
          customer_style: context.preferences.preferred_style,
          usage: completion.usage,
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