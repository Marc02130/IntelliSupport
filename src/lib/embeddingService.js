import OpenAI from 'openai'
import { supabase } from './supabaseClient'
import { upsertEmbedding, deleteEmbedding } from './pineconeClient'
import { post } from 'aws-amplify/api'

const openai = new OpenAI({
  apiKey: import.meta.env.VITE_OPENAI_API_KEY
})

export async function generateAndStoreEmbedding(content, entityType, entityId) {
  try {
    const response = await post({
      apiName: 'ticketProcessor',
      path: '/process',
      options: {
        body: {
          content,
          entityType,
          entityId
        }
      }
    })
    return response
  } catch (error) {
    console.error('Error calling ticket processor:', error)
    throw error
  }
}

export async function deleteEntityEmbedding(entityType, entityId) {
  try {
    // Get embedding record from Supabase
    const { data: embeddingRecord, error: supabaseError } = await supabase
      .from('embeddings')
      .select('id')
      .match({ entity_type: entityType, entity_id: entityId })
      .single()

    if (supabaseError) throw supabaseError

    // Delete from Pinecone
    await deleteEmbedding(embeddingRecord.id)

    // Delete from Supabase
    const { error: deleteError } = await supabase
      .from('embeddings')
      .delete()
      .match({ id: embeddingRecord.id })

    if (deleteError) throw deleteError
  } catch (error) {
    console.error('Error deleting embedding:', error)
    throw error
  }
} 