import { secret } from '@aws-amplify/backend';

export const secrets = {
  openAiKey: secret('OPENAI_API_KEY'),
  pineconeKey: secret('PINECONE_API_KEY'),
  pineconeIndex: secret('PINECONE_INDEX'),
  supabaseKey: secret('SUPABASE_SERVICE_ROLE_KEY')
};