import { OpenAIService } from '../../services/openai';
import { PineconeService } from '../../services/pinecone';
import { SupabaseService } from '../../services/supabase';
import dotenv from 'dotenv';

// Load test environment variables
dotenv.config({ path: '.env.test' });

describe('Embedding Integration', () => {
  const openai = new OpenAIService();
  const pinecone = new PineconeService();
  const supabase = new SupabaseService();

  // Increase timeout to 10 seconds
  it('should generate and store embeddings in Pinecone', async () => {
    const testContent = "This is a test ticket about a JavaScript error";
    
    // Generate embedding with OpenAI
    const embedding = await openai.generateEmbedding(testContent);
    expect(embedding).toBeDefined();
    expect(embedding.length).toBe(3072); // text-embedding-3-large dimensions
    
    // Store in Pinecone with proper metadata
    await pinecone.upsertEmbedding(
      'test-ticket-123',
      embedding,
      {
        type: 'ticket',
        content: testContent,
        created_at: new Date().toISOString()
      }
    );

    // Add delay to allow Pinecone to index
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Query to verify storage
    const results = await pinecone.queryEmbeddings(embedding, { type: 'ticket' }, 1);
    expect(results.length).toBeGreaterThan(0);
    expect(results[0].metadata?.content).toBe(testContent);
  }, 10000); // 10 second timeout

  it('should process a ticket and store routing history', async () => {
    const testContent = "This is a test ticket about a JavaScript error";
    
    // Get existing IDs
    const agentId = await supabase.getTestAgent();
    const ticketId = await supabase.getTestTicket();
    
    // Generate embedding with OpenAI
    const embedding = await openai.generateEmbedding(testContent);
    
    // Store in Pinecone with proper metadata
    await pinecone.upsertEmbedding(
      ticketId,
      embedding,
      {
        type: 'ticket',
        content: testContent,
        created_at: new Date().toISOString()
      }
    );

    // Store routing decision in Supabase using existing agent
    const routingHistory = await supabase.storeRoutingHistory({
      ticket_id: ticketId,
      assigned_to: agentId,
      confidence_score: 0.95,
      routing_factors: {
        domain_match: 0.8,
        workload: 0.9
      }
    });

    expect(routingHistory).toBeDefined();
    expect(routingHistory.confidence_score).toBe(0.95);
  });

  // Clean up after all tests
  afterAll(async () => {
    await pinecone.deleteEmbedding('test-ticket-123');
  });
}); 