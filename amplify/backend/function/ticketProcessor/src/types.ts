export interface RoutingDecision {
  confidence: number;
  reasoning: string;
  suggestedTags: string[];
  priority?: 'low' | 'medium' | 'high';
  assignedAgentId?: number;
  estimatedTimeToResolution?: number;
}

export interface Agent {
  id: number;
  expertise: string[];
  availability?: 'available' | 'busy' | 'offline';
  performance?: {
    averageResponseTime: number;
    satisfactionScore: number;
  };
}

export interface Ticket {
  id: string;
  content: string;
  tags?: string[];
  priority?: 'low' | 'medium' | 'high';
  status: 'open' | 'in_progress' | 'resolved' | 'closed';
  created_at: string;
  organization_id?: string;
}

export interface Comment {
  id: string;
  ticket_id: string;
  content: string;
  created_at: string;
  author_id: string;
  is_internal?: boolean;
} 