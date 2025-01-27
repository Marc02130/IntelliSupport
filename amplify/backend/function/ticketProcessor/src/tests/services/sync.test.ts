import { SyncService } from '../../services/sync';
import { SupabaseService } from '../../services/supabase';
import { PineconeService } from '../../services/pinecone';
import { OpenAIService } from '../../services/openai';

jest.mock('../../services/supabase');
jest.mock('../../services/pinecone');
jest.mock('../../services/openai');

describe('SyncService', () => {
  let syncService: SyncService;
  let mockSupabase: jest.Mocked<SupabaseService>;
  let mockPinecone: jest.Mocked<PineconeService>;
  let mockOpenAI: jest.Mocked<OpenAIService>;

  beforeEach(() => {
    mockSupabase = new SupabaseService() as jest.Mocked<SupabaseService>;
    mockPinecone = new PineconeService() as jest.Mocked<PineconeService>;
    mockOpenAI = new OpenAIService() as jest.Mocked<OpenAIService>;
    
    syncService = new SyncService(mockSupabase, mockPinecone, mockOpenAI);
  });

  it('should process pending ticket embeddings', async () => {
    const mockPendingUpdates = [{
      id: 'queue1',
      entity_id: 'ticket1',
      content: 'test content',
      created_at: new Date().toISOString(),
      metadata: {
        type: 'ticket' as const,
        id: 'ticket1',
        organization_id: 'org1',
        last_updated: new Date().toISOString(),
        status: 'open',
        requested_by: 'user1',
        tags: ['test'],
        priority: 'medium',
        subject: 'Test Ticket',
        description: 'test content'
      }
    }];

    mockSupabase.getPendingEmbeddings.mockResolvedValue(mockPendingUpdates);
    mockOpenAI.generateEmbedding.mockResolvedValue([0.1, 0.2, 0.3]);
    mockPinecone.batchUpsertEmbeddings.mockResolvedValue();
    mockSupabase.deletePendingEmbeddings.mockResolvedValue();

    await syncService.syncEmbeddings();

    expect(mockSupabase.getPendingEmbeddings).toHaveBeenCalledWith(100);
    expect(mockOpenAI.generateEmbedding).toHaveBeenCalledWith('test content');
    expect(mockPinecone.batchUpsertEmbeddings).toHaveBeenCalled();
    expect(mockSupabase.deletePendingEmbeddings).toHaveBeenCalledWith(['queue1']);
  });

  it('should process pending team embeddings', async () => {
    const mockPendingUpdates = [{
      id: 'queue2',
      entity_id: 'team1',
      content: 'Backend Team Infrastructure',
      created_at: new Date().toISOString(),
      metadata: {
        type: 'team' as const,
        id: 'team1',
        organization_id: 'org1',
        name: 'Backend Team',
        is_active: true,
        last_updated: new Date().toISOString(),
        tags: ['backend', 'infrastructure'],
        members: [{
          user_id: 'user1',
          role: 'lead',
          is_active: true,
          last_updated: new Date().toISOString()
        }],
        schedule: [{
          user_id: 'user1',
          start_time: '09:00',
          end_time: '17:00',
          is_active: true,
          last_updated: new Date().toISOString()
        }]
      }
    }];

    mockSupabase.getPendingEmbeddings.mockResolvedValue(mockPendingUpdates);
    mockOpenAI.generateEmbedding.mockResolvedValue([0.1, 0.2, 0.3]);
    mockPinecone.batchUpsertEmbeddings.mockResolvedValue();
    mockSupabase.deletePendingEmbeddings.mockResolvedValue();

    await syncService.syncEmbeddings();

    expect(mockSupabase.getPendingEmbeddings).toHaveBeenCalledWith(100);
    expect(mockOpenAI.generateEmbedding).toHaveBeenCalledWith('Backend Team Infrastructure');
    expect(mockPinecone.batchUpsertEmbeddings).toHaveBeenCalled();
    expect(mockSupabase.deletePendingEmbeddings).toHaveBeenCalledWith(['queue2']);
  });
}); 