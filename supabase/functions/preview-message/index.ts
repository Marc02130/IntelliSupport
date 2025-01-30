import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { OpenAI } from 'https://esm.sh/openai@4.28.0'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { websocket } from 'https://deno.land/x/websocket@v0.1.4/mod.ts'
import { checkRateLimit } from './rateLimit.ts'
import { enhanceContext } from './context.ts'
import { MODELS, PROMPT_TEMPLATES } from './config.ts'

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

interface PreviewRequest {
  customer_context: {
    customer_id: string
    preferred_style?: string
    recent_communications?: Array<{
      message: string
      sent_at: string
      effectiveness: Record<string, any>
    }>
  }
  draft_text: string
  context_type: string
}

serve(async (req) => {
  // Handle WebSocket upgrade
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("Expected websocket", { status: 400 })
  }

  const { socket, response } = Deno.upgradeWebSocket(req)

  socket.onopen = () => {
    console.log("Client connected")
  }

  socket.onmessage = async (event) => {
    try {
      const data: PreviewRequest = JSON.parse(event.data)
      
      // Check rate limit
      const rateLimitInfo = checkRateLimit(data.customer_context.customer_id)
      
      // Enhance context
      const enhancedContext = await enhanceContext(data.customer_context.customer_id)
      
      // Stream suggestions using OpenAI with enhanced context
      const stream = await openai.chat.completions.create({
        model: MODELS.GPT4,
        messages: [
          {
            role: "system",
            content: `You are a helpful assistant providing real-time suggestions for customer communications.
                     Style: ${data.customer_context.preferred_style || enhancedContext.preferences?.preferred_style || 'professional'}
                     Context: ${data.context_type}
                     Recent Communications: ${JSON.stringify(enhancedContext.communications)}`
          },
          {
            role: "user",
            content: PROMPT_TEMPLATES.IMPROVEMENT.replace('{draft}', data.draft_text)
          }
        ],
        stream: true
      })

      // Send suggestions as they arrive
      for await (const chunk of stream) {
        if (chunk.choices[0]?.delta?.content) {
          socket.send(JSON.stringify({
            type: 'suggestion',
            content: chunk.choices[0].delta.content
          }))
        }
      }

    } catch (error) {
      socket.send(JSON.stringify({
        type: 'error',
        message: error.message
      }))
    }
  }

  socket.onerror = (e) => console.error("WebSocket error:", e)
  socket.onclose = () => console.log("Client disconnected")

  return response
}) 