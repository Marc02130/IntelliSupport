import OpenAI from 'openai';
import { OpenAIService } from '../../services/openai';
import { EmbeddingCreateParams, CreateEmbeddingResponse } from 'openai/resources/embeddings';
import { ChatCompletion, ChatCompletionCreateParams } from 'openai/resources/chat';
import { RequestOptions, APIPromise } from 'openai/core';

// Create the mock functions with proper OpenAI typing
const mockEmbeddingsCreate = jest.fn<APIPromise<CreateEmbeddingResponse>, [EmbeddingCreateParams, (RequestOptions | undefined)?]>();
const mockChatCompletionsCreate = jest.fn<APIPromise<ChatCompletion>, [ChatCompletionCreateParams, (RequestOptions | undefined)?]>();

// Mock the OpenAI module
jest.mock('openai', () => ({
  __esModule: true,
  default: jest.fn().mockImplementation(() => ({
    embeddings: {
      create: mockEmbeddingsCreate
    },
    chat: {
      completions: {
        create: mockChatCompletionsCreate
      }
    }
  }))
}));

describe('OpenAIService', () => {
  let openaiService: OpenAIService;
  let mockOpenAI: jest.Mocked<OpenAI>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockOpenAI = {
      embeddings: { create: mockEmbeddingsCreate },
      chat: { completions: { create: mockChatCompletionsCreate } }
    } as unknown as jest.Mocked<OpenAI>;
    (OpenAI as jest.MockedClass<typeof OpenAI>).mockImplementation(() => mockOpenAI);
    openaiService = new OpenAIService();
  });

  describe('generateEmbedding', () => {
    it('should generate embeddings successfully', async () => {
      const mockEmbedding = Array(3072).fill(0.1);
      const mockResponse = {
        data: [{ embedding: mockEmbedding }],
        model: process.env.OPENAI_EMBEDDING_MODEL,
        object: 'list',
        usage: { prompt_tokens: 1, total_tokens: 1 }
      };

      mockOpenAI.embeddings.create = jest.fn().mockImplementation(() => Promise.resolve(mockResponse));

      const result = await openaiService.generateEmbedding('test text');
      expect(result).toEqual(mockEmbedding);
      expect(mockOpenAI.embeddings.create).toHaveBeenCalledWith({
        model: process.env.OPENAI_EMBEDDING_MODEL,
        input: 'test text',
        encoding_format: 'float'
      });
    });

    it('should handle errors gracefully', async () => {
      mockOpenAI.embeddings.create = jest.fn().mockImplementation(() => Promise.reject(new Error('API Error')));
      await expect(openaiService.generateEmbedding('test text'))
        .rejects.toThrow('Failed to generate embedding');
    });
  });

  describe('analyzeTicket', () => {
    it('should analyze tickets successfully', async () => {
      const mockResponse = {
        confidence: 0.8,
        reasoning: 'Test reasoning',
        suggestedTags: ['javascript']
      };

      mockOpenAI.chat.completions.create = jest.fn().mockImplementation(() => 
        Promise.resolve({
          choices: [{ message: { content: JSON.stringify(mockResponse) } }]
        } as ChatCompletion)
      );

      const result = await openaiService.analyzeTicket('Test ticket content');
      expect(result).toEqual(mockResponse);
      expect(mockOpenAI.chat.completions.create).toHaveBeenCalledWith({
        model: expect.any(String),
        messages: expect.any(Array),
        temperature: 0.7
      });
    });

    it('should handle empty responses', async () => {
      mockOpenAI.chat.completions.create = jest.fn().mockImplementation(() => 
        Promise.resolve({
          choices: [{ message: { content: null } }]
        } as ChatCompletion)
      );

      await expect(openaiService.analyzeTicket('Test ticket content'))
        .rejects.toThrow('Empty response from OpenAI');
    });
  });

  describe('generateSummary', () => {
    it('should generate summary successfully', async () => {
      const mockSummary = 'Test summary';
      mockOpenAI.chat.completions.create = jest.fn().mockImplementation(() => 
        Promise.resolve({
          choices: [{ message: { content: mockSummary } }]
        } as ChatCompletion)
      );

      const result = await openaiService.generateSummary('test content');
      expect(result).toBe(mockSummary);
      expect(mockOpenAI.chat.completions.create).toHaveBeenCalledWith({
        model: expect.any(String),
        messages: expect.any(Array),
        temperature: 0.7
      });
    });

    it('should handle empty responses', async () => {
      mockOpenAI.chat.completions.create = jest.fn().mockImplementation(() => 
        Promise.resolve({
          choices: [{ message: { content: '' } }]
        } as ChatCompletion)
      );

      const result = await openaiService.generateSummary('test content');
      expect(result).toBe('');
    });
  });

  describe('suggestResponse', () => {
    it('should suggest response successfully', async () => {
      const mockResponse = 'Suggested response';
      mockOpenAI.chat.completions.create = jest.fn().mockImplementation(() => 
        Promise.resolve({
          choices: [{ message: { content: mockResponse } }]
        } as ChatCompletion)
      );

      const result = await openaiService.suggestResponse(
        'test ticket',
        [{ content: 'similar ticket' }],
        ['javascript']
      );

      expect(result).toBe(mockResponse);
      expect(mockOpenAI.chat.completions.create).toHaveBeenCalledWith({
        model: expect.any(String),
        messages: expect.any(Array),
        temperature: 0.7
      });
    });

    it('should handle errors gracefully', async () => {
      mockOpenAI.chat.completions.create = jest.fn().mockImplementation(() => 
        Promise.reject(new Error('API Error'))
      );

      await expect(openaiService.suggestResponse('test ticket', [], ['javascript']))
        .rejects.toThrow('Failed to suggest response');
    });
  });
});
