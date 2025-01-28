import { RunnableSequence, RunnablePassthrough } from "@langchain/core/runnables";
import { SupabaseVectorStore } from "@langchain/community/vectorstores/supabase";
import { OpenAIEmbeddings } from "@langchain/openai";
import { createClient } from "@supabase/supabase-js";
import { Document } from "@langchain/core/documents";
import type {
  Ticket,
  TicketContext,
  Team,
  TeamMatchResult,
  WorkloadResult,
  RoutingResult,
  Context,
  TicketMetadata,
  TeamMetadata,
  EntityMetadata,
  UserMetadata
} from "./types.ts";

// Export types
export type { 
  Ticket,
  TicketContext,
  Team,
  TeamMatchResult,
  WorkloadResult,
  RoutingResult
};

// Add types for initialized clients
export interface Clients {
  supabaseClient: any;  // Replace with proper type
  embeddings: OpenAIEmbeddings;
  vectorStore: SupabaseVectorStore;
}

// Helper function to extract domains from text
function extractDomainsFromText(text: string): Set<string> {
  const domains = new Set<string>();
  const lowercaseText = text.toLowerCase();

  const domainKeywords = {
    'networking': ['network', 'router', 'switch', 'firewall', 'vpn'],
    'security': ['security', 'vulnerability', 'breach', 'encryption', 'password'],
    'database': ['database', 'sql', 'query', 'table', 'schema'],
  };

  Object.entries(domainKeywords).forEach(([domain, keywords]) => {
    if (keywords.some(keyword => lowercaseText.includes(keyword))) {
      domains.add(domain);
    }
  });

  return domains;
}

// Export initialization function
export function initClients(): Clients {
  const supabaseClient = createClient(
    (globalThis as any).Deno?.env.get("SUPABASE_URL") || process.env.DB_URL!,
    (globalThis as any).Deno?.env.get("SUPABASE_SERVICE_ROLE_KEY") || process.env.SERVICE_ROLE_KEY!
  );

  const embeddings = new OpenAIEmbeddings({
    openAIApiKey: (globalThis as any).Deno?.env.get("OPENAI_API_KEY") || process.env.OPENAI_API_KEY,
    modelName: (globalThis as any).Deno?.env.get("OPENAI_EMBEDDING_MODEL") || process.env.OPENAI_EMBEDDING_MODEL
  });

  const vectorStore = new SupabaseVectorStore(embeddings, {
    client: supabaseClient,
    tableName: "embeddings",
  });

  return { supabaseClient, embeddings, vectorStore };
}

// Create and export components factory
export function createComponents(clients: Clients) {
  const { supabaseClient, embeddings, vectorStore } = clients;

  // 1. Parse and prepare ticket data
  const ticketParser = RunnableSequence.from([
    new RunnablePassthrough(),
    async (ticket: Ticket): Promise<TicketContext> => {
      return {
        ticket,
        similarTickets: [],
        relevantTeams: [],
        agentWorkloads: []
      };
    }
  ]);

  // 2. Find similar tickets
  const similarTicketRetriever = RunnableSequence.from([
    new RunnablePassthrough(),
    async (context: TicketContext) => {
      const { ticket } = context;
      const searchText = `${ticket.subject} ${ticket.description}`;
      
      const similarTickets = await vectorStore.similaritySearch(searchText, 5, {
        filter: (doc: Document<EntityMetadata>) => 
          doc.metadata.type === 'ticket',
        query: `
          WITH latest_ticket_embeddings AS (
            SELECT DISTINCT ON (entity_id)
              id, content, embedding, entity_type, entity_id, metadata, created_at
            FROM embeddings
            WHERE entity_type = 'ticket'
            ORDER BY entity_id, created_at DESC
          )
          SELECT * FROM latest_ticket_embeddings
        `
      });

      return { ...context, similarTickets };
    }
  ]);

  // 3. Find and score relevant teams and users
  const teamMatcher = RunnableSequence.from([
    new RunnablePassthrough(),
    async (context: TicketContext): Promise<TeamMatchResult> => {
      const { ticket } = context;
      const searchText = `${ticket.subject} ${ticket.description}`;

      // Get team and user embeddings
      const [teamResults, userResults] = await Promise.all([
        vectorStore.similaritySearchWithScore(searchText, 5, {
          filter: (doc: Document<EntityMetadata>) => {
            const metadata = doc.metadata;
            return metadata.type === 'team' && metadata.is_active === true;
          }
        }),
        vectorStore.similaritySearchWithScore(searchText, 5, {
          filter: (doc: Document<EntityMetadata>) => {
            const metadata = doc.metadata;
            return metadata.type === 'user' && metadata.is_active === true;
          }
        })
      ]);

      console.log('Team results:', JSON.stringify(teamResults, null, 2));
      console.log('User results:', JSON.stringify(userResults, null, 2));

      // Filter and convert teams to AssigneeMatch
      const teamAssignees = teamResults
        .filter(([result]) => result.metadata.type === 'team')  // Extra type check
        .map(([result, similarity]) => {
          const metadata = result.metadata as TeamMetadata;
          let score = 0;

          // 1. Tag matching (30%)
          if (metadata.tags) {  // Add null check
            const matchingTags = metadata.tags.filter(tag => 
              ticket.tags.includes(tag)
            );
            score += (matchingTags.length / Math.max(metadata.tags.length, ticket.tags.length)) * 0.3;
          }

          // 2. Knowledge domain matching (40%)
          const ticketDomains = extractDomainsFromText(
            `${ticket.subject} ${ticket.description}`
          );
          const teamDomains = new Set(
            metadata.members?.flatMap(m => m.knowledge_domains.map(kd => kd.domain)) || []
          );
          const matchingDomains = [...ticketDomains].filter(d => teamDomains.has(d));
          score += (matchingDomains.length / Math.max(ticketDomains.size, teamDomains.size)) * 0.4;

          // 3. Vector similarity score (30%)
          score += similarity * 0.3;

          return {
            id: metadata.id,
            name: metadata.name,
            type: 'team' as const,
            relevance_score: score,
            knowledge_domains: metadata.members?.flatMap(m => m.knowledge_domains) || []
          };
        });

      // Filter and convert users to AssigneeMatch
      const userAssignees = userResults
        .filter(([result]) => result.metadata.type === 'user')  // Extra type check
        .map(([result, similarity]) => {
          const metadata = result.metadata as UserMetadata;
          let score = 0;

          // 1. Knowledge domain matching (70%)
          const ticketDomains = extractDomainsFromText(
            `${ticket.subject} ${ticket.description}`
          );
          const userDomains = new Set(
            metadata.knowledge_domains.map(kd => kd.domain)
          );
          const matchingDomains = [...ticketDomains].filter(d => userDomains.has(d));
          score += (matchingDomains.length / Math.max(ticketDomains.size, userDomains.size)) * 0.7;

          // 2. Vector similarity score (30%)
          score += similarity * 0.3;

          return {
            id: metadata.id,
            name: metadata.name,
            type: 'user' as const,
            relevance_score: score,
            knowledge_domains: metadata.knowledge_domains
          };
        });

      // Combine and sort all potential assignees
      const potentialAssignees = [...teamAssignees, ...userAssignees]
        .sort((a, b) => b.relevance_score - a.relevance_score)
        .slice(0, 5);  // Keep top 5 overall

      console.log('Potential assignees:', JSON.stringify(potentialAssignees, null, 2));

      return {
        ...context,
        potentialAssignees
      };
    }
  ]);

  // 4. Analyze team workloads and capacity
  const workloadAnalyzer = RunnableSequence.from([
    new RunnablePassthrough(),
    async (context: TeamMatchResult): Promise<WorkloadResult> => {
      const { potentialAssignees } = context;
      // ... workload analysis logic ...
      return { ...context, agentWorkloads: [] };
    }
  ]);

  // 5. Make final routing recommendation
  const routingRecommender = RunnableSequence.from([
    new RunnablePassthrough(),
    async (context: WorkloadResult): Promise<RoutingResult> => {
      const { potentialAssignees } = context;
      
      if (potentialAssignees.length === 0) {
        return {
          recommendedAssignee: null,
          confidence: 0,
          factors: {
            relevance: { 
              score: 0, 
              tags: [],
              domains: [],
              similar_tickets: 0 
            },
            workload: { 
              open_tickets: 0, 
              active_agents: 0, 
              capacity_score: 0 
            }
          },
          alternativeAssignees: []
        };
      }

      // Calculate confidence based on score difference and thresholds
      const bestScore = potentialAssignees[0].relevance_score;
      const confidence = Math.min(
        1.0,  // Cap at 100%
        bestScore > 0.8 ? 0.9 :  // Very high match
        bestScore > 0.6 ? 0.8 :  // Good match
        bestScore > 0.4 ? 0.6 :  // Moderate match
        bestScore > 0.2 ? 0.4 :  // Poor match
        0.2  // Very poor match
      );

      const best = potentialAssignees[0];
      const recommendedAssignee = {
        id: best.id,
        name: best.name,
        type: best.type,
        score: best.relevance_score
      };

      return {
        recommendedAssignee,
        confidence,
        factors: {
          relevance: { 
            score: best.relevance_score,
            tags: best.type === 'team' ? (best as any).tags : [],
            domains: best.knowledge_domains.map(kd => kd.domain),
            similar_tickets: 0 
          },
          workload: { 
            open_tickets: 0, 
            active_agents: best.type === 'team' ? 1 : 0,
            capacity_score: 0 
          }
        },
        alternativeAssignees: potentialAssignees
          .slice(1)
          .map(assignee => ({
            id: assignee.id,
            name: assignee.name,
            type: assignee.type,
            score: assignee.relevance_score
          }))
      };
    }
  ]);

  // Add new component to update ticket
  const ticketUpdater = RunnableSequence.from([
    new RunnablePassthrough(),
    async (context: RoutingResult): Promise<RoutingResult> => {
      const { recommendedAssignee, ticket } = context;
      
      if (recommendedAssignee) {
        // Update ticket assignment
        const { error: updateError } = await supabaseClient
          .from('tickets')
          .update({
            assignee_id: recommendedAssignee.type === 'user' ? recommendedAssignee.id : null,
            team_id: recommendedAssignee.type === 'team' ? recommendedAssignee.id : null,
            updated_at: new Date().toISOString()
          })
          .eq('id', ticket.id);

        if (updateError) {
          console.error('Failed to update ticket:', updateError);
        }
      }

      return context;
    }
  ]);

  // Add to routing chain
  const routingChain = RunnableSequence.from([
    ticketParser,
    similarTicketRetriever,
    teamMatcher,
    workloadAnalyzer,
    routingRecommender,
    ticketUpdater  // Add final step
  ]);

  return {
    ticketParser,
    similarTicketRetriever,
    teamMatcher,
    workloadAnalyzer,
    routingRecommender,
    ticketUpdater,
    routingChain
  };
}

// Add type for request body
interface ReevaluationRequest {
  type: 'reevaluation';
  id: string;
  trigger_source: string;
}

interface NewTicketRequest extends Ticket {}

type RequestBody = ReevaluationRequest | NewTicketRequest;

// Add type guard for reevaluation requests
function isReevaluation(body: RequestBody): body is ReevaluationRequest {
  return 'type' in body && body.type === 'reevaluation';
}

// Edge function handler
export const onRequest = async (context: Context) => {
  const clients = initClients();
  const { routingChain } = createComponents(clients);
  
  const body = await context.request.json() as RequestBody;
  
  if (isReevaluation(body)) {
    // ... reevaluation logic using clients.supabaseClient
  }

  const result = await routingChain.invoke(body);
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
}; 