//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Fetch pre-built movie card for fast app display

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const tmdbId = url.searchParams.get('tmdb_id');
    
    if (!tmdbId) {
      return new Response(
        JSON.stringify({ error: 'tmdb_id required' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    // Look up work by tmdb_id
    const { data: work, error: workError } = await supabase
      .from('works')
      .select('work_id')
      .eq('tmdb_id', tmdbId)
      .maybeSingle();
    
    if (workError && workError.code !== 'PGRST116') {
      throw workError;
    }
    
    if (!work) {
      // Movie not in database - trigger ingestion
      const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({ tmdb_id: tmdbId }),
      });
      
      const result = await ingestResponse.json();
      
      if (!ingestResponse.ok) {
        return new Response(
          JSON.stringify({ error: result.error || 'Failed to ingest movie' }), 
          { status: ingestResponse.status, headers: { 'Content-Type': 'application/json' } }
        );
      }
      
      return new Response(
        JSON.stringify(result.card || result), 
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Get cached card
    const { data: card, error: cardError } = await supabase
      .from('work_cards_cache')
      .select('payload, etag')
      .eq('work_id', work.work_id)
      .single();
    
    if (cardError) {
      // Card not cached - trigger rebuild
      const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({ tmdb_id: tmdbId, force_refresh: true }),
      });
      
      const result = await ingestResponse.json();
      
      if (!ingestResponse.ok) {
        return new Response(
          JSON.stringify({ error: result.error || 'Failed to rebuild card' }), 
          { status: ingestResponse.status, headers: { 'Content-Type': 'application/json' } }
        );
      }
      
      return new Response(
        JSON.stringify(result.card || result), 
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    return new Response(
      JSON.stringify(card.payload), 
      {
        headers: {
          'Content-Type': 'application/json',
          'ETag': card.etag || '',
          'Cache-Control': 'max-age=3600',
        }
      }
    );
    
  } catch (error) {
    console.error('Get movie card error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

