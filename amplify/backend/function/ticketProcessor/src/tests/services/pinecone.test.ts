import { PineconeService, type PineconeMetadata } from '../../services/pinecone';
import { Pinecone } from '@pinecone-database/pinecone';

// Create mock index methods
const mockUpsert = jest.fn();
const mockQuery = jest.fn();
const mockDeleteOne = jest.fn();

// Create mock index
const mockIndexMethods = {
  upsert: mockUpsert,
  query: mockQuery,
  deleteOne: mockDeleteOne
};

// Mock the Pinecone class
jest.mock('@pinecone-database/pinecone', () => {
  const MockPineconeClass = function(this: any) {
    this.index = jest.fn().mockReturnValue(mockIndexMethods);
    this.listIndexes = jest.fn();
    return this;
  };
  return { Pinecone: MockPineconeClass };
});

describe('PineconeService', () => {
  let pineconeService: PineconeService;

  beforeEach(() => {
    jest.clearAllMocks();
    pineconeService = new PineconeService();
  });

  describe('upsertEmbedding', () => {
    it('should upsert embedding successfully', async () => {
      const mockId = 'test-id';
      const mockValues = Array(1536).fill(0.1);
      const mockMetadata: PineconeMetadata = {
        type: 'ticket',
        content: 'test content',
        created_at: new Date().toISOString()
      };

      await pineconeService.upsertEmbedding(mockId, mockValues, mockMetadata);
      
      expect(mockUpsert).toHaveBeenCalledWith([{
        id: mockId,
        values: mockValues,
        metadata: mockMetadata
      }]);
    });

    it('should handle upsert errors', async () => {
      mockUpsert.mockRejectedValueOnce(new Error('API Error'));

      await expect(
        pineconeService.upsertEmbedding('test-id', [], {
          type: 'ticket',
          content: 'test',
          created_at: new Date().toISOString()
        })
      ).rejects.toThrow('Failed to upsert embedding');
    });
  });

  describe('queryEmbeddings', () => {
    it('should query embeddings successfully', async () => {
      const mockMatches = [{
        id: 'test-id',
        score: 0.9,
        values: [],
        metadata: {
          type: 'ticket' as const,
          content: 'test content',
          created_at: new Date().toISOString()
        }
      }];

      mockQuery.mockResolvedValueOnce({ matches: mockMatches });

      const result = await pineconeService.queryEmbeddings(Array(1536).fill(0.1));
      expect(result).toEqual(mockMatches);
    });

    it('should handle empty results', async () => {
      mockQuery.mockResolvedValueOnce({ matches: [] });

      const result = await pineconeService.queryEmbeddings(Array(1536).fill(0.1));
      expect(result).toEqual([]);
    });
  });

  describe('findSimilarTickets', () => {
    it('should find similar tickets with filters', async () => {
      const mockEmbedding = Array(1536).fill(0.1);
      const mockOrgId = 'org-123';
      const mockTags = ['javascript', 'react'];

      mockQuery.mockResolvedValueOnce({ matches: [] });

      await pineconeService.findSimilarTickets(mockEmbedding, mockOrgId, mockTags);

      expect(mockQuery).toHaveBeenCalledWith({
        vector: mockEmbedding,
        filter: {
          type: 'ticket',
          organization_id: mockOrgId,
          tags: mockTags
        },
        topK: 5,
        includeMetadata: true
      });
    });
  });
}); 