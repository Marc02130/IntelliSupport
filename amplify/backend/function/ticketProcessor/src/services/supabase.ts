import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { Database } from '../types/supabase';

interface TestTicket {
  id: string;
  subject: string;
  description: string;
  status: string;
  priority: string;
}

interface TestUser {
  id: string;
  email: string;
  role: 'admin' | 'agent' | 'customer';
}

export class SupabaseService {
  private client: SupabaseClient<Database>;

  constructor() {
    this.client = createClient<Database>(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      {
        auth: {
          persistSession: false
        }
      }
    );
  }

  async testConnection(): Promise<any[]> {
    const { data, error } = await this.client
      .from('tickets')
      .select('id')
      .limit(1);

    if (error) throw error;
    return data;
  }

  async getTicketDetails(ticketId: string) {
    const { data, error } = await this.client
      .from('tickets')
      .select(`
        *,
        requester:requester_id(*),
        assignee:assignee_id(*),
        team:team_id(*),
        organization:organization_id(*)
      `)
      .eq('id', ticketId)
      .single();

    if (error) throw error;
    return data;
  }

  async getAgentKnowledgeDomains(agentId: string) {
    const { data, error } = await this.client
      .from('user_knowledge_domain')
      .select(`
        *,
        knowledge_domain(*)
      `)
      .eq('user_id', agentId);

    if (error) throw error;
    return data;
  }

  async updateTicketAssignment(
    ticketId: string, 
    assigneeId: string,
    confidence: number,
    factors: Record<string, any>
  ) {
    const { error: updateError } = await this.client
      .from('tickets')
      .update({ assignee_id: assigneeId })
      .eq('id', ticketId);

    if (updateError) throw updateError;

    const { error: historyError } = await this.client
      .from('ticket_routing_history')
      .insert({
        ticket_id: ticketId,
        assigned_to: assigneeId,
        confidence_score: confidence,
        routing_factors: factors
      });

    if (historyError) throw historyError;
  }

  async storeRoutingHistory(data: {
    ticket_id: string;
    assigned_to: string;
    confidence_score: number;
    routing_factors: Record<string, number>;
  }) {
    const { data: record, error } = await this.client
      .from('ticket_routing_history')
      .insert(data)
      .select()
      .single();

    if (error) throw error;
    return record;
  }

  async deleteRoutingHistory(id: string) {
    const { error } = await this.client
      .from('ticket_routing_history')
      .delete()
      .eq('id', id);

    if (error) throw error;
  }

  async createTestTicket(data: TestTicket): Promise<Database['public']['Tables']['tickets']['Row']> {
    const { data: ticket, error } = await this.client
      .from('tickets')
      .insert(data)
      .select()
      .single();

    if (error) throw error;
    return ticket;
  }

  async deleteTestTicket(id: string): Promise<void> {
    const { error } = await this.client
      .from('tickets')
      .delete()
      .eq('id', id);

    if (error) throw error;
  }

  async createTestUser(user: TestUser) {
    const { data: authUser, error: authError } = await this.client.auth.admin.createUser({
      email: user.email,
      email_confirm: true,
      user_metadata: { role: user.role },
      id: user.id
    });

    if (authError) throw authError;

    const { data: publicUser, error: publicError } = await this.client
      .from('users')
      .insert({
        id: user.id,
        email: user.email,
        role: user.role
      })
      .select()
      .single();

    if (publicError) throw publicError;
    return publicUser;
  }

  async deleteTestUser(id: string) {
    const { error } = await this.client
      .from('users')
      .delete()
      .eq('id', id);

    if (error) throw error;
  }

  async createTicket(ticket: {
    id: string;
    subject: string;
    description?: string;
    status: string;
    priority: string;
  }) {
    const { data, error } = await this.client
      .from('tickets')
      .insert(ticket)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  async deleteTicket(ticketId: string) {
    const { error } = await this.client
      .from('tickets')
      .delete()
      .eq('id', ticketId);

    if (error) throw error;
  }

  async getTestAgent(): Promise<string> {
    const { data: agents, error } = await this.client
      .from('users')
      .select('id')
      .eq('role', 'agent')
      .limit(1);

    if (error) throw error;
    if (!agents?.length) {
      throw new Error('No test agent found in database');
    }

    return agents[0].id;
  }

  async getTestTicket(): Promise<string> {
    const { data: tickets, error } = await this.client
      .from('tickets')
      .select('id')
      .limit(1);

    if (error) throw error;
    if (!tickets?.length) {
      throw new Error('No test ticket found in database');
    }

    return tickets[0].id;
  }
} 