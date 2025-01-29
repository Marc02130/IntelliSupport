import { createClient } from '@supabase/supabase-js'
import { OpenAI } from 'openai'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { websocket } from 'https://deno.land/x/websocket@v0.1.4/mod.ts'

const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

serve(async (req) => {
  // Upgrade the connection to WebSocket
  if (req.headers.get("upgrade") != "websocket") {
    return new Response(null, { status: 501 })
  }

  const { socket, response } = Deno.upgradeWebSocket(req)

  socket.onopen = () => {
    console.log("Connected to client")
  }

  socket.onmessage = async (event) => {
    try {
      const data = JSON.parse(event.data)
      const { customer_context, context_type, draft_text } = data

      // Generate preview using streaming
      const stream = await openai.chat.completions.create({
        model: Deno.env.get('OPENAI_MODEL'),
        messages: [
          {
            role: "system",
            content: `You are helping preview and edit customer communications.
                     Style: ${customer_context.preferred_style}
                     Type: ${context_type}`
          },
          {
            role: "user", 
            content: `Edit this draft message: ${draft_text}`
          }
        ],
        stream: true
      })

      // Stream suggestions back to client
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