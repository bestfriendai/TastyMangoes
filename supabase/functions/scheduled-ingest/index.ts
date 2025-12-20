//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-19 at 19:00 (America/Los_Angeles - Pacific Time)
//  Notes: Scheduled ingestion function that proactively ingests popular and trending movies from TMDB

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const TMDB_API_KEY = Deno.env.get('TMDB_API_KEY');
const TMDB_BASE = 'https://api.themoviedb.org/3';
const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

interface TMDBMovieResult {
  id: number;
  title: string;
  release_date?: string;
  poster_path?: string;
  overview?: string;
  vote_average?: number;
  vote_count?: number;
}

interface TMDBSearchResponse {
  page: number;
  results: TMDBMovieResult[];
  total_pages: number;
  total_results: number;
}

interface RequestBody {
  source?: 'popular' | 'now_playing' | 'trending' | 'all';
  max_movies?: number;
  trigger_type?: 'scheduled' | 'manual';
}

interface IngestedMovie {
  tmdb_id: string;
  title: string;
  year: number | null;
}

serve(async (req) => {
  const startTime = Date.now();
  
  try {
    // Parse request body
    let body: RequestBody = {};
    try {
      if (req.method === 'POST') {
        const bodyText = await req.text();
        if (bodyText) {
          body = JSON.parse(bodyText);
        }
      }
    } catch (error) {
      console.warn('[SCHEDULED] Failed to parse request body:', error);
    }
    
    const source = body.source || 'all';
    const maxMovies = body.max_movies || 20;
    const triggerType = body.trigger_type || 'scheduled';
    
    console.log(`[SCHEDULED] Starting scheduled ingestion - source: ${source}, max_movies: ${maxMovies}, trigger_type: ${triggerType}`);
    
    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Step 1: Fetch TMDB lists based on source
    const tmdbMovies: TMDBMovieResult[] = [];
    
    if (source === 'all' || source === 'popular') {
      console.log('[SCHEDULED] Fetching popular movies...');
      await new Promise(resolve => setTimeout(resolve, 500)); // Rate limit delay
      
      const popularResponse = await fetch(
        `${TMDB_BASE}/movie/popular?api_key=${TMDB_API_KEY}&page=1&language=en-US`
      );
      if (popularResponse.ok) {
        const popularData: TMDBSearchResponse = await popularResponse.json();
        tmdbMovies.push(...popularData.results);
        console.log(`[SCHEDULED] Fetched ${popularData.results.length} popular movies`);
      } else {
        console.error(`[SCHEDULED] Failed to fetch popular: ${popularResponse.status}`);
      }
    }
    
    if (source === 'all' || source === 'now_playing') {
      console.log('[SCHEDULED] Fetching now playing movies...');
      await new Promise(resolve => setTimeout(resolve, 500)); // Rate limit delay
      
      const nowPlayingResponse = await fetch(
        `${TMDB_BASE}/movie/now_playing?api_key=${TMDB_API_KEY}&page=1&language=en-US`
      );
      if (nowPlayingResponse.ok) {
        const nowPlayingData: TMDBSearchResponse = await nowPlayingResponse.json();
        tmdbMovies.push(...nowPlayingData.results);
        console.log(`[SCHEDULED] Fetched ${nowPlayingData.results.length} now playing movies`);
      } else {
        console.error(`[SCHEDULED] Failed to fetch now_playing: ${nowPlayingResponse.status}`);
      }
    }
    
    if (source === 'all' || source === 'trending') {
      console.log('[SCHEDULED] Fetching trending movies...');
      await new Promise(resolve => setTimeout(resolve, 500)); // Rate limit delay
      
      const trendingResponse = await fetch(
        `${TMDB_BASE}/trending/movie/week?api_key=${TMDB_API_KEY}&page=1&language=en-US`
      );
      if (trendingResponse.ok) {
        const trendingData: TMDBSearchResponse = await trendingResponse.json();
        tmdbMovies.push(...trendingData.results);
        console.log(`[SCHEDULED] Fetched ${trendingData.results.length} trending movies`);
      } else {
        console.error(`[SCHEDULED] Failed to fetch trending: ${trendingResponse.status}`);
      }
    }
    
    // Step 2: Deduplicate by TMDB ID
    const uniqueMoviesMap = new Map<number, TMDBMovieResult>();
    for (const movie of tmdbMovies) {
      if (!uniqueMoviesMap.has(movie.id)) {
        uniqueMoviesMap.set(movie.id, movie);
      }
    }
    const uniqueMovies = Array.from(uniqueMoviesMap.values());
    const uniqueIds = uniqueMovies.map(m => m.id.toString());
    
    console.log(`[SCHEDULED] Collected ${uniqueMovies.length} unique movies from TMDB`);
    
    if (uniqueMovies.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'No movies fetched from TMDB',
          movies_checked: 0,
          movies_skipped: 0,
          movies_ingested: 0,
          movies_failed: 0,
          duration_ms: Date.now() - startTime
        }), 
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Step 3: Check which movies already exist in works table
    const { data: existingWorks, error: checkError } = await supabase
      .from('works')
      .select('tmdb_id')
      .in('tmdb_id', uniqueIds);
    
    if (checkError) {
      console.error('[SCHEDULED] Error checking existing works:', checkError);
      throw checkError;
    }
    
    const existingIds = new Set(existingWorks?.map(w => w.tmdb_id) || []);
    const newMovies = uniqueMovies.filter(m => !existingIds.has(m.id.toString()));
    
    console.log(`[SCHEDULED] Found ${existingIds.size} existing movies, ${newMovies.length} new movies to ingest`);
    
    // Step 4: Ingest new movies (max maxMovies)
    const toIngest = newMovies.slice(0, maxMovies);
    const ingested: IngestedMovie[] = [];
    const failed: Array<{ tmdb_id: string; title: string; error: string }> = [];
    
    console.log(`[SCHEDULED] Ingesting ${toIngest.length} movies (max: ${maxMovies})`);
    
    for (let i = 0; i < toIngest.length; i++) {
      const movie = toIngest[i];
      const tmdbId = movie.id.toString();
      
      console.log(`[SCHEDULED] [${i + 1}/${toIngest.length}] Ingesting: ${movie.title} (TMDB ID: ${tmdbId})`);
      
      try {
        // Call ingest-movie Edge Function internally
        const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`
          },
          body: JSON.stringify({ tmdb_id: tmdbId })
        });
        
        const ingestResult = await ingestResponse.json();
        
        if (ingestResponse.ok) {
          const year = movie.release_date ? parseInt(movie.release_date.substring(0, 4)) : null;
          ingested.push({
            tmdb_id: tmdbId,
            title: movie.title,
            year: year
          });
          console.log(`[SCHEDULED] ✅ [${i + 1}/${toIngest.length}] Success: ${movie.title}`);
        } else {
          failed.push({
            tmdb_id: tmdbId,
            title: movie.title,
            error: ingestResult.error || 'Unknown error'
          });
          console.error(`[SCHEDULED] ❌ [${i + 1}/${toIngest.length}] Failed: ${movie.title} - ${ingestResult.error}`);
        }
      } catch (error) {
        failed.push({
          tmdb_id: tmdbId,
          title: movie.title,
          error: error.message || 'Exception during ingestion'
        });
        console.error(`[SCHEDULED] ❌ [${i + 1}/${toIngest.length}] Exception: ${movie.title} - ${error.message}`);
      }
      
      // Rate limiting: wait 1000ms between ingest calls (don't overwhelm)
      if (i < toIngest.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    const durationMs = Date.now() - startTime;
    const successCount = ingested.length;
    const failCount = failed.length;
    
    console.log(`[SCHEDULED] Completed: ${successCount} ingested, ${failCount} failed, duration: ${durationMs}ms`);
    
    // Step 5: Log to scheduled_ingestion_log table
    try {
      const logData = {
        source: source === 'all' ? 'mixed' : source,
        movies_checked: uniqueMovies.length,
        movies_skipped: existingIds.size,
        movies_ingested: successCount,
        movies_failed: failCount,
        ingested_titles: ingested.map(m => `${m.title} (${m.year || '?'})`),
        failed_titles: failed.map(f => `${f.title}: ${f.error}`),
        duration_ms: durationMs,
        trigger_type: triggerType,
        created_at: new Date().toISOString()
      };
      
      const { error: logError } = await supabase
        .from('scheduled_ingestion_log')
        .insert(logData);
      
      if (logError) {
        console.error('[SCHEDULED] Failed to log to scheduled_ingestion_log:', logError);
        // Don't fail the whole function if logging fails
      } else {
        console.log('[SCHEDULED] Logged results to scheduled_ingestion_log');
      }
    } catch (logErr) {
      console.error('[SCHEDULED] Exception logging results:', logErr);
      // Don't fail the whole function if logging fails
    }
    
    // Return response
    return new Response(
      JSON.stringify({
        success: true,
        movies_checked: uniqueMovies.length,
        movies_skipped: existingIds.size,
        movies_ingested: successCount,
        movies_failed: failCount,
        ingested: ingested,
        failed: failed.length > 0 ? failed : undefined,
        duration_ms: durationMs
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    const durationMs = Date.now() - startTime;
    console.error('[SCHEDULED] Scheduled ingestion error:', error);
    
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
