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

    // Store embedding using service method
    const embeddingRecord = await supabase.storeEmbedding({
      entity_type: entityType,
      entity_id: entityId,
      embedding
    });

    // Store in Pinecone with metadata
    await pinecone.upsertEmbedding(
      embeddingRecord.id,
      embedding,
      {
        type: entityType,
        content,
        created_at: new Date().toISOString()
      }
    );

    return {
      statusCode: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
      },
      body: JSON.stringify(embeddingRecord)
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
      },
      body: JSON.stringify({ error: (error as Error).message })
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