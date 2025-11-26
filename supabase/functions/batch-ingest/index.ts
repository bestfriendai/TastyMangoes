//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Batch process seed movies for initial data population

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Get all works that don't have metadata yet (or limit to 10 for batch processing)
    const { data: works, error: worksError } = await supabase
      .from('works')
      .select('work_id, tmdb_id, title')
      .order('created_at', { ascending: true })
      .limit(10); // Process 10 at a time to avoid rate limits
    
    if (worksError) throw worksError;
    
    if (!works || works.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No movies to process' }), 
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    const results = [];
    
    for (const work of works) {
      try {
        // Call ingest function for each movie
        const response = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
          },
          body: JSON.stringify({ tmdb_id: work.tmdb_id }),
        });
        
        const result = await response.json();
        
        if (response.ok) {
          results.push({ 
            tmdb_id: work.tmdb_id, 
            title: work.title, 
            status: 'success',
            work_id: result.work_id 
          });
        } else {
          results.push({ 
            tmdb_id: work.tmdb_id, 
            title: work.title, 
            status: 'error', 
            error: result.error 
          });
        }
        
        // Rate limiting: wait 250ms between requests (TMDB allows ~40 req/10s)
        await new Promise(resolve => setTimeout(resolve, 250));
        
      } catch (error) {
        results.push({ 
          tmdb_id: work.tmdb_id, 
          title: work.title, 
          status: 'error', 
          error: error.message 
        });
      }
    }
    
    return new Response(
      JSON.stringify({ 
        processed: results.length,
        results 
      }), 
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('Batch ingest error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

