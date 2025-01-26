import { Pinecone, Index } from '@pinecone-database/pinecone';
import { secrets } from '../../../../secrets';

async function createPineconeIndex() {
  try {
    const PINECONE_API_KEY = process.env[secrets.pineconeKey.toString()];
    const PINECONE_INDEX_NAME = process.env.PINECONE_INDEX;

    if (!PINECONE_API_KEY || !PINECONE_INDEX_NAME) {
      throw new Error('Missing required Pinecone configuration');
    }

    const pinecone = new Pinecone({
      apiKey: PINECONE_API_KEY
    });

    // Check if index already exists
    const existingIndexes = await pinecone.listIndexes();
    
    if (existingIndexes.indexes?.find(index => index.name === PINECONE_INDEX_NAME)) {
      console.log(`Index ${PINECONE_INDEX_NAME} already exists`);
      return;
    }

    // Create the index
    console.log(`Creating index ${PINECONE_INDEX_NAME}...`);
    await pinecone.createIndex({
      name: PINECONE_INDEX_NAME,
      dimension: 1536,
      metric: 'cosine',
      spec: {
        serverless: {
          cloud: 'aws',
          region: process.env.AWS_REGION || 'us-west-2'
        }
      }
    });

    console.log('Waiting for index to be ready...');
    await waitForIndexReady(pinecone, PINECONE_INDEX_NAME);
    
    console.log('Index created successfully!');

  } catch (error) {
    console.error('Error creating Pinecone index:', error);
    process.exit(1);
  }
}

async function waitForIndexReady(
  pinecone: Pinecone,
  indexName: string,
  maxAttempts = 60
): Promise<void> {
  for (let i = 0; i < maxAttempts; i++) {
    const index = await pinecone.describeIndex(indexName);
    if (index.status?.ready) {
      return;
    }
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  throw new Error('Timeout waiting for index to be ready');
}

// Run the script
createPineconeIndex(); 