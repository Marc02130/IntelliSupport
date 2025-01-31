import { config } from './config.ts'
import { getSupabaseClient } from './context.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-user-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

console.log('Starting function')
console.log('Environment:', {
  keys: Object.keys(Deno.env.toObject()),
  values: Deno.env.toObject()
})

// Debug environment variables
console.log('Environment variables:', {
  dbUrl: !!config.DB_URL,
  serviceKey: !!config.SERVICE_ROLE_KEY
})

let supabaseClient
try {
  supabaseClient = getSupabaseClient()
} catch (error) {
  console.error('Failed to create Supabase client:', error)
}

// Add request debugging
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    console.log('OPTIONS request headers:', Object.fromEntries(req.headers.entries()))
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (!supabaseClient) {
      console.error('Supabase client initialization failed with config:', {
        hasDbUrl: !!config.DB_URL,
        hasServiceKey: !!config.SERVICE_ROLE_KEY
      })
      throw new Error('Supabase client not initialized')
    }

    // Auth info is in req.headers.get('x-user-id')
    const authUser = req.headers.get('x-user-id')
    if (!authUser) {
      throw new Error('Unauthorized')
    }

    // Log the full request
    const body = await req.json()
    console.log('Request:', {
      method: req.method,
      headers: Object.fromEntries(req.headers.entries()),
      auth: req.auth,
      body
    })

    const { queryId, filters, parentId, parentField } = body
    console.log('Request params:', { queryId, filters, parentId, parentField })

    // Get the query definition
    const { data: queryDef, error: queryError } = await supabaseClient
      .from('search_queries')
      .select('*')
      .eq('id', queryId)
      .single()

    if (queryError) {
      console.error('Query definition error:', queryError)
      throw queryError
    }

    console.log('Query definition:', queryDef)
    if (!queryDef) throw new Error('Query definition not found')

    // Get base query
    let query = supabaseClient.from(queryDef.base_table)
    console.log('Base table:', queryDef.base_table)

    // Add select
    if (queryDef.query_definition.select) {
      query = query.select(queryDef.query_definition.select)
      console.log('Select fields:', queryDef.query_definition.select)
    }

    // Handle where clauses
    let whereClause = queryDef.query_definition.where || {}
    console.log('Where clause:', whereClause)
    
    // Add parent filter if provided (for child tables)
    if (parentId && parentField) {
      whereClause = {
        ...whereClause,
        [parentField]: parentId
      }
      console.log('Updated where clause with parent:', whereClause)
    }

    // Apply where clauses
    if (Object.keys(whereClause).length > 0) {
      for (const [key, value] of Object.entries(whereClause)) {
        if (value === 'auth.uid()') {
          query = query.eq(key, req.headers.get('x-user-id'))
        } else if (typeof value === 'string' && value.startsWith('(')) {
          // Handle SQL expressions/subqueries
          const sqlWithUserId = value.replace('auth.uid()', `'${req.headers.get('x-user-id')}'`)
          console.log('SQL subquery:', sqlWithUserId)
          const { data: subqueryData, error: rpcError } = await supabaseClient.rpc('execute_sql', { 
            sql_query: sqlWithUserId.slice(1, -1)
          })
          if (rpcError) {
            console.error('RPC error:', rpcError)
            throw new Error(`RPC Error: ${rpcError.message}`)
          }
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
      console.log('Applied filters:', filters)
    }

    const { data, error } = await query
    if (error) {
      console.error('Query error:', error)
      throw error
    }

    console.log('Query successful, row count:', data?.length)

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
    console.error('Full error:', error)
    // Log error details
    if (error instanceof Error) {
      console.error({
        name: error.name,
        message: error.message,
        stack: error.stack,
        cause: error.cause
      })
    }
    return new Response(
      JSON.stringify({ 
        error: error.message,
        details: error.toString(),
        stack: error.stack
      }),
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