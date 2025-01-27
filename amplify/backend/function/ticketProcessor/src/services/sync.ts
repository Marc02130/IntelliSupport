import { SupabaseService } from './supabase';
import { PineconeMetadata, PineconeService } from './pinecone';
import { OpenAIService } from './openai';

interface EmbeddingQueueRecord {
  id: string;
  entity_id: string;
  content: string;
  embedding?: number[];
  metadata: PineconeMetadata;
  created_at: string;
}

export class SyncService {
  constructor(
    private supabase: SupabaseService,
    private pinecone: PineconeService,
    private openai: OpenAIService
  ) {}

  async syncEmbeddings() {
    const pendingUpdates = await this.supabase.getPendingEmbeddings(100);
    
    if (!pendingUpdates?.length) return;

    const embeddings = await Promise.all(
      pendingUpdates.map(async (update: EmbeddingQueueRecord) => {
        // Generate embedding if not already exists
        const values = update.embedding || await this.openai.generateEmbedding(update.content);
        
        // Ensure metadata has required base fields
        const metadata = {
          ...update.metadata,
          content: update.content,
          created_at: update.created_at
        };

        return {
          id: update.entity_id,
          values,
          metadata
        };
      })
    );

    await this.pinecone.batchUpsertEmbeddings(embeddings);
    await this.supabase.deletePendingEmbeddings(pendingUpdates.map(u => u.id));
  }
}
