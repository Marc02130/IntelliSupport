import { createClient } from '@supabase/supabase-js'
import { Configuration, OpenAIApi } from 'openai'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const openaiKey = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)
const openai = new OpenAIApi(new Configuration({ apiKey: openaiKey }))

Deno.serve(async (req) => {
  if (req.method === 'POST') {
    const { content, entityType, entityId } = await req.json()
    
    try {
      const embedding = await openai.createEmbedding({
        model: "text-embedding-ada-002",
        input: content
      })

      const { error } = await supabase
        .from('embeddings')
        .insert({
          content,
          embedding: embedding.data.data[0].embedding,
          entity_type: entityType,
          entity_id: entityId
        })

      if (error) throw error

      return new Response(JSON.stringify({ success: true }), {
        headers: { 'Content-Type': 'application/json' }
      })
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }
  }
}) 