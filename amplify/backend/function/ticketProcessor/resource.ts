import { defineFunction, secret } from '@aws-amplify/backend';

export const ticketProcessor = defineFunction({
  entry: './src/index.ts',
  environment: {
    PINECONE_INDEX: process.env.PINECONE_INDEX ?? '',
    PINECONE_ENVIRONMENT: process.env.PINECONE_ENVIRONMENT ?? '',
    PINECONE_API_KEY: secret('PINECONE_API_KEY'),
    OPENAI_API_KEY: secret('OPENAI_API_KEY'),
    SUPABASE_URL: process.env.SUPABASE_URL ?? '',
    SUPABASE_SERVICE_ROLE_KEY: secret('SUPABASE_SERVICE_ROLE_KEY'),
    AWS_REGION: process.env.AWS_REGION || 'us-west-2'
  },
  timeoutSeconds: 60,
  schedule: 'every 15m'
});
