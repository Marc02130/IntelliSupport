import { supabase } from './supabaseClient'

export async function generateAndStoreEmbedding(content, entityType, entityId) {
  try {
    const { data, error } = await supabase.functions.invoke('process-embeddings', {
      body: {
        content,
        entityType,
        entityId
      }
    })
    
    if (error) throw error
    return data
  } catch (error) {
    console.error('Error processing embedding:', error)
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