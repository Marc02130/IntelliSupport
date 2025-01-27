import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Configuration, OpenAIApi } from 'https://esm.sh/openai@4.12.1'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const openaiKey = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)
const openai = new OpenAIApi(new Configuration({ apiKey: openaiKey }))

Deno.serve(async (req) => {
  try {
    // Get pending items from queue (limit batch size)
    const { data: queueItems, error: fetchError } = await supabase
      .from('embedding_queue')
      .select('*')
      .limit(50)  // Process in batches

    if (fetchError) throw fetchError
    if (!queueItems?.length) {
      return new Response(JSON.stringify({ message: 'No items to process' }))
    }

    // Process each queue item
    for (const item of queueItems) {
      try {
        // Generate embedding
        const embedding = await openai.createEmbedding({
          model: "text-embedding-ada-002",
          input: item.content
        })

        // Store embedding
        const { error: insertError } = await supabase
          .from('embeddings')
          .insert({
            content: item.content,
            embedding: embedding.data.data[0].embedding,
            entity_type: item.metadata.type,
            entity_id: item.entity_id,
            metadata: item.metadata
          })

        if (insertError) throw insertError

        // Remove from queue after successful processing
        const { error: deleteError } = await supabase
          .from('embedding_queue')
          .delete()
          .match({ id: item.id })

        if (deleteError) throw deleteError

      } catch (error) {
        console.error(`Error processing queue item ${item.id}:`, error)
        // Continue with next item even if one fails
      }
    }

    return new Response(JSON.stringify({ 
      success: true, 
      processed: queueItems.length 
    }))

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500
    })
  }
}) 