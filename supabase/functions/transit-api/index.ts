// Supabase Edge Function: transit-api
// Serves /routes and /stops directly from the Supabase edge runtime

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'https://xpphmiajwjkcxtxitcex.supabase.co'
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? 'sb_publishable_7cqahorS_JAw4601eqpQkA_xPgA3YZL'
    const supabase = createClient(supabaseUrl, supabaseKey)

    const url = new URL(req.url)
    const pathname = url.pathname

    if (pathname.endsWith('/routes') || url.searchParams.get('type') === 'routes') {
      const routeType = url.searchParams.get('route_type')
      let query = supabase.from('routes').select('*')
      if (routeType) {
        query = query.eq('route_type', routeType.toUpperCase())
      }
      const { data, error } = await query
      if (error) throw error
      return new Response(JSON.stringify(data), { headers: corsHeaders })
    }

    if (pathname.endsWith('/stops') || url.searchParams.get('type') === 'stops') {
      const { data, error } = await supabase.from('stops').select('*')
      if (error) throw error
      return new Response(JSON.stringify(data), { headers: corsHeaders })
    }

    // Default: return both routes and stops
    const [routesRes, stopsRes] = await Promise.all([
      supabase.from('routes').select('*'),
      supabase.from('stops').select('*')
    ])

    return new Response(
      JSON.stringify({
        routes: routesRes.data || [],
        stops: stopsRes.data || [],
        status: 'online',
        server: 'SmartTransit Supabase Edge'
      }),
      { headers: corsHeaders }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: corsHeaders }
    )
  }
})
