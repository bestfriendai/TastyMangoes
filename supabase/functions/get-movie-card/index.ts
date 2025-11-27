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
    
    // Get works_meta to check schema version
    const { data: workMeta, error: metaError } = await supabase
      .from('works_meta')
      .select('schema_version, trailers')
      .eq('work_id', work.work_id)
      .single();
    
    const CURRENT_SCHEMA_VERSION = 2;
    const schemaVersion = workMeta?.schema_version || 1;
    
    // Check if upgrade is needed
    if (schemaVersion < CURRENT_SCHEMA_VERSION) {
      console.log(`[GET-CARD] Movie ${work.work_id} needs upgrade: v${schemaVersion} → v${CURRENT_SCHEMA_VERSION}`);
      
      // Trigger upgrade via ingest-movie (it will handle the upgrade logic)
      try {
        const upgradeResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
          },
          body: JSON.stringify({ tmdb_id: tmdbId, force_refresh: false }),
        });
        
        const upgradeResult = await upgradeResponse.json();
        if (upgradeResponse.ok && upgradeResult.card) {
          console.log(`[GET-CARD] Upgrade successful, returning upgraded card`);
          return new Response(
            JSON.stringify(upgradeResult.card),
            { headers: { 'Content-Type': 'application/json' } }
          );
        } else {
          console.warn(`[GET-CARD] Upgrade failed, continuing with existing data:`, upgradeResult);
        }
      } catch (upgradeError) {
        console.warn(`[GET-CARD] Upgrade error, continuing with existing data:`, upgradeError);
      }
    }
    
    // Get cached card
    const { data: card, error: cardError } = await supabase
      .from('work_cards_cache')
      .select('payload, etag')
      .eq('work_id', work.work_id)
      .single();
    
    // Check if cached card exists and has certification
    if (card && card.payload) {
      const cert = card.payload.certification;
      const hasCertification = cert !== null && cert !== undefined && cert !== '' && String(cert).trim() !== '';
      if (!hasCertification) {
        console.log(`[GET-CARD] Cached card missing certification, triggering refresh for work_id: ${work.work_id}`);
        // Trigger refresh to get certification
        const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
          },
          body: JSON.stringify({ tmdb_id: tmdbId, force_refresh: true }),
        });
        
        const result = await ingestResponse.json();
        if (ingestResponse.ok && result.card) {
          console.log(`[GET-CARD] Refresh successful, returning updated card with certification`);
          return new Response(
            JSON.stringify(result.card), 
            { headers: { 'Content-Type': 'application/json' } }
          );
        }
        // If refresh fails, continue with existing cached card
        console.warn(`[GET-CARD] Refresh failed, returning cached card without certification`);
      }
    }
    
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
    
    // Merge trailers from works_meta if available (for v2+)
    let cardPayload = card.payload;
    if (workMeta?.trailers && (!cardPayload.trailers || cardPayload.trailers.length === 0)) {
      cardPayload = {
        ...cardPayload,
        trailers: workMeta.trailers,
      };
    }
    
    return new Response(
      JSON.stringify(cardPayload), 
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
