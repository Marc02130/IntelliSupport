export interface Ticket {
  id: string;
  subject: string;
  description: string;
  tags: string[];
  organization_id: string;
}

export interface TicketContext {
  ticket: Ticket;
  similarTickets: any[];
  relevantTeams: any[];
  agentWorkloads: any[];
}

export interface Team {
  id: string;
  name: string;
  tags: string[];
  knowledge_domains: {
    domain: string;
    expertise: string;
  }[];
  relevance_score: number;
}

// Common interface for any potential assignee (team or user)
export interface AssigneeMatch {
  id: string;
  name: string;
  type: 'team' | 'user';
  relevance_score: number;
  knowledge_domains: {
    domain: string;
    expertise: string;
  }[];
}

// Update TeamMatchResult to include both types of matches
export interface TeamMatchResult extends TicketContext {
  potentialAssignees: AssigneeMatch[];  // Combined list of teams and users
}

// Update WorkloadResult
export interface WorkloadResult extends TeamMatchResult {
  agentWorkloads: {
    assignee_id: string;  // Can be team_id or user_id
    open_tickets: number;
    active_agents: number;  // Only relevant for teams
    capacity_score: number;
  }[];
}

// Update RoutingResult
export interface RoutingResult {
  recommendedAssignee: {
    id: string;
    name: string;
    type: 'team' | 'user';
    score: number;
  } | null;
  confidence: number;
  factors: {
    relevance: {
      score: number;
      tags: string[];
      domains: string[];
      similar_tickets: number;
    };
    workload: {
      open_tickets: number;
      active_agents: number;
      capacity_score: number;
    };
  };
  alternativeAssignees: {
    id: string;
    name: string;
    type: 'team' | 'user';
    score: number;
  }[];
}

export type Context = {
  request: Request;
  env: Record<string, string>;
};

export interface Domain {
  name: string | null;
}

export interface UserKnowledgeDomain {
  domain: Domain | null;
  expertise: string | null;
}

export interface User {
  user_knowledge_domain: {
    domain: {
      name: string;
    };
    expertise: string;
  }[];
}

export interface TeamMember {
  role: string;
  user_id: string;
  schedule: {
    start_time: string;
    end_time: string;
  };
  knowledge_domains: KnowledgeDomain[];
}

export interface TeamTag {
  tag: {
    name: string | null;
  } | null;
}

export interface DatabaseTeamData {
  id: string;
  name: string;
  tags: {
    tag: {
      name: string | null;
    } | null;
  }[] | null;
  knowledge_domains: {
    user: {
      user_knowledge_domain: Array<{
        domain: {
          name: string | null;
        } | null;
        expertise: string | null;
      }> | null;
    } | null;
  }[] | null;
}

export interface TeamSchedule {
  team_id: string;
  user_id: string;
  start_time: string;
  end_time: string;
}

export interface TicketCount {
  team_id: string;
  count: string;
}

export interface SupabaseQueryResult<T> {
  data: T[] | null;
  error: Error | null;
}

// Base metadata interface
interface BaseMetadata {
  id: string;
  type: 'user' | 'team' | 'ticket';
  organization_id: string;
  last_updated: string;
}

// Knowledge domain structure
interface KnowledgeDomain {
  domain: string;
  expertise: 'beginner' | 'intermediate' | 'expert';
}

// User metadata
interface UserMetadata extends BaseMetadata {
  type: 'user';
  name: string;
  knowledge_domains: KnowledgeDomain[];
  is_active: boolean;
}

// Rename the second one
interface MetadataTeamMember {
  role: string;
  user_id: string;
  schedule: {
    start_time: string;
    end_time: string;
  };
  knowledge_domains: KnowledgeDomain[];
}

// Update TeamMetadata to use the new interface name
interface TeamMetadata extends BaseMetadata {
  type: 'team';
  name: string;
  tags: string[];
  members: MetadataTeamMember[];
  is_active: boolean;
}

// Ticket comment structure
interface TicketComment {
  content: string;
  author_id: string | null;
  created_at: string;
}

// Ticket metadata
interface TicketMetadata extends BaseMetadata {
  type: 'ticket';
  subject: string;
  description: string;
  status: 'open' | 'in_progress' | 'resolved';
  priority: 'low' | 'medium' | 'high';
  tags: string[];
  team_id: string | null;
  assigned_to: string | null;
  requested_by: string | null;
  comments: TicketComment[];
}

// Union type for all metadata
type EntityMetadata = UserMetadata | TeamMetadata | TicketMetadata;

export type {
  BaseMetadata,
  KnowledgeDomain,
  UserMetadata,
  MetadataTeamMember,
  TeamMetadata,
  TicketComment,
  TicketMetadata,
  EntityMetadata
};

// Database types for team query results
export interface DatabaseKnowledgeDomain {
  domain: {
    name: string;
  };
  expertise: string;
}

export interface DatabaseTeamMember {
  user: User;
} 