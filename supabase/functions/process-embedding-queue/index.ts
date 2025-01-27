import { createClient } from '@supabase/supabase-js'
import { Configuration, OpenAIApi } from 'openai'
import { PineconeClient } from '@pinecone-database/pinecone'

// Initialize clients
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

const openai = new OpenAIApi(
  new Configuration({ 
    apiKey: Deno.env.get('OPENAI_API_KEY') 
  })
)

const pinecone = new PineconeClient()
await pinecone.init({
  environment: Deno.env.get('PINECONE_ENVIRONMENT') ?? '',
  apiKey: Deno.env.get('PINECONE_API_KEY') ?? ''
})

// Serve function
Deno.serve(async (req) => {
  try {
    console.log('Function started')
    console.log('Environment check:', {
      hasSupabaseUrl: !!Deno.env.get('SUPABASE_URL'),
      hasSupabaseKey: !!Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
      hasOpenAI: !!Deno.env.get('OPENAI_API_KEY'),
      hasPinecone: !!Deno.env.get('PINECONE_API_KEY')
    })

    // Get pending items from queue (limit batch size)
    const { data: queueItems, error: fetchError } = await supabase
      .from('embedding_queue')
      .select('*')
      .limit(50)  // Process in batches

    console.log('Queue items:', queueItems?.length || 0)
    console.log('Processing queue items:', queueItems?.length || 0)
    console.log('Sample item:', queueItems?.[0])
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

        // Store in Pinecone
        const index = pinecone.Index(item.metadata.type)
        await index.upsert({
          vectors: [{
            id: `${item.metadata.type}_${item.entity_id}`,
            values: embedding.data.data[0].embedding,
            metadata: item.metadata
          }]
        })

        // Store reference in Supabase
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