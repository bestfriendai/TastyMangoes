//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Daily refresh enqueue function - finds stale movies and adds them to refresh_queue

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

serve(async (req) => {
  const startTime = Date.now();
  
  try {
    console.log('[DAILY-REFRESH] Starting daily refresh enqueue...');
    
    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Step 1: Find stale movies using the is_stale() function
    // Order by last_refreshed_at ASC to prioritize oldest refreshes first
    // Limit to 100 movies per run to avoid overwhelming the queue
    const { data: staleMovies, error: staleError } = await supabase
      .rpc('get_stale_movies', { limit_count: 100 })
      .select('work_id, tmdb_id, title, last_refreshed_at');
    
    // If the RPC function doesn't exist, fall back to manual query
    let staleWorkIds: Array<{ work_id: number; tmdb_id: string }> = [];
    
    if (staleError && staleError.code === '42883') {
      // Function doesn't exist, use manual query
      console.log('[DAILY-REFRESH] get_stale_movies function not found, using manual query...');
      
      const { data: allWorks, error: worksError } = await supabase
        .from('works')
        .select('work_id, tmdb_id, last_refreshed_at')
        .not('tmdb_id', 'is', null)
        .order('last_refreshed_at', { ascending: true })
        .limit(1000); // Get more than needed, filter in memory
      
      if (worksError) {
        throw worksError;
      }
      
      // Check each movie for staleness
      for (const work of allWorks || []) {
        const { data: isStale, error: staleCheckError } = await supabase
          .rpc('is_stale', { work_id_input: work.work_id });
        
        if (!staleCheckError && isStale === true) {
          staleWorkIds.push({ work_id: work.work_id, tmdb_id: work.tmdb_id });
          if (staleWorkIds.length >= 100) break; // Limit to 100
        }
      }
    } else if (staleError) {
      throw staleError;
    } else {
      // Use results from RPC function
      staleWorkIds = (staleMovies || []).map((m: any) => ({
        work_id: m.work_id,
        tmdb_id: m.tmdb_id
      }));
    }
    
    console.log(`[DAILY-REFRESH] Found ${staleWorkIds.length} stale movies`);
    
    if (staleWorkIds.length === 0) {
      // Update sync_state even if no movies found
      await supabase
        .from('sync_state')
        .upsert({
          sync_type: 'daily_refresh_stale',
          last_sync_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, { onConflict: 'sync_type' });
      
      return new Response(
        JSON.stringify({
          success: true,
          movies_found: 0,
          movies_queued: 0,
          movies_already_queued: 0,
          duration_ms: Date.now() - startTime
        }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Step 2: Insert into refresh_queue (skip if already queued)
    const queueEntries = staleWorkIds.map(w => ({
      work_id: w.work_id,
      priority: 0, // Default priority
      status: 'queued' as const,
      queued_at: new Date().toISOString()
    }));
    
    const { data: inserted, error: insertError } = await supabase
      .from('refresh_queue')
      .upsert(queueEntries, {
        onConflict: 'work_id',
        ignoreDuplicates: true // Don't update if already exists
      })
      .select('work_id');
    
    if (insertError) {
      throw insertError;
    }
    
    const queuedCount = inserted?.length || 0;
    const alreadyQueuedCount = staleWorkIds.length - queuedCount;
    
    console.log(`[DAILY-REFRESH] Queued ${queuedCount} movies, ${alreadyQueuedCount} already in queue`);
    
    // Step 3: Update sync_state
    const { error: syncError } = await supabase
      .from('sync_state')
      .upsert({
        sync_type: 'daily_refresh_stale',
        last_sync_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }, { onConflict: 'sync_type' });
    
    if (syncError) {
      console.error('[DAILY-REFRESH] Failed to update sync_state:', syncError);
      // Don't fail the whole function if sync_state update fails
    }
    
    const durationMs = Date.now() - startTime;
    
    console.log(`[DAILY-REFRESH] Completed in ${durationMs}ms`);
    
    return new Response(
      JSON.stringify({
        success: true,
        movies_found: staleWorkIds.length,
        movies_queued: queuedCount,
        movies_already_queued: alreadyQueuedCount,
        duration_ms: durationMs
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    const durationMs = Date.now() - startTime;
    console.error('[DAILY-REFRESH] Error:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error',
        duration_ms: durationMs
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

