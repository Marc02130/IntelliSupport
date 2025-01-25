import { PineconeClient } from '@pinecone-database/pinecone'

const PINECONE_API_KEY = import.meta.env.VITE_PINECONE_API_KEY
const PINECONE_ENVIRONMENT = import.meta.env.VITE_PINECONE_ENVIRONMENT
const PINECONE_INDEX = import.meta.env.VITE_PINECONE_INDEX

let pinecone = null

export async function initPinecone() {
  if (!pinecone) {
    pinecone = new PineconeClient()
    await pinecone.init({
      apiKey: PINECONE_API_KEY,
      environment: PINECONE_ENVIRONMENT,
    })
  }
  return pinecone
}

export async function upsertEmbedding(id, values, metadata = {}) {
  const client = await initPinecone()
  const index = client.Index(PINECONE_INDEX)

  await index.upsert({
    vectors: [{
      id,
      values,
      metadata
    }]
  })
}

export async function queryEmbeddings(values, topK = 5) {
  const client = await initPinecone()
  const index = client.Index(PINECONE_INDEX)

  const results = await index.query({
    vector: values,
    topK,
    includeMetadata: true
  })

  return results.matches
}

export async function deleteEmbedding(id) {
  const client = await initPinecone()
  const index = client.Index(PINECONE_INDEX)

  await index.delete1({
    ids: [id]
  })
} 