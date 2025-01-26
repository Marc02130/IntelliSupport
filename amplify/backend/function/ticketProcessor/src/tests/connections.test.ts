import { OpenAI } from 'openai';
import { Pinecone } from '@pinecone-database/pinecone';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.test' });

const isValidOpenAIKey = (key?: string) => {
  return key?.startsWith('sk-') || key?.startsWith('sk-project');
};

describe('Service Connections', () => {
  describe('OpenAI Connection', () => {
    let openai: OpenAI;

    beforeAll(() => {
      const apiKey = process.env.OPENAI_API_KEY;
      if (!isValidOpenAIKey(apiKey)) {
        console.warn('Warning: OpenAI API key should start with "sk-" or "sk-project"');
      }

      openai = new OpenAI({
        apiKey: apiKey
      });
    });

    it('should have valid API key format', () => {
      expect(process.env.OPENAI_API_KEY).toBeDefined();
      expect(isValidOpenAIKey(process.env.OPENAI_API_KEY)).toBeTruthy();
    });

    it('should connect to OpenAI API', async () => {
      if (!isValidOpenAIKey(process.env.OPENAI_API_KEY)) {
        console.warn('Skipping OpenAI connection test due to invalid API key format');
        return;
      }

      try {
        const response = await openai.embeddings.create({
          model: "text-embedding-3-small",
          input: "Hello, World!"
        });
        expect(response.data[0].embedding).toBeDefined();
        expect(response.data[0].embedding.length).toBe(1536);
      } catch (error) {
        console.error('OpenAI Connection Error:', error);
        throw error;
      }
    });
  });

  describe('Pinecone Connection', () => {
    let pinecone: Pinecone;

    beforeAll(() => {
      pinecone = new Pinecone({
        apiKey: process.env.PINECONE_API_KEY!
      });
    });

    it('should have valid configuration', () => {
      expect(process.env.PINECONE_API_KEY).toBeDefined();
      expect(process.env.PINECONE_INDEX).toBeDefined();
    });

    it('should connect to Pinecone API', async () => {
      try {
        const indexList = await pinecone.listIndexes();
        expect(indexList).toBeDefined();
        
        const indexes = indexList.indexes || [];
        expect(indexes.length).toBeGreaterThan(0);
        
        // Log available indexes
        console.log('Available Pinecone indexes:', 
          JSON.stringify({ indexes }, null, 2)
        );

        // Verify our index exists
        const ourIndex = indexes.find(
          index => index.name === process.env.PINECONE_INDEX
        );
        expect(ourIndex).toBeDefined();
        
        if (ourIndex) {
          console.log('Our index configuration:', 
            JSON.stringify(ourIndex, null, 2)
          );
        }
      } catch (error) {
        console.error('Pinecone Connection Error:', error);
        throw error;
      }
    });
  });
}); 