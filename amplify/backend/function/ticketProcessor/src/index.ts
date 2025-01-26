import { OpenAIService } from './services/openai';
import { PineconeService } from './services/pinecone';
import { SupabaseService } from './services/supabase';
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { defineFunction } from '@aws-amplify/backend';
import { Function, Runtime, Code } from 'aws-cdk-lib/aws-lambda';

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const openai = new OpenAIService();
    const pinecone = new PineconeService();
    const supabase = new SupabaseService();

    const { content, entityType, entityId } = JSON.parse(event.body || '{}');

    // Generate embedding
    const embedding = await openai.generateEmbedding(content);

    // Store embedding in Pinecone
    await pinecone.upsertEmbedding(entityId, embedding, {
      type: entityType,
      content,
      organization_id: event.requestContext.authorizer?.claims?.['custom:organization_id'] || '',
      created_at: new Date().toISOString()
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ success: true })
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to process ticket' })
    };
  }
};

export const ticketProcessor = defineFunction((scope) => {
  return new Function(scope, 'ticketProcessor', {
    runtime: Runtime.NODEJS_18_X,
    handler: 'index.handler',
    code: Code.fromAsset('./src'),
    environment: {
      PINECONE_ENVIRONMENT: process.env.PINECONE_ENVIRONMENT ?? '',
      PINECONE_INDEX: process.env.PINECONE_INDEX ?? '',
      SUPABASE_URL: process.env.SUPABASE_URL ?? ''
    }
  });
}); 