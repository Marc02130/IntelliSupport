import { createClient } from '@supabase/supabase-js'
import { OpenAI } from 'openai'
import { PineconeClient } from '@pinecone-database/pinecone'

// Initialize clients with proper error handling
const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY')
})

// Initialize Pinecone
const pinecone = new PineconeClient()
await pinecone.init({
  apiKey: Deno.env.get('PINECONE_API_KEY') ?? '',
  environment: Deno.env.get('PINECONE_ENVIRONMENT') ?? ''
})

// Initialize Supabase
const supabaseUrl = Deno.env.get('SUPABASE_URL')
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error('Missing Supabase environment variables')
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
})

// Add environment validation
function validateEnvironment() {
  const required = [
    'OPENAI_API_KEY',
    'PINECONE_API_KEY',
    'PINECONE_ENVIRONMENT',
    'PINECONE_INDEX',
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY'
  ]

  const missing = required.filter(key => !Deno.env.get(key))
  if (missing.length > 0) {
    throw new Error(`Missing environment variables: ${missing.join(', ')}`)
  }
}

// Validate on startup
validateEnvironment()

export const routeTicket = async (ticket: {
  id: string
  subject: string
  description: string
  tags: string[]
  priority: string
  organization_id: string
}) => {
  // 1. Get ticket embedding
  const embedding = await openai.embeddings.create({
    model: "text-embedding-3-large",
    input: `${ticket.subject}\n${ticket.description}`
  })

  // 2. Find similar tickets in Pinecone
  const similarTickets = await pinecone.query({
    vector: embedding.data[0].embedding,
    filter: {
      type: "ticket",
      status: "resolved",
      tags: { $in: ticket.tags }
    },
    topK: 5
  })

  // 3. Get team scores based on tags
  const teamScores = await getTeamScores(ticket.tags)

  // 4. Get available agents
  const availableAgents = await getAvailableAgents(
    ticket.organization_id,
    teamScores
  )

  // 5. Score agents based on:
  // - Knowledge domain expertise
  // - Similar tickets history
  // - Current workload
  // - Team tag matches
  const agentScores = await scoreAgents(
    availableAgents,
    similarTickets,
    ticket
  )

  // 6. Select best agent
  const bestAgent = selectBestAgent(agentScores)

  // 7. Store routing decision
  await storeRoutingDecision({
    ticket_id: ticket.id,
    assigned_to: bestAgent.id,
    confidence_score: bestAgent.score,
    routing_factors: {
      similar_tickets: similarTickets.map(t => t.id),
      team_scores: teamScores,
      agent_scores: agentScores
    }
  })

  return bestAgent
}

async function getTeamScores(tags: string[]) {
  // Score teams based on tag matches
  const { data: teamTags } = await supabase
    .from('team_tags')
    .select(`
      team_id,
      tags (name)
    `)
    .in('tag.name', tags)

  return teamTags.reduce((scores, tt) => ({
    ...scores,
    [tt.team_id]: (scores[tt.team_id] || 0) + 1
  }), {})
}

async function getAvailableAgents(orgId: string, teamScores: Record<string, number>) {
  // Get agents who:
  // 1. Are active
  // 2. Are on schedule
  // 3. Have capacity
  // 4. Are on teams matching tags
  const { data: agents } = await supabase
    .from('team_members')
    .select(`
      user_id,
      team_id,
      users!inner (
        id,
        knowledge_domains (
          domain:knowledge_domains(id, description),
          expertise,
          years_experience
        )
      )
    `)
    .eq('organization_id', orgId)
    .eq('is_active', true)
    // Add schedule check here
} 