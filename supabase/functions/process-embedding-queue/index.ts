import { createClient } from "@supabase/supabase-js"
import { OpenAI } from "openai"
import { PineconeClient } from "@pinecone-database/pinecone"

// Add startup logging at the very top
console.log("[STARTUP] Function loading:", {
  timestamp: new Date().toISOString(),
  function: 'process-embedding-queue'
})

// Add debug logging
console.log("[Info] Environment check:", {
  PINECONE_API_KEY: !!Deno.env.get('PINECONE_API_KEY'),
  PINECONE_ENVIRONMENT: Deno.env.get('PINECONE_ENVIRONMENT'),
  PINECONE_INDEX: Deno.env.get('PINECONE_INDEX'),
  PINECONE_PROJECT_ID: Deno.env.get('PINECONE_PROJECT_ID')
})

// Initialize clients with try-catch
let supabase;
try {
  supabase = createClient(
    Deno.env.get('DB_URL') ?? '',
    Deno.env.get('SERVICE_ROLE_KEY') ?? ''
  )
  console.log("[Info] Supabase client initialized")
} catch (err) {
  console.error("[Error] Failed to initialize Supabase:", err)
  throw err
}

// Add version logging
console.log('OpenAI client version:', OpenAI.version)

// Initialize with more error handling
const openai = new OpenAI({ 
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

// Test the API key early with more detailed error logging
try {
  console.log('Testing OpenAI connection...')
  const models = await openai.models.list()
  console.log('OpenAI connection successful')
} catch (error) {
  console.error('OpenAI initialization error:', {
    message: error.message,
    status: error.status,
    response: error.response?.data,
    key: Deno.env.get('OPENAI_API_KEY')?.substring(0, 15) + '...'  // Log key prefix for debugging
  })
  throw error
}

// Initialize Pinecone with error handling
try {
  const pinecone = new PineconeClient()
  await pinecone.init({
    apiKey: Deno.env.get('PINECONE_API_KEY') ?? '',
    environment: Deno.env.get('PINECONE_ENVIRONMENT') ?? ''
  })
  
  // Remove the test connection that's causing issues
  console.log("[Info] Pinecone initialized with host:", Deno.env.get('PINECONE_HOST'))
  
} catch (err) {
  console.error("[Error] Failed to initialize Pinecone:", err)
  throw err
}

// Add rate limiting helper
const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

// Add error types
const isQuotaError = (error: any) => 
  error.message.includes('exceeded your current quota')

const isRateLimitError = (error: any) => 
  error.message.includes('429') && !isQuotaError(error)

// Update retry helper
async function withRetry<T>(
  operation: () => Promise<T>, 
  retries = 3, 
  delay = 1000
): Promise<T> {
  try {
    return await operation()
  } catch (error) {
    if (retries > 0 && isRateLimitError(error)) {
      console.log(`Rate limited, retrying in ${delay}ms...`)
      await sleep(delay)
      return withRetry(operation, retries - 1, delay * 2)
    }
    if (isQuotaError(error)) {
      console.error('OpenAI quota exceeded - please check billing')
      throw new Error('OpenAI quota exceeded')
    }
    throw error
  }
}

// Add Pinecone retry helper
async function withPineconeRetry<T>(
  operation: () => Promise<T>,
  retries = 3,
  delay = 1000
): Promise<T> {
  try {
    return await operation()
  } catch (error) {
    if (retries > 0) {
      console.log(`Pinecone error, retrying in ${delay}ms...`, error.message)
      await sleep(delay)
      return withPineconeRetry(operation, retries - 1, delay * 2)
    }
    throw error
  }
}

// Process in smaller batches
const BATCH_SIZE = 10 // Process fewer items at once

// Add type definitions from pinecone.ts
interface TeamMetadata {
  id: string;
  name: string;
  is_active: boolean;
  last_updated: string;
  tags: string[];
  // ... other team fields
}

interface UserMetadata {
  id: string;
  organization_id: string;
  last_updated: string;
  // ... other user fields
}

type BaseMetadata = {
  content: string;
  created_at: string;
  organization_id?: string;
  tags?: string[];
};

type TicketMetadata = BaseMetadata & {
  type: 'ticket';
  id: string;
  // ... other ticket fields
};

type PineconeMetadata = TicketMetadata | CommentMetadata | ResourceMetadata;

// Add metadata cleaning helper
function cleanMetadata(metadata: any): any {
  const cleaned: any = {}
  for (const [key, value] of Object.entries(metadata)) {
    if (value !== null && value !== undefined) {
      if (typeof value === 'object' && !Array.isArray(value)) {
        cleaned[key] = cleanMetadata(value)
      } else {
        cleaned[key] = value
      }
    }
  }
  return cleaned
}

// Add metadata formatting for Pinecone
function formatPineconeMetadata(metadata: any): any {
  const formatted: any = {}
  
  for (const [key, value] of Object.entries(metadata)) {
    if (value === null || value === undefined) continue

    if (key === 'knowledge_domains') {
      // Convert knowledge domains to array of strings
      formatted[key] = value.map((kd: any) => 
        `${kd.domain}:${kd.expertise}`
      )
    }
    else if (key === 'comments') {
      // Convert comments to array of strings
      formatted[key] = value.map((c: any) => c.content)
    }
    else if (key === 'members') {
      // Extract member knowledge domains
      formatted.member_domains = value.flatMap((m: any) => 
        m.knowledge_domains.map((kd: any) => 
          `${kd.domain}:${kd.expertise}`
        )
      )
      // Extract member IDs
      formatted.member_ids = value.map((m: any) => m.user_id)
    }
    else if (Array.isArray(value)) {
      // Keep arrays of primitives
      formatted[key] = value
    }
    else if (typeof value === 'object') {
      // Skip nested objects
      continue
    }
    else {
      // Keep primitives
      formatted[key] = value
    }
  }
  
  return formatted
}

// Update upsertToPinecone function
async function upsertToPinecone(vector: {
  id: string;
  values: number[];
  metadata: PineconeMetadata;
}) {
  try {
    const host = Deno.env.get('PINECONE_HOST')
    const formattedMetadata = formatPineconeMetadata(vector.metadata)
    
    const body = {
      vectors: [{
        id: vector.id,
        values: vector.values,
        metadata: formattedMetadata
      }]
    }
    
    console.log('Pinecone request:', {
      url: `https://${host}/vectors/upsert`,
      vectorId: vector.id,
      valuesLength: vector.values.length,
      metadata: formattedMetadata
    })

    const response = await fetch(
      `https://${host}/vectors/upsert`,
      {
        method: 'POST',
        headers: {
          'Api-Key': Deno.env.get('PINECONE_API_KEY') ?? '',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body)
      }
    )

    if (!response.ok) {
      const errorData = await response.json()
      throw new Error(`HTTP error! status: ${response.status}, details: ${JSON.stringify(errorData)}`)
    }
    return await response.json()

  } catch (error) {
    console.error('Pinecone upsert error:', {
      message: error.message,
      vector: vector.id
    })
    throw error
  }
}

// Add request logging
Deno.serve(async (req) => {
  console.log("[REQUEST] Received request:", {
    timestamp: new Date().toISOString(),
    method: req.method,
    url: req.url
  })
  
  try {
    console.log('Function started')
    
    // Get pending items from queue
    const { data: queueItems, error: fetchError } = await supabase
      .from('embedding_queue')
      .select('*')
      .limit(50)

    console.log('Queue items found:', queueItems?.length || 0)
    if (fetchError) throw fetchError
    if (!queueItems?.length) {
      return new Response(JSON.stringify({ message: 'No items to process' }))
    }

    // Process each queue item
    for (const item of queueItems) {
      try {
        console.log('Processing item:', item.id)
        
        // Generate embedding with retry using env model
        const embedding = await withRetry(async () => {
          await sleep(200)
          console.log('Generating embedding for content:', item.content.substring(0, 100) + '...')
          const result = await openai.embeddings.create({
            model: Deno.env.get('OPENAI_EMBEDDING_MODEL') ?? 'text-embedding-ada-002',
            input: item.content
          })
          console.log('Embedding generated successfully:', {
            model: Deno.env.get('OPENAI_EMBEDDING_MODEL'),
            dimensions: result.data[0].embedding.length
          })
          return result
        })

        // Store in Pinecone
        await upsertToPinecone({
          id: `${item.metadata.type}_${item.entity_id}`,
          values: embedding.data[0].embedding,
          metadata: item.metadata
        })
        console.log('Stored in Pinecone')

        // Store in Supabase and remove from queue in a single transaction
        const { error: dbError } = await supabase.rpc('process_embedding', {
          p_content: item.content,
          p_embedding: embedding.data[0].embedding,
          p_entity_type: item.metadata.type,
          p_entity_id: item.entity_id,
          p_metadata: item.metadata,
          p_queue_id: item.id
        })
        
        if (dbError) throw dbError
        console.log('Processed in database')

      } catch (error) {
        console.error('Error processing item:', {
          itemId: item.id,
          error: error.message,
          response: error.response?.data
        })
      }
    }

    return new Response(JSON.stringify({ 
      success: true,
      processed: queueItems.length 
    }))

  } catch (error) {
    console.error('Function error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500
    })
  }
})