import { Pinecone, PineconeRecord, ScoredPineconeRecord } from '@pinecone-database/pinecone';

export type BaseMetadata = {
  content: string;
  created_at: string;
  organization_id?: string;
  tags?: string[];
};

export type TicketMetadata = BaseMetadata & {
  type: 'ticket';
};

export type CommentMetadata = BaseMetadata & {
  type: 'comment';
  ticket_id: string;
};

export type PineconeMetadata = TicketMetadata | CommentMetadata;

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