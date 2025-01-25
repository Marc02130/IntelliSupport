import { OpenAI } from 'openai'
import { PineconeClient } from '@pinecone-database/pinecone'
import { createClient } from '@supabase/supabase-js'

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
})

const pinecone = new PineconeClient()
await pinecone.init({
  apiKey: process.env.PINECONE_API_KEY,
  environment: process.env.PINECONE_ENVIRONMENT
})

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
)

export const handler = async (event) => {
  try {
    const { body } = event
    const { content, entityType, entityId } = JSON.parse(body)

    // Generate embedding
    const response = await openai.embeddings.create({
      model: "text-embedding-3-small",
      input: content,
      encoding_format: "float"
    })

    const embedding = response.data[0].embedding

    // Store in Supabase
    const { data: embeddingRecord, error: supabaseError } = await supabase
      .from('embeddings')
      .insert({
        entity_type: entityType,
        entity_id: entityId,
        embedding
      })
      .select()
      .single()

    if (supabaseError) throw supabaseError

    // Store in Pinecone
    const index = pinecone.Index(process.env.PINECONE_INDEX)
    await index.upsert({
      vectors: [{
        id: embeddingRecord.id,
        values: embedding,
        metadata: { entity_type: entityType, entity_id: entityId }
      }]
    })

    return {
      statusCode: 200,
      body: JSON.stringify(embeddingRecord)
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    }
  }
} 