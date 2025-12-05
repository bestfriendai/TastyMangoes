//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-01-15 at 22:50 (America/Los_Angeles - Pacific Time)
//  Notes: Batch process seed movies - fixed to process ALL movies when force_refresh=true with pagination

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Parse request body (JSON)
    let body: any = {};
    try {
      if (req.method === 'POST') {
        const bodyText = await req.text();
        console.log(`[BATCH] Raw request body: ${bodyText}`);
        if (bodyText) {
          body = JSON.parse(bodyText);
          console.log(`[BATCH] Parsed body:`, JSON.stringify(body));
        }
      }
    } catch (error) {
      console.warn(`[BATCH] Failed to parse request body:`, error);
      // Continue with empty body, will use query params
    }
    
    // Get parameters from body first, then fallback to query parameters
    const url = new URL(req.url);
    const forceRefresh = body.force_refresh === true || body.force_refresh === 'true' || url.searchParams.get('force_refresh') === 'true';
    const limitParam = body.limit || url.searchParams.get('limit');
    const offsetParam = body.offset || url.searchParams.get('offset');
    
    console.log(`[BATCH] Starting batch ingest - force_refresh: ${forceRefresh}, limit: ${limitParam || 'none'}, offset: ${offsetParam || '0'}`);
    console.log(`[BATCH] Request method: ${req.method}, body.force_refresh: ${body.force_refresh}, type: ${typeof body.force_refresh}`);
    
    // Build base query
    let query = supabase
      .from('works')
      .select('work_id, tmdb_id, title, ingestion_status', { count: 'exact' })
      .order('work_id', { ascending: true });
    
    if (!forceRefresh) {
      // Only get works that don't have complete metadata
      console.log(`[BATCH] Filtering for incomplete metadata (not force_refresh)`);
      query = query.or('ingestion_status.is.null,ingestion_status.eq.pending,ingestion_status.eq.failed');
    } else {
      console.log(`[BATCH] force_refresh=true - getting ALL movies`);
    }
    
    // Apply pagination
    const limit = limitParam ? parseInt(limitParam) : (forceRefresh ? 50 : 10); // Process 50 at a time if force_refresh
    const offset = offsetParam ? parseInt(offsetParam) : 0;
    
    query = query.range(offset, offset + limit - 1);
    
    console.log(`[BATCH] Query: limit=${limit}, offset=${offset}`);
    
    const { data: works, error: worksError, count } = await query;
    
    if (worksError) {
      console.error(`[BATCH] Query error:`, worksError);
      throw worksError;
    }
    
    console.log(`[BATCH] Found ${works?.length || 0} movies (total count: ${count || 'unknown'})`);
    
    if (!works || works.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: 'No movies to process',
          force_refresh: forceRefresh,
          limit: limit,
          offset: offset,
          total_count: count || 0
        }), 
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[BATCH] Processing ${works.length} movies (force_refresh: ${forceRefresh})`);
    console.log(`[BATCH] First movie: ${works[0]?.title} (work_id: ${works[0]?.work_id}, tmdb_id: ${works[0]?.tmdb_id})`);
    console.log(`[BATCH] Last movie: ${works[works.length - 1]?.title} (work_id: ${works[works.length - 1]?.work_id}, tmdb_id: ${works[works.length - 1]?.tmdb_id})`);
    
    const results = [];
    
    for (let i = 0; i < works.length; i++) {
      const work = works[i];
      try {
        console.log(`[BATCH] [${i + 1}/${works.length}] Processing: ${work.title} (TMDB ID: ${work.tmdb_id}, work_id: ${work.work_id})`);
        
        // Call ingest function for each movie with force_refresh flag
        const response = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
          },
          body: JSON.stringify({ tmdb_id: work.tmdb_id, force_refresh: forceRefresh }),
        });
        
        const result = await response.json();
        
        if (response.ok) {
          results.push({ 
            tmdb_id: work.tmdb_id, 
            title: work.title,
            work_id: work.work_id,
            status: 'success',
            ingested_work_id: result.work_id 
          });
          console.log(`[BATCH] ✅ [${i + 1}/${works.length}] Success: ${work.title}`);
        } else {
          results.push({ 
            tmdb_id: work.tmdb_id, 
            title: work.title,
            work_id: work.work_id,
            status: 'error', 
            error: result.error 
          });
          console.log(`[BATCH] ❌ [${i + 1}/${works.length}] Error: ${work.title} - ${result.error}`);
        }
        
        // Rate limiting: wait 250ms between requests (TMDB allows ~40 req/10s)
        await new Promise(resolve => setTimeout(resolve, 250));
        
      } catch (error) {
        results.push({ 
          tmdb_id: work.tmdb_id, 
          title: work.title,
          work_id: work.work_id,
          status: 'error', 
          error: error.message 
        });
        console.log(`[BATCH] ❌ [${i + 1}/${works.length}] Exception: ${work.title} - ${error.message}`);
      }
    }
    
    const successCount = results.filter(r => r.status === 'success').length;
    const errorCount = results.filter(r => r.status === 'error').length;
    
    console.log(`[BATCH] Completed: ${successCount} success, ${errorCount} errors`);
    
    return new Response(
      JSON.stringify({ 
        processed: results.length,
        success: successCount,
        errors: errorCount,
        total_count: count || works.length,
        force_refresh: forceRefresh,
        limit: limit,
        offset: offset,
        has_more: count ? (offset + limit < count) : false,
        next_offset: count && (offset + limit < count) ? offset + limit : null,
        results 
      }), 
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('[BATCH] Batch ingest error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
