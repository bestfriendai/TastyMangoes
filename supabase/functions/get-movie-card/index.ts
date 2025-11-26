//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-01-15 at 21:00 (America/Los_Angeles - Pacific Time)
//  Notes: Fetch pre-built movie card for fast app display - accepts POST body with tmdb_id as string or number

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    // Support both GET (query param) and POST (body) for tmdb_id
    let tmdbId: string | null = null;
    
    // Try POST body first
    if (req.method === 'POST') {
      try {
        const body = await req.json();
        // Accept tmdb_id as string or number
        if (body.tmdb_id !== undefined && body.tmdb_id !== null) {
          tmdbId = String(body.tmdb_id);
        }
      } catch (e) {
        // If body parsing fails, try query param
        console.warn('Failed to parse POST body, trying query param:', e);
      }
    }
    
    // Fallback to GET query param
    if (!tmdbId) {
      const url = new URL(req.url);
      tmdbId = url.searchParams.get('tmdb_id');
    }
    
    if (!tmdbId) {
      return new Response(
        JSON.stringify({ error: 'tmdb_id required (as query param or POST body)' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[GET-CARD] Requested movie card for TMDB ID: ${tmdbId}`);
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    
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
      // Movie not in database - automatically trigger ingestion
      console.log(`[GET-CARD] Movie not in database, triggering auto-ingest for TMDB ID: ${tmdbId}`);
      
      const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({ tmdb_id: tmdbId, force_refresh: false }),
      });
      
      const result = await ingestResponse.json();
      
      if (!ingestResponse.ok) {
        console.error(`[GET-CARD] Auto-ingest failed:`, result);
        return new Response(
          JSON.stringify({ error: result.error || 'Failed to ingest movie' }), 
          { status: ingestResponse.status, headers: { 'Content-Type': 'application/json' } }
        );
      }
      
      console.log(`[GET-CARD] Auto-ingest successful, returning new card for work_id: ${result.work_id}`);
      
      // Return the newly created card
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
      console.log(`[GET-CARD] Card not cached, triggering rebuild for work_id: ${work.work_id}`);
      
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
        console.error(`[GET-CARD] Rebuild failed:`, result);
        return new Response(
          JSON.stringify({ error: result.error || 'Failed to rebuild card' }), 
          { status: ingestResponse.status, headers: { 'Content-Type': 'application/json' } }
        );
      }
      
      console.log(`[GET-CARD] Rebuild successful, returning card for work_id: ${result.work_id}`);
      
      return new Response(
        JSON.stringify(result.card || result), 
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[GET-CARD] Returning cached card for work_id: ${work.work_id}`);
    
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
    console.error('[GET-CARD] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
