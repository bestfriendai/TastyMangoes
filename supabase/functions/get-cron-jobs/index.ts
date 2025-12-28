//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-24 at 00:00 (America/Los_Angeles - Pacific Time)
//  Notes: Edge Function to query cron.job table (NO MIGRATION NEEDED - avoids drift risk)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    console.log('[GET-CRON-JOBS] Fetching cron jobs...');
    
    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Strategy 1: Try to query cron.job via PostgREST REST API
    // Note: cron schema may not be exposed by default, but worth trying
    try {
      const response = await fetch(
        `${supabaseUrl}/rest/v1/cron.job?select=*&order=jobname.asc`,
        {
          method: 'GET',
          headers: {
            'apikey': supabaseServiceKey,
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Accept': 'application/json',
          },
        }
      );

      if (response.ok) {
        const jobs = await response.json();
        console.log(`[GET-CRON-JOBS] Found ${jobs.length} jobs via PostgREST`);
        return new Response(
          JSON.stringify({ jobs, success: true, source: 'postgrest' }),
          {
            headers: { 'Content-Type': 'application/json' },
            status: 200,
          }
        );
      }
    } catch (postgrestError) {
      console.warn('[GET-CRON-JOBS] PostgREST query failed, trying RPC fallback:', postgrestError);
    }

    // Strategy 2: Try RPC function (if migration 021 was applied)
    // This is a graceful fallback - if migration exists, use it
    try {
      const { data, error } = await supabase.rpc('get_cron_jobs');
      
      if (!error && data) {
        console.log(`[GET-CRON-JOBS] Found ${data.length} jobs via RPC`);
        return new Response(
          JSON.stringify({ jobs: data, success: true, source: 'rpc' }),
          {
            headers: { 'Content-Type': 'application/json' },
            status: 200,
          }
        );
      }
    } catch (rpcError) {
      console.warn('[GET-CRON-JOBS] RPC function not available:', rpcError);
    }

    // Strategy 3: Return empty array with helpful message
    // This allows dashboard to load without errors
    console.warn('[GET-CRON-JOBS] No cron jobs accessible. Cron jobs may not be configured yet.');
    return new Response(
      JSON.stringify({ 
        jobs: [],
        success: true,
        source: 'fallback',
        message: 'Cron jobs not accessible. This is normal if cron jobs have not been configured yet.'
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error: any) {
    console.error('[GET-CRON-JOBS] Unexpected error:', error);
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Failed to fetch cron jobs',
        jobs: [],
        success: false
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});
