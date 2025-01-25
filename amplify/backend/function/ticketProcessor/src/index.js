const { OpenAI } = require('openai')
const { PineconeClient } = require('@pinecone-database/pinecone')
const { createClient } = require('@supabase/supabase-js')

let pinecone = null
let supabase = null
let openai = null

async function initClients() {
  if (!openai) {
    openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    })
  }

  if (!pinecone) {
    pinecone = new PineconeClient()
    await pinecone.init({
      apiKey: process.env.PINECONE_API_KEY,
      environment: process.env.PINECONE_ENVIRONMENT
    })
  }

  if (!supabase) {
    supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    )
  }
}

exports.handler = async (event) => {
  try {
    await initClients()
    
    const { content, entityType, entityId } = JSON.parse(event.body)

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
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
      },
      body: JSON.stringify(embeddingRecord)
    }
  } catch (error) {
    console.error('Error:', error)
    return {
      statusCode: 500,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
      },
      body: JSON.stringify({ error: error.message })
    }
  }
} 