import { PineconeService } from '../../services/pinecone';
import { Pinecone } from '@pinecone-database/pinecone';

jest.mock('@pinecone-database/pinecone');

describe('PineconeService', () => {
  let pinecone: PineconeService;
  const mockUpsert = jest.fn();
  const mockQuery = jest.fn();
  const mockDeleteMany = jest.fn();
  const mockBatchUpsert = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
    (Pinecone as jest.Mock).mockImplementation(() => ({
      index: () => ({
        upsert: mockUpsert,
        query: mockQuery,
        deleteMany: mockDeleteMany
      })
    }));
    pinecone = new PineconeService();
  });

  it('should upsert team embedding', async () => {
    const teamMetadata = {
      type: 'team' as const,
      organization_id: 'org123',
      team: {
        id: 'team1',
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
      },
      created_at: new Date().toISOString()
    };

    await pinecone.upsertEmbedding('test-id', [0.1, 0.2], teamMetadata);
    expect(mockUpsert).toHaveBeenCalledWith([{
      id: 'test-id',
      values: [0.1, 0.2],
      metadata: teamMetadata
    }]);
  });

  it('should batch upsert embeddings', async () => {
    const records = [
      {
        id: 'test1',
        values: [0.1, 0.2],
        metadata: {
          type: 'team' as const,
          organization_id: 'org123',
          team: {
            id: 'team1',
            name: 'Backend Team',
            is_active: true,
            last_updated: new Date().toISOString(),
            tags: ['backend'],
            members: [],
            schedule: []
          },
          created_at: new Date().toISOString()
        }
      },
      {
        id: 'test2',
        values: [0.3, 0.4],
        metadata: {
          type: 'user' as const,
          organization_id: 'org123',
          user: {
            id: 'user1',
            organization_id: 'org123',
            last_updated: new Date().toISOString(),
            knowledge_domains: [{
              id: 'kd1',
              name: 'Backend',
              description: 'Backend Development',
              years_experience: 5,
              expertise: ['nodejs'],
              credentials: 'AWS Certified',
              last_updated: new Date().toISOString()
            }]
          },
          created_at: new Date().toISOString()
        }
      }
    ];

    await pinecone.batchUpsertEmbeddings(records);
    expect(mockUpsert).toHaveBeenCalledWith(records);
  });

  it('should delete stale records', async () => {
    const organizationId = 'org123';
    const beforeTimestamp = new Date().toISOString();

    await pinecone.deleteStaleRecords(organizationId, beforeTimestamp);
    expect(mockDeleteMany).toHaveBeenCalledWith({
      filter: {
        organization_id: { $eq: organizationId },
        last_updated: { $lt: beforeTimestamp }
      }
    });
  });

  it('should query embeddings', async () => {
    const mockResults = [{
      id: 'test-id',
      score: 0.9,
      metadata: {
        type: 'team',
        organization_id: 'org123',
        team: {
          id: 'team1',
          name: 'Backend Team',
          tags: ['backend']
        },
        created_at: new Date().toISOString()
      }
    }];

    mockQuery.mockResolvedValue({ matches: mockResults });
    const results = await pinecone.queryEmbeddings([0.1, 0.2]);
    
    expect(mockQuery).toHaveBeenCalledWith({
      vector: [0.1, 0.2],
      topK: 5,
      includeMetadata: true
    });
    expect(results).toEqual(mockResults);
  });
}); 