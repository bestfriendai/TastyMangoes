//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-19 at 19:00 (America/Los_Angeles - Pacific Time)
//  Notes: Scheduled ingestion function that proactively ingests popular and trending movies from TMDB

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { logTMDBCall } from '../_shared/tmdb.ts';

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
  source?: 'popular' | 'now_playing' | 'trending' | 'all' | 'mixed_daily' | 'mixed_weekly';
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
    // Calculate how many pages to fetch: each page has ~20 movies, fetch enough to get maxMovies unique
    // For "all" sources, we fetch from 3 lists, so we need fewer pages per list
    // For single source, we need more pages from that one list
    const moviesPerPage = 20;
    const sourcesToFetch = source === 'all' ? 3 : 1; // all = 3 lists, single = 1 list
    const pagesPerSource = Math.ceil((maxMovies * 1.5) / (moviesPerPage * sourcesToFetch)); // 1.5x buffer for deduplication
    const maxPagesPerSource = Math.min(pagesPerSource, 5); // Cap at 5 pages per source to avoid too many API calls
    
    console.log(`[SCHEDULED] Will fetch up to ${maxPagesPerSource} pages per source (target: ${maxMovies} movies)`);
    
    const tmdbMovies: TMDBMovieResult[] = [];
    
    // Helper function to fetch multiple pages from a TMDB endpoint with logging
    const fetchMultiplePages = async (endpoint: string, sourceName: string, maxPages: number) => {
      const movies: TMDBMovieResult[] = [];
      for (let page = 1; page <= maxPages; page++) {
        await new Promise(resolve => setTimeout(resolve, 500)); // Rate limit delay
        
        const startTime = Date.now();
        const url = `${endpoint}&page=${page}`;
        const response = await fetch(url);
        const responseTimeMs = Date.now() - startTime;
        const responseText = await response.text();
        const responseSizeBytes = new TextEncoder().encode(responseText).length;
        
        // Extract endpoint path for logging
        const endpointPath = new URL(url).pathname;
        const queryParams: Record<string, any> = { page };
        const urlObj = new URL(url);
        urlObj.searchParams.forEach((value, key) => {
          if (key !== 'api_key') queryParams[key] = value;
        });
        
        // Log the API call
        if (response.ok) {
          const data: TMDBSearchResponse = JSON.parse(responseText);
          const resultsCount = data?.results?.length || 0;
          
          logTMDBCall({
            endpoint: endpointPath,
            method: 'GET',
            httpStatus: response.status,
            queryParams,
            responseTimeMs,
            responseSizeBytes,
            resultsCount,
            edgeFunction: 'scheduled-ingest',
            metadata: {
              source: sourceName,
              page,
              total_pages: data?.total_pages,
              total_results: data?.total_results,
            },
          });
          
          movies.push(...data.results);
          console.log(`[SCHEDULED] Fetched page ${page}/${maxPages} of ${sourceName}: ${data.results.length} movies`);
          
          // Stop if we've reached the last page
          if (page >= data.total_pages) {
            console.log(`[SCHEDULED] Reached last page (${data.total_pages}) for ${sourceName}`);
            break;
          }
        } else {
          // Log error
          logTMDBCall({
            endpoint: endpointPath,
            method: 'GET',
            httpStatus: response.status,
            queryParams,
            responseTimeMs,
            responseSizeBytes,
            edgeFunction: 'scheduled-ingest',
            errorMessage: `Failed to fetch ${sourceName} page ${page}: ${response.status} ${response.statusText}`,
            metadata: {
              source: sourceName,
              page,
            },
          });
          
          console.error(`[SCHEDULED] Failed to fetch ${sourceName} page ${page}: ${response.status}`);
          break; // Stop on error
        }
      }
      return movies;
    };
    
    if (source === 'all' || source === 'popular') {
      console.log(`[SCHEDULED] Fetching popular movies (up to ${maxPagesPerSource} pages)...`);
      const popularMovies = await fetchMultiplePages(
        `${TMDB_BASE}/movie/popular?api_key=${TMDB_API_KEY}&language=en-US`,
        'popular',
        maxPagesPerSource
      );
      tmdbMovies.push(...popularMovies);
      console.log(`[SCHEDULED] Total popular movies fetched: ${popularMovies.length}`);
    }
    
    if (source === 'all' || source === 'now_playing') {
      console.log(`[SCHEDULED] Fetching now playing movies (up to ${maxPagesPerSource} pages)...`);
      const nowPlayingMovies = await fetchMultiplePages(
        `${TMDB_BASE}/movie/now_playing?api_key=${TMDB_API_KEY}&language=en-US`,
        'now_playing',
        maxPagesPerSource
      );
      tmdbMovies.push(...nowPlayingMovies);
      console.log(`[SCHEDULED] Total now playing movies fetched: ${nowPlayingMovies.length}`);
    }
    
    if (source === 'all' || source === 'trending') {
      console.log(`[SCHEDULED] Fetching trending movies (up to ${maxPagesPerSource} pages)...`);
      const trendingMovies = await fetchMultiplePages(
        `${TMDB_BASE}/trending/movie/week?api_key=${TMDB_API_KEY}&language=en-US`,
        'trending',
        maxPagesPerSource
      );
      tmdbMovies.push(...trendingMovies);
      console.log(`[SCHEDULED] Total trending movies fetched: ${trendingMovies.length}`);
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
        source: source === 'all' ? 'mixed' : (source === 'mixed_daily' || source === 'mixed_weekly' ? source : source),
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
