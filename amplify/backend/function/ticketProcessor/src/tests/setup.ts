import dotenv from 'dotenv';

// Load test environment variables
dotenv.config({ path: '.env.test' });

// Validate OpenAI API key format
const isValidOpenAIKey = (key?: string) => {
  return key?.startsWith('sk-') || key?.startsWith('sk-proj');
};

const openaiKey = process.env.OPENAI_API_KEY;
if (!isValidOpenAIKey(openaiKey)) {
  console.warn('Warning: OpenAI API key should start with "sk-" or "sk-proj"');
}

// Set default test environment variables if not provided
process.env = {
  ...process.env,
  OPENAI_API_KEY: openaiKey,
  PINECONE_API_KEY: process.env.PINECONE_API_KEY,
  PINECONE_INDEX: process.env.PINECONE_INDEX
}; 

// Validate required environment variables
const requiredEnvVars = ['OPENAI_API_KEY', 'PINECONE_API_KEY', 'PINECONE_INDEX'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
} 