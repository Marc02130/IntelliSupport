import { defineFunction } from '@aws-amplify/backend';
import { Function, Runtime, Code } from 'aws-cdk-lib/aws-lambda';

export const ticketProcessor = defineFunction((scope) => {
  return new Function(scope, 'ticketProcessor', {
    runtime: Runtime.NODEJS_18_X,
    handler: 'index.handler',
    code: Code.fromAsset('./src'),
    environment: {
      OPENAI_API_KEY: process.env.OPENAI_API_KEY ?? '',
      PINECONE_API_KEY: process.env.PINECONE_API_KEY ?? '',
      PINECONE_ENVIRONMENT: process.env.PINECONE_ENVIRONMENT ?? '',
      PINECONE_INDEX: process.env.PINECONE_INDEX ?? '',
      SUPABASE_URL: process.env.SUPABASE_URL ?? '',
      SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''
    }
  });
}); 