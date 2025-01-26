import { Pinecone, PineconeRecord, ScoredPineconeRecord } from '@pinecone-database/pinecone';

interface TeamMetadata {
  id: string;
  name: string;
  is_active: boolean;
  last_updated: string;
  tags: string[];
  members: Array<{
    user_id: string;
    role: string;
    is_active: boolean;
    last_updated: string;
  }>;
  schedule: Array<{
    user_id: string;
    start_time: string;
    end_time: string;
    is_active: boolean;
    last_updated: string;
  }>;
}

interface UserMetadata {
  id: string;
  organization_id: string;
  last_updated: string;
  knowledge_domains: Array<{
    id: string;
    name: string;
    description: string;
    years_experience: number;
    expertise: string[];
    credentials: string;
    last_updated: string;
  }>;
}

interface ResourceMetadata {
  type: 'team' | 'user';
  organization_id: string;
  team?: TeamMetadata;
  user?: UserMetadata;
  created_at: string;
  [key: string]: any;  // Add index signature for RecordMetadata constraint
}

export type BaseMetadata = {
  content: string;
  created_at: string;
  organization_id?: string;
  tags?: string[];
};

export type TicketMetadata = BaseMetadata & {
  type: 'ticket';
  id: string;
  organization_id: string;
  last_updated: string;
  status: string;
  assigned_to?: string;
  requested_by: string;
  team_id?: string;
  tags: string[];
  priority: string;
  subject: string;
  description: string;
  [key: string]: any;
};

export type CommentMetadata = BaseMetadata & {
  type: 'comment';
  ticket_id: string;
};

export type PineconeMetadata = TicketMetadata | CommentMetadata | ResourceMetadata;

export class PineconeService {
  private client: Pinecone;
  private indexName: string;

  constructor() {
    this.client = new Pinecone({
      apiKey: process.env.PINECONE_API_KEY!
    });
    this.indexName = process.env.PINECONE_INDEX!;
  }

  async upsertEmbedding(
    id: string,
    values: number[],
    metadata: PineconeMetadata
  ): Promise<void> {
    const index = this.client.index(this.indexName);
    
    try {
      await index.upsert([{
        id,
        values,
        metadata
      }]);
    } catch (error) {
      throw new Error('Failed to upsert embedding');
    }
  }

  async queryEmbeddings(
    values: number[],
    filter?: Partial<PineconeMetadata>,
    topK: number = 5
  ): Promise<ScoredPineconeRecord<PineconeMetadata>[]> {
    const index = this.client.index(this.indexName);

    try {
      const queryResponse = await index.query({
        vector: values,
        filter,
        topK,
        includeMetadata: true
      });

      return (queryResponse.matches || []) as ScoredPineconeRecord<PineconeMetadata>[];
    } catch (error) {
      throw new Error('Failed to query embeddings');
    }
  }

  async deleteEmbedding(id: string): Promise<void> {
    const index = this.client.index(this.indexName);
    
    try {
      await index.deleteOne(id);
    } catch (error) {
      throw new Error('Failed to delete embedding');
    }
  }

  async findSimilarTickets(
    embedding: number[],
    organizationId?: string,
    tags?: string[]
  ): Promise<ScoredPineconeRecord<TicketMetadata>[]> {
    const filter: Partial<TicketMetadata> = {
      type: 'ticket'
    };

    if (organizationId) filter.organization_id = organizationId;
    if (tags?.length) filter.tags = tags;

    const results = await this.queryEmbeddings(embedding, filter);
    return results as ScoredPineconeRecord<TicketMetadata>[];
  }

  async findRelevantComments(
    embedding: number[],
    ticketId: string
  ): Promise<ScoredPineconeRecord<CommentMetadata>[]> {
    const results = await this.queryEmbeddings(
      embedding,
      {
        type: 'comment',
        ticket_id: ticketId
      }
    );
    return results as ScoredPineconeRecord<CommentMetadata>[];
  }

  async batchUpsertEmbeddings(
    records: Array<{
      id: string;
      values: number[];
      metadata: PineconeMetadata;
    }>,
    batchSize = 100
  ): Promise<void> {
    const index = this.client.index(this.indexName);
    
    try {
      // Process in batches to avoid rate limits
      for (let i = 0; i < records.length; i += batchSize) {
        const batch = records.slice(i, i + batchSize);
        await index.upsert(batch);
        
        // Optional: Add delay between batches if needed
        if (i + batchSize < records.length) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
    } catch (error) {
      throw new Error(`Failed to batch upsert embeddings: ${error}`);
    }
  }

  async deleteStaleRecords(
    organizationId: string,
    beforeTimestamp: string
  ): Promise<void> {
    const index = this.client.index(this.indexName);
    
    try {
      await index.deleteMany({
        filter: {
          organization_id: { $eq: organizationId },
          last_updated: { $lt: beforeTimestamp }
        }
      });
    } catch (error) {
      throw new Error(`Failed to delete stale records: ${error}`);
    }
  }
}

// Initialize function for the service
export function initPinecone(): PineconeService {
  if (!process.env.PINECONE_API_KEY) {
    throw new Error('PINECONE_API_KEY is not set');
  }
  if (!process.env.PINECONE_ENVIRONMENT) {
    throw new Error('PINECONE_ENVIRONMENT is not set');
  }
  if (!process.env.PINECONE_INDEX) {
    throw new Error('PINECONE_INDEX is not set');
  }

  return new PineconeService();
} 