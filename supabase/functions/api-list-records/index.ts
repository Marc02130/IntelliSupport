import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { corsHeaders } from '../_shared/cors.ts'

const supabaseClient = createClient(
  Deno.env.get('DB_URL') ?? '',
  Deno.env.get('SERVICE_ROLE_KEY') ?? ''
)

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { queryId, filters, pagination } = await req.json()

    // Get query configuration
    const { data: queryConfig } = await supabaseClient
      .from('list_view_configs')
      .select('*')
      .eq('id', queryId)
      .single()

    if (!queryConfig) {
      throw new Error('Query configuration not found')
    }

    // Execute configured query with filters
    const { data, error } = await supabaseClient
      .from(queryConfig.table_name)
      .select(queryConfig.select_fields)
      .match(filters || {})
      .range(
        pagination?.from || 0,
        pagination?.to || 9
      )

    if (error) throw error

    return new Response(
      JSON.stringify({ data }),
      { 
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  }
}) 