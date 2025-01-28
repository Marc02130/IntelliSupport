import * as dotenv from 'dotenv';
import { dirname } from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: `${__dirname}/.env` });

// Now import and initialize
import { initClients, createComponents } from "./index.js";
import { RunnableSequence } from "@langchain/core/runnables";
import { OpenAIEmbeddings } from "@langchain/openai";
import { SupabaseVectorStore } from "@langchain/community/vectorstores/supabase";

// Initialize clients and get components
const clients = initClients();

// Verify database connection
try {
  const { data, error } = await clients.supabaseClient
    .from('embeddings')
    .select('count')
    .limit(1);

  if (error) {
    console.error('Failed to connect to database:', error);
    process.exit(1);
  }

  console.log('Database connection verified');
} catch (error) {
  console.error('Failed to connect to database:', error);
  process.exit(1);
}

// Now proceed with tests
const { 
  ticketParser, 
  similarTicketRetriever, 
  teamMatcher, 
  workloadAnalyzer, 
  routingRecommender 
} = createComponents(clients);

// Verify environment variables are loaded
console.log('Environment check:');
console.log('DB_URL:', process.env.DB_URL ? 'Set' : 'Not set');
console.log('SERVICE_ROLE_KEY:', process.env.SERVICE_ROLE_KEY ? 'Set' : 'Not set');

async function setupTestData() {
  try {
    // Clean up any existing test data first
    await clients.supabaseClient.from('embeddings')
      .delete()
      .eq('metadata->>organization_id', 'test-org-id')
      .throwOnError();

    // Wait a moment for deletion to complete
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Create test team
    const { data: team1, error: team1Error } = await clients.supabaseClient
      .from('teams')
      .insert({
        name: 'Network Support',
        description: 'Network and infrastructure support team'
      })
      .select()
      .single();

    if (team1Error) {
      console.error('Failed to create team1:', team1Error);
      throw team1Error;
    }

    // Generate embeddings for team and user
    const [teamEmbedding, userEmbedding] = await Promise.all([
      clients.embeddings.embedQuery(`Network support team specializing in VPN and infrastructure`),
      clients.embeddings.embedQuery(`Network infrastructure and VPN specialist`)
    ]);

    // Add team and user metadata to embeddings
    const { error: embeddingError } = await clients.supabaseClient
      .from('embeddings')
      .insert([
        {
          entity_id: team1.id,
          entity_type: 'team',
          content: `Network support team specializing in VPN and infrastructure`,
          metadata: {
            type: 'team',
            id: team1.id,
            name: team1.name,
            tags: ['network', 'infrastructure', 'vpn'],
            members: [{
              role: 'member',
              user_id: 'test-user-1',
              schedule: {
                start_time: '09:00',
                end_time: '17:00'
              },
              knowledge_domains: [{
                domain: 'networking',
                expertise: 'expert'
              }]
            }],
            is_active: true,
            organization_id: 'test-org-id',
            last_updated: new Date().toISOString()
          },
          embedding: teamEmbedding
        },
        {
          entity_id: crypto.randomUUID(),
          entity_type: 'user',
          content: 'Network infrastructure and VPN specialist',
          metadata: {
            type: 'user',
            id: crypto.randomUUID(),
            name: 'Network Expert',
            knowledge_domains: [{
              domain: 'networking',
              expertise: 'expert'
            }],
            is_active: true,
            organization_id: 'test-org-id',
            last_updated: new Date().toISOString()
          },
          embedding: userEmbedding
        }
      ]);

    if (embeddingError) {
      console.error('Failed to create embeddings:', embeddingError);
      throw embeddingError;
    }

    return { team1 };
  } catch (error) {
    console.error('Setup test data failed:', error);
    throw error;
  }
}

async function testTicketRouting() {
  try {
    // Create test ticket
    const testTicket = {
      subject: "VPN Connection Issues",
      description: "Unable to connect to corporate VPN from remote location",
      tags: ["network", "vpn"],
      organization_id: "test-org-id"
    };

    console.log('Starting with ticket:', testTicket);

    // Test each component individually
    console.log('Testing ticketParser...');
    const parsed = await ticketParser.invoke(testTicket);
    console.log('Parsed result:', parsed);

    console.log('Testing similarTicketRetriever...');
    const similar = await similarTicketRetriever.invoke(parsed);
    console.log('Similar tickets:', similar);

    console.log('Testing teamMatcher...');
    const matched = await teamMatcher.invoke(similar);
    console.log('Matched teams:', matched);

    console.log('Testing workloadAnalyzer...');
    const workload = await workloadAnalyzer.invoke(matched);
    console.log('Workload analysis:', workload);

    console.log('Testing routingRecommender...');
    const recommendation = await routingRecommender.invoke(workload);
    console.log('Final recommendation:', recommendation);

  } catch (error: unknown) {
    // Type guard for Error objects
    if (error instanceof Error) {
      console.error('Component test failed:', {
        message: error.message,
        stack: error.stack
      });
    } else {
      console.error('Unknown error:', error);
    }
    throw error;
  }
}

async function cleanupTestData(data: { team1: any }) {
  const { team1 } = data;
  
  // Delete in reverse order of dependencies
  await clients.supabaseClient.from('embedding_queue').delete().eq('entity_id', team1.id);
  await clients.supabaseClient.from('teams').delete().eq('id', team1.id);
}

async function main() {
  let testData;
  try {
    console.log('Setting up test data...');
    testData = await setupTestData();

    console.log('Testing ticket routing...');
    await testTicketRouting();
  } catch (error: unknown) {
    if (error instanceof Error) {
      console.error('Test failed with error:', {
        name: error.name,
        message: error.message,
        stack: error.stack,
        cause: error.cause
      });
    } else {
      console.error('Unknown error:', error);
    }
  } finally {
    if (testData) {
      console.log('Cleaning up test data...');
      await cleanupTestData(testData);
    }
  }
}

main(); 