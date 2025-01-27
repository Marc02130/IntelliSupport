import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import OpenAI from 'https://esm.sh/openai@4.24.1'
import { PineconeClient } from 'https://esm.sh/@pinecone-database/pinecone@1.1.3'

// Add environment variable check at start
console.log('Environment check:', {
    PINECONE_API_KEY: !!Deno.env.get('PINECONE_API_KEY'),
    PINECONE_ENVIRONMENT: Deno.env.get('PINECONE_ENVIRONMENT'),
    PINECONE_INDEX: Deno.env.get('PINECONE_INDEX'),
    PINECONE_PROJECT_ID: Deno.env.get('PINECONE_PROJECT_ID')
  })
  
// Initialize clients
const supabase = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? ''
)

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

const pinecone = new PineconeClient()
await pinecone.init({
  apiKey: Deno.env.get('PINECONE_API_KEY') ?? '',
  environment: Deno.env.get('PINECONE_ENVIRONMENT') ?? '',
  fetchOptions: {
    timeout: 10000,
    headers: {
      'Content-Type': 'application/json'
    }
  }
})

// Test basic fetch to Pinecone
try {
  console.log('Testing Pinecone connection...')
  const host = Deno.env.get('PINECONE_HOST')
  console.log('Pinecone host:', host)
  
  const response = await fetch(
    `https://${host}/describe_index_stats`,
    {
      method: 'GET',
      headers: {
        'Api-Key': Deno.env.get('PINECONE_API_KEY') ?? '',
        'Accept': 'application/json',
      }
    }
  )
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }
  const data = await response.json()
  console.log('Pinecone connection test response:', data)
} catch (error) {
  console.error('Pinecone fetch test error:', {
    message: error.message,
    cause: error.cause,
    status: error.status
  })
  throw error
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

// Update upsertToPinecone function
async function upsertToPinecone(vector: {
  id: string;
  values: number[];
  metadata: PineconeMetadata;
}) {
  try {
    const host = Deno.env.get('PINECONE_HOST')
    const body = {
      vectors: [{
        id: vector.id,
        values: vector.values,
        metadata: cleanMetadata(vector.metadata)  // Clean metadata
      }]
    }
    
    console.log('Pinecone request:', {
      url: `https://${host}/vectors/upsert`,
      vectorId: vector.id,
      valuesLength: vector.values.length,
      metadata: body.vectors[0].metadata  // Log cleaned metadata
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

// Serve function
Deno.serve(async (req) => {
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
          return await openai.embeddings.create({
            model: Deno.env.get('OPENAI_EMBEDDING_MODEL') ?? 'text-embedding-ada-002',
            input: item.content
          })
        })
        console.log('Generated embedding with model:', Deno.env.get('OPENAI_EMBEDDING_MODEL'))

        // Store in Pinecone
        await upsertToPinecone({
          id: `${item.metadata.type}_${item.entity_id}`,
          values: embedding.data[0].embedding,
          metadata: item.metadata
        })
        console.log('Stored in Pinecone')

        // Store in Supabase and remove from queue
        await supabase.from('embeddings').insert({
          content: item.content,
          embedding: embedding.data[0].embedding,
          entity_type: item.metadata.type,
          entity_id: item.entity_id,
          metadata: item.metadata
        })
        console.log('Stored in Supabase')

        await supabase.from('embedding_queue').delete().match({ id: item.id })
        console.log('Removed from queue')

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