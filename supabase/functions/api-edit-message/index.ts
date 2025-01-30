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

interface EditRequest {
  message_id: string
  customer_id: string
  current_text: string
  edit_type: 'tone' | 'clarity' | 'length' | 'style' | 'grammar' | 
             'format' | 'emphasis' | 'technical' | 'persuasive' | 'localize'
  edit_instructions?: string
  target_style?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      throw new Error('Method not allowed')
    }

    const { message_id, customer_id, current_text, edit_type, edit_instructions, target_style } = 
      await req.json() as EditRequest

    // Check rate limit
    const rateLimitInfo = await checkRateLimit(customer_id)

    // Get message history
    const { data: messageHistory } = await supabaseClient
      .from('message_versions')
      .select('*')
      .eq('message_id', message_id)
      .order('version_number', { ascending: false })

    // Get context
    const context = await enhanceContext(customer_id)

    if (!context.preferences) {
      throw new Error('Customer not found')
    }

    // Generate edit
    const completion = await openai.chat.completions.create({
      model: MODELS.GPT4,
      messages: [
        {
          role: "system",
          content: `You are helping edit customer communications.
            Current Style: ${context.preferences.preferred_style}
            Target Style: ${target_style || context.preferences.preferred_style}
            Edit Type: ${edit_type}
            ${edit_instructions ? `Additional Instructions: ${edit_instructions}` : ''}
            Previous Versions: ${messageHistory?.length || 0}`
        },
        {
          role: "user",
          content: `Edit this message: ${current_text}`
        }
      ]
    })

    const editedText = completion.choices[0].message.content

    // Store version
    const { data: newVersion, error: versionError } = await supabaseClient
      .from('message_versions')
      .insert({
        message_id,
        version_number: (messageHistory?.[0]?.version_number || 0) + 1,
        content: editedText,
        edit_type,
        edit_instructions,
        previous_version: current_text,
        metadata: {
          target_style,
          model_used: MODELS.GPT4,
          timestamp: new Date().toISOString()
        }
      })
      .select()
      .single()

    if (versionError) {
      throw new Error('Failed to save message version')
    }

    return new Response(
      JSON.stringify({
        edited_text: editedText,
        version: newVersion,
        metadata: {
          model: MODELS.GPT4,
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