//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 22:15 (America/Los_Angeles - Pacific Time)
//  Notes: Fetch similar movies with auto-ingestion and rate limiting

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

const STORAGE_BASE_URL = `${supabaseUrl}/storage/v1/object/public/movie-images`;

interface SimilarMovieResult {
  tmdb_id: number;
  title: string;
  year: number | null;
  poster_url: string | null;
  rating: number | null;
}

serve(async (req) => {
  try {
    const { tmdb_ids } = await req.json();
    
    if (!tmdb_ids || !Array.isArray(tmdb_ids) || tmdb_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: 'tmdb_ids array required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Limit to first 10 IDs
    const limitedIds = tmdb_ids.slice(0, 10).map(id => Number(id));
    console.log(`[SIMILAR] Processing ${limitedIds.length} similar movie IDs`);
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    
    const results: SimilarMovieResult[] = [];
    const ingestionPromises: Promise<void>[] = [];
    let concurrentIngestions = 0;
    const maxConcurrent = 3;
    
    // Process each movie ID
    for (const tmdbId of limitedIds) {
      // Check if movie exists in our database
      const { data: work, error: workError } = await supabase
        .from('works')
        .select('work_id, ingestion_status, title, year')
        .eq('tmdb_id', tmdbId.toString())
        .maybeSingle();
      
      if (workError && workError.code !== 'PGRST116') {
        console.error(`[SIMILAR] Error checking work for TMDB ID ${tmdbId}:`, workError);
        continue;
      }
      
      if (work && work.ingestion_status === 'complete') {
        // Movie is complete - fetch from database
        const { data: meta } = await supabase
          .from('works_meta')
          .select('poster_url_medium')
          .eq('work_id', work.work_id)
          .single();
        
        const { data: aggregate } = await supabase
          .from('aggregates')
          .select('ai_score')
          .eq('work_id', work.work_id)
          .eq('method_version', 'v1_2025_11')
          .single();
        
        const posterUrl = meta?.poster_url_medium || null;
        const rating = aggregate?.ai_score ? aggregate.ai_score / 10 : null;
        
        results.push({
          tmdb_id: tmdbId,
          title: work.title,
          year: work.year,
          poster_url: posterUrl,
          rating: rating,
        });
        
        console.log(`[SIMILAR] Found complete movie: ${work.title} (TMDB ID: ${tmdbId})`);
        
      } else if (work && work.ingestion_status === 'ingesting') {
        // Movie is being ingested - wait for completion
        console.log(`[SIMILAR] Movie ${tmdbId} is being ingested, waiting...`);
        
        const maxWaitTime = 30000; // 30 seconds
        const checkInterval = 500; // Check every 500ms
        const startTime = Date.now();
        let completed = false;
        
        while (Date.now() - startTime < maxWaitTime && !completed) {
          await new Promise(resolve => setTimeout(resolve, checkInterval));
          
          const { data: updatedWork } = await supabase
            .from('works')
            .select('work_id, ingestion_status, title, year')
            .eq('work_id', work.work_id)
            .single();
          
          if (updatedWork && updatedWork.ingestion_status === 'complete') {
            // Fetch from database
            const { data: meta } = await supabase
              .from('works_meta')
              .select('poster_url_medium')
              .eq('work_id', work.work_id)
              .single();
            
            const { data: aggregate } = await supabase
              .from('aggregates')
              .select('ai_score')
              .eq('work_id', work.work_id)
              .eq('method_version', 'v1_2025_11')
              .single();
            
            const posterUrl = meta?.poster_url_medium || null;
            const rating = aggregate?.ai_score ? aggregate.ai_score / 10 : null;
            
            results.push({
              tmdb_id: tmdbId,
              title: updatedWork.title,
              year: updatedWork.year,
              poster_url: posterUrl,
              rating: rating,
            });
            
            completed = true;
            console.log(`[SIMILAR] Ingestion completed for: ${updatedWork.title} (TMDB ID: ${tmdbId})`);
          } else if (updatedWork && updatedWork.ingestion_status === 'failed') {
            console.warn(`[SIMILAR] Ingestion failed for TMDB ID ${tmdbId}`);
            completed = true;
          }
        }
        
        if (!completed) {
          console.warn(`[SIMILAR] Timeout waiting for TMDB ID ${tmdbId} to complete ingestion`);
        }
        
      } else {
        // Movie doesn't exist - auto-ingest
        console.log(`[SIMILAR] Auto-ingesting TMDB ID: ${tmdbId}`);
        
        // Wait if we're at max concurrent ingestions
        while (concurrentIngestions >= maxConcurrent) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        
        concurrentIngestions++;
        
        // Add 250ms delay before starting ingestion
        await new Promise(resolve => setTimeout(resolve, 250));
        
        const ingestPromise = (async () => {
          try {
            const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${supabaseServiceKey}`,
              },
              body: JSON.stringify({ tmdb_id: tmdbId, force_refresh: false }),
            });
            
            if (!ingestResponse.ok) {
              const errorData = await ingestResponse.json();
              console.error(`[SIMILAR] Auto-ingest failed for TMDB ID ${tmdbId}:`, errorData);
              return;
            }
            
            const ingestResult = await ingestResponse.json();
            const workId = ingestResult.work_id || ingestResult.card?.work_id;
            
            if (workId) {
              // Fetch from database
              const { data: workData } = await supabase
                .from('works')
                .select('work_id, title, year')
                .eq('work_id', workId)
                .single();
              
              const { data: meta } = await supabase
                .from('works_meta')
                .select('poster_url_medium')
                .eq('work_id', workId)
                .single();
              
              const { data: aggregate } = await supabase
                .from('aggregates')
                .select('ai_score')
                .eq('work_id', workId)
                .eq('method_version', 'v1_2025_11')
                .single();
              
              const posterUrl = meta?.poster_url_medium || null;
              const rating = aggregate?.ai_score ? aggregate.ai_score / 10 : null;
              
              results.push({
                tmdb_id: tmdbId,
                title: workData?.title || 'Unknown',
                year: workData?.year || null,
                poster_url: posterUrl,
                rating: rating,
              });
              
              console.log(`[SIMILAR] Auto-ingest completed for: ${workData?.title} (TMDB ID: ${tmdbId})`);
            }
          } catch (error) {
            console.error(`[SIMILAR] Error auto-ingesting TMDB ID ${tmdbId}:`, error);
          } finally {
            concurrentIngestions--;
          }
        })();
        
        ingestionPromises.push(ingestPromise);
      }
    }
    
    // Wait for all ingestion promises to complete
    await Promise.all(ingestionPromises);
    
    console.log(`[SIMILAR] Returning ${results.length} similar movies`);
    
    return new Response(
      JSON.stringify({ movies: results }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('[SIMILAR] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

