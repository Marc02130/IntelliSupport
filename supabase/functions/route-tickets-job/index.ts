import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import type { Ticket } from '../route-ticket/types.ts'

export const onRequest = async (context: Context) => {
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // Get unassigned tickets
    const { data: tickets, error: fetchError } = await supabaseClient
      .from('tickets')
      .select('*')
      .is('assignee_id', null)
      .is('team_id', null)
      .eq('status', 'open')
      .order('created_at', { ascending: true });

    if (fetchError) throw fetchError;

    console.log(`Found ${tickets?.length || 0} unassigned tickets`);

    // Route each ticket by calling route-ticket function
    const results = await Promise.all(
      (tickets || []).map(async (ticket: Ticket) => {
        try {
          const response = await fetch(
            `${Deno.env.get("SUPABASE_URL")}/functions/v1/route-ticket`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(ticket)
            }
          );

          if (!response.ok) {
            throw new Error(`Failed to route ticket ${ticket.id}: ${response.statusText}`);
          }

          return {
            ticket_id: ticket.id,
            status: 'success'
          };
        } catch (error) {
          console.error(`Failed to route ticket ${ticket.id}:`, error);
          return {
            ticket_id: ticket.id,
            status: 'error',
            error: error.message
          };
        }
      })
    );

    return new Response(
      JSON.stringify({ 
        processed: results.length,
        results 
      }),
      { status: 200 }
    );

  } catch (error) {
    console.error('Job failed:', error);
    return new Response(
      JSON.stringify({ error: 'Job failed' }),
      { status: 500 }
    );
  }
}; 