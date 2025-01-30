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
    const { queryId, filters, parentId, parentField } = await req.json()

    // Get the query definition
    const { data: queryDef, error: queryError } = await supabaseClient
      .from('search_queries')
      .select('*')
      .eq('id', queryId)
      .single()

    if (queryError) throw queryError
    if (!queryDef) throw new Error('Query definition not found')

    // Get base query
    let query = supabaseClient.from(queryDef.base_table)

    // Add select
    if (queryDef.query_definition.select) {
      query = query.select(queryDef.query_definition.select)
    }

    // Handle where clauses
    let whereClause = queryDef.query_definition.where || {}
    
    // Add parent filter if provided (for child tables)
    if (parentId && parentField) {
      whereClause = {
        ...whereClause,
        [parentField]: parentId
      }
    }

    // Apply where clauses
    if (Object.keys(whereClause).length > 0) {
      for (const [key, value] of Object.entries(whereClause)) {
        if (value === 'auth.uid()') {
          query = query.eq(key, req.headers.get('x-user-id'))
        } else if (typeof value === 'string' && value.startsWith('(')) {
          // Handle SQL expressions/subqueries
          const sqlWithUserId = value.replace('auth.uid()', `'${req.headers.get('x-user-id')}'`)
          const { data: subqueryData, error: rpcError } = await supabaseClient.rpc('execute_sql', { 
            sql_query: sqlWithUserId.slice(1, -1)
          })
          if (rpcError) throw new Error(`RPC Error: ${rpcError.message}`)
          if (!subqueryData || !subqueryData[0]) throw new Error('No results from subquery')
          query = query.eq(key, subqueryData[0].result)
        } else {
          query = query.eq(key, value)
        }
      }
    }

    // Apply any additional filters
    if (filters) {
      query = query.match(filters)
    }

    const { data, error } = await query

    if (error) throw error

    return new Response(
      JSON.stringify({ 
        data,
        queryDef 
      }),
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