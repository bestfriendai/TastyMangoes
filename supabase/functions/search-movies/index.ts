//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Hybrid search - queries local database first, then supplements with TMDB results. Deduplicates by tmdb_id (prefers local results).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { searchMovies, discoverMovies, buildImageUrl } from '../_shared/tmdb.ts';

// TMDB genre ID mapping (genre name -> genre ID)
const GENRE_MAP: Record<string, number> = {
  'Action': 28,
  'Adventure': 12,
  'Animation': 16,
  'Comedy': 35,
  'Crime': 80,
  'Documentary': 99,
  'Drama': 18,
  'Family': 10751,
  'Fantasy': 14,
  'History': 36,
  'Historical': 36,
  'Horror': 27,
  'Music': 10402,
  'Musical': 10402,
  'Mystery': 9648,
  'Romance': 10749,
  'Science Fiction': 878,
  'Sci-Fi': 878,
  'TV Movie': 10770,
  'Thriller': 53,
  'War': 10752,
  'Western': 37,
  'Biography': 18,
  'Sport': 18
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }

  try {
    console.log(`[SEARCH] Received ${req.method} request to ${req.url}`);
    
    const url = new URL(req.url);
    const query = url.searchParams.get('q');
    const yearFrom = url.searchParams.get('year_from');
    const yearTo = url.searchParams.get('year_to');
    const genresParam = url.searchParams.get('genres'); // Comma-separated genre names
    
    console.log(`[SEARCH] Query params - q: "${query}", year_from: ${yearFrom}, year_to: ${yearTo}, genres: ${genresParam}`);
    
    // Parse year range
    const yearFromInt = yearFrom ? parseInt(yearFrom) : null;
    const yearToInt = yearTo ? parseInt(yearTo) : null;
    
    // Parse genres - convert genre names to TMDB genre IDs
    const genreIds: number[] = [];
    if (genresParam) {
      const genreNames = genresParam.split(',').map(g => g.trim());
      console.log(`[SEARCH] Parsing genres: ${JSON.stringify(genreNames)}`);
      for (const genreName of genreNames) {
        // Try exact match first
        if (GENRE_MAP[genreName]) {
          genreIds.push(GENRE_MAP[genreName]);
          console.log(`[SEARCH] Mapped "${genreName}" -> ${GENRE_MAP[genreName]}`);
        } else {
          // Try case-insensitive match
          const found = Object.entries(GENRE_MAP).find(
            ([key]) => key.toLowerCase() === genreName.toLowerCase()
          );
          if (found) {
            genreIds.push(found[1]);
            console.log(`[SEARCH] Mapped "${genreName}" -> ${found[1]} (case-insensitive match)`);
          } else {
            console.warn(`[SEARCH] Genre "${genreName}" not found in GENRE_MAP`);
          }
        }
      }
      console.log(`[SEARCH] Final genre IDs: ${JSON.stringify(genreIds)}`);
    } else {
      console.log(`[SEARCH] No genres parameter provided`);
    }
    
    const hasFilters = (yearFromInt || yearToInt) || genreIds.length > 0;
    const queryTrimmed = query ? query.trim() : '';
    const hasQuery = queryTrimmed.length > 0;
    
    // Validation: require either query or filters
    if (!hasQuery && !hasFilters) {
      return new Response(
        JSON.stringify({ error: 'Either q (query) or filters (year_from, year_to, genres) required' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Initialize Supabase client for local database queries
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    let allResults: Array<{ id: number; title: string; release_date: string; poster_path: string; overview: string; vote_average: number; vote_count: number; genre_ids?: number[] }> = [];
    let localResults: Array<{ tmdb_id: string; title: string; year: number | null; poster_url: string | null; overview_short: string | null; vote_average: number; vote_count: number }> = [];
    let localTmdbIds = new Set<string>();
    let apiCallsMade = 0;
    
    // Step 1: Query local database first (only if we have a text query)
    if (hasQuery) {
      try {
        console.log(`[SEARCH] Querying local database for: "${queryTrimmed}"`);
        
        // Build query with ILIKE title matching
        // Use left joins to works_meta and aggregates (optional)
        let localQuery = supabase
          .from('works')
          .select(`
            tmdb_id,
            title,
            year,
            release_date,
            works_meta(
              poster_url_medium,
              overview_short,
              genres
            ),
            aggregates(
              ai_score,
              source_scores
            )
          `)
          .ilike('title', `%${queryTrimmed}%`)
          .limit(20);
        
        // Apply year filter if provided
        if (yearFromInt) {
          localQuery = localQuery.gte('year', yearFromInt);
        }
        if (yearToInt) {
          localQuery = localQuery.lte('year', yearToInt);
        }
        
        const { data: localMovies, error: localError } = await localQuery;
        
        if (localError) {
          console.warn(`[SEARCH] Local database query error:`, localError);
        } else if (localMovies && localMovies.length > 0) {
          console.log(`[SEARCH] Found ${localMovies.length} movies in local database`);
          
          // Get genre names from genre IDs for filtering
          const genreNames: string[] = [];
          if (genreIds.length > 0 && genresParam) {
            // Use the original genre names from the request
            genreNames.push(...genresParam.split(',').map(g => g.trim()));
          }
          
          // Transform local results to match expected format
          localResults = localMovies
            .map((movie: any) => {
              const tmdbId = movie.tmdb_id;
              
              // Get poster URL from works_meta (it's an array from the join, take first if exists)
              const meta = Array.isArray(movie.works_meta) && movie.works_meta.length > 0 
                ? movie.works_meta[0] 
                : null;
              
              // Filter by genres if provided
              if (genreNames.length > 0 && meta?.genres) {
                const movieGenres = Array.isArray(meta.genres) ? meta.genres : [];
                const hasMatchingGenre = genreNames.some(genreName => 
                  movieGenres.some((g: string) => g.toLowerCase() === genreName.toLowerCase())
                );
                if (!hasMatchingGenre) {
                  return null; // Filter out this movie
                }
              }
              
              localTmdbIds.add(tmdbId);
              const posterUrl = meta?.poster_url_medium || null;
              
              // Get overview from works_meta
              const overviewShort = meta?.overview_short || null;
              
              // Get vote_average from aggregates (ai_score) or source_scores
              const agg = Array.isArray(movie.aggregates) && movie.aggregates.length > 0
                ? movie.aggregates[0]
                : null;
              const aiScore = agg?.ai_score;
              const sourceScores = agg?.source_scores;
              const voteAverage = aiScore ? aiScore / 10 : (sourceScores?.tmdb?.score || 0); // Convert 0-100 to 0-10 scale
              const voteCount = sourceScores?.tmdb?.votes || 0;
              
              return {
                tmdb_id: tmdbId,
                title: movie.title,
                year: movie.year,
                poster_url: posterUrl,
                overview_short: overviewShort,
                vote_average: voteAverage,
                vote_count: voteCount,
              };
            })
            .filter((result: any) => result !== null); // Remove filtered out movies
          
          console.log(`[SEARCH] Local results: ${localResults.length} movies (tmdb_ids: ${Array.from(localTmdbIds).slice(0, 5).join(', ')}${localTmdbIds.size > 5 ? '...' : ''})`);
        } else {
          console.log(`[SEARCH] No local movies found for: "${queryTrimmed}"`);
        }
      } catch (localError) {
        console.warn(`[SEARCH] Error querying local database:`, localError);
        // Continue with TMDB search even if local query fails
      }
    }
    
    // Logic flow:
    // 1. If query is empty AND filters are active → use discover endpoint (1 call)
    // 2. If query has text AND filters are active → use search endpoint, fetch up to 3 pages (up to 3 calls)
    // 3. Otherwise (query has text, no filters) → use search endpoint, fetch 1 page only (1 call)
    
    if (!hasQuery && hasFilters) {
      // Case 1: Filter-only search - use discover endpoint (1 API call)
      console.log(`[SEARCH] Using discover endpoint (filter-only search)`);
      
      try {
        const discoverParams: any = {
          page: 1,
          sortBy: 'popularity.desc',
        };
        
        // Add year range filters
        if (yearFromInt) {
          discoverParams.primaryReleaseDateGte = `${yearFromInt}-01-01`;
        }
        if (yearToInt) {
          discoverParams.primaryReleaseDateLte = `${yearToInt}-12-31`;
        }
        
        // Add genre filters
        if (genreIds.length > 0) {
          discoverParams.withGenres = genreIds;
        }
        
        const discoverResponse = await discoverMovies(discoverParams, {
          edgeFunction: 'search-movies',
        });
        allResults = discoverResponse?.results || [];
        apiCallsMade = 1;
        
        console.log(`[SEARCH] Discover returned ${allResults.length} results (1 API call)`);
      } catch (discoverError) {
        console.error(`[SEARCH] Discover endpoint error:`, discoverError);
        // Fall back to empty results rather than failing completely
        allResults = [];
        apiCallsMade = 0;
      }
      
    } else if (hasQuery && hasFilters) {
      // Case 2: Text + filters - use search endpoint, fetch up to 3 pages (up to 3 calls)
      console.log(`[SEARCH] Using search endpoint with filters (text + filters)`);
      
      try {
        const maxPages = 3; // Reduced from 5 to 3 (60 results instead of 100)
        let currentPage = 1;
        let totalPages = 1;
        
        do {
          const singleYear = (yearFromInt && yearToInt && yearFromInt === yearToInt) ? yearFromInt : undefined;
          const pageResults = await searchMovies(queryTrimmed, singleYear, currentPage, {
            edgeFunction: 'search-movies',
            userQuery: queryTrimmed,
          });
          
          if (currentPage === 1) {
            totalPages = pageResults?.total_pages || 1;
          }
          
          if (pageResults?.results) {
            allResults = allResults.concat(pageResults.results);
          }
          apiCallsMade++;
          currentPage++;
          
          // Stop if we have enough results or reached max pages
          if (allResults.length >= 60 || currentPage > maxPages || currentPage > totalPages) {
            break;
          }
          
          // Small delay to respect rate limits
          await new Promise(resolve => setTimeout(resolve, 100));
        } while (currentPage <= maxPages && currentPage <= totalPages);
      } catch (searchError) {
        console.error(`[SEARCH] Search endpoint error:`, searchError);
        // Continue with whatever results we have so far
      }
      
      console.log(`[SEARCH] Fetched ${allResults.length} total results from ${apiCallsMade} page(s)`);
      
      // Filter results by year range and genres (client-side filtering)
      // Apply year filter AFTER getting TMDB results but BEFORE returning to client
      if (yearFromInt || yearToInt) {
        const beforeCount = allResults.length;
        const fromYear = yearFromInt || 0;
        const toYear = yearToInt || 9999;
        
        console.log(`[SEARCH] Applying year filter: ${yearFromInt || 'any'} to ${yearToInt || 'any'}`);
        console.log(`[SEARCH] Before filtering: ${beforeCount} results`);
        
        allResults = allResults.filter((movie) => {
          // Extract year from release_date (format: "YYYY-MM-DD")
          const releaseYear = movie.release_date 
            ? parseInt(movie.release_date.substring(0, 4)) 
            : null;
          
          if (!releaseYear || isNaN(releaseYear)) {
            // Exclude movies with no year or invalid year
            return false;
          }
          
          // Check if year is within range: releaseYear >= fromYear && releaseYear <= toYear
          const passes = releaseYear >= fromYear && releaseYear <= toYear;
          
          if (!passes) {
            console.log(`[SEARCH] Filtered out: ${movie.title} (${releaseYear}) - outside range ${fromYear}-${toYear}`);
          }
          
          return passes;
        });
        
        console.log(`[SEARCH] Year filter: ${beforeCount} -> ${allResults.length} results (kept movies within ${fromYear}-${toYear})`);
      } else {
        console.log(`[SEARCH] No year filter applied (yearFromInt=${yearFromInt}, yearToInt=${yearToInt})`);
      }
      
      // Filter by genres (TMDB search results include genre_ids)
      if (genreIds.length > 0) {
        const beforeCount = allResults.length;
        console.log(`[SEARCH] Applying genre filter with IDs: ${JSON.stringify(genreIds)}`);
        console.log(`[SEARCH] Before filtering: ${beforeCount} results`);
        
        // Debug: Log genre_ids for first few movies
        allResults.slice(0, 3).forEach((m, idx) => {
          console.log(`[SEARCH] Movie ${idx + 1}: "${m.title}" has genre_ids: ${JSON.stringify(m.genre_ids)}`);
        });
        
        allResults = allResults.filter((m) => {
          // TMDB search results have genre_ids array
          if (!m.genre_ids || m.genre_ids.length === 0) {
            console.log(`[SEARCH] Filtered out "${m.title}": no genre_ids`);
            return false;
          }
          // Check if movie has at least one of the requested genres
          const hasMatchingGenre = m.genre_ids.some(id => genreIds.includes(id));
          if (!hasMatchingGenre) {
            console.log(`[SEARCH] Filtered out "${m.title}": genre_ids ${JSON.stringify(m.genre_ids)} don't match ${JSON.stringify(genreIds)}`);
          }
          return hasMatchingGenre;
        });
        console.log(`[SEARCH] Genre filter: ${beforeCount} -> ${allResults.length} results (kept movies with genres ${JSON.stringify(genreIds)})`);
      } else {
        console.log(`[SEARCH] No genre filter applied (genreIds.length = 0)`);
      }
      
    } else {
      // Case 3: Text-only (no filters) - use search endpoint, fetch 1 page only (1 call)
      console.log(`[SEARCH] Using search endpoint (text-only, no filters)`);
      
      try {
        const searchResponse = await searchMovies(queryTrimmed, undefined, 1, {
          edgeFunction: 'search-movies',
          userQuery: queryTrimmed,
        });
        allResults = searchResponse?.results || [];
        apiCallsMade = 1;
        
        console.log(`[SEARCH] Search returned ${allResults.length} results (1 API call)`);
      } catch (searchError) {
        console.error(`[SEARCH] Search endpoint error:`, searchError);
        allResults = [];
        apiCallsMade = 0;
      }
    }
    
    // Step 2: Filter out TMDB results that are already in local database (deduplication)
    if (localTmdbIds.size > 0) {
      const beforeCount = allResults.length;
      allResults = allResults.filter((movie) => {
        const tmdbId = movie.id?.toString();
        const isDuplicate = tmdbId && localTmdbIds.has(tmdbId);
        if (isDuplicate) {
          console.log(`[SEARCH] Filtering out duplicate TMDB result: ${movie.title} (tmdb_id: ${tmdbId}) - already in local database`);
        }
        return !isDuplicate;
      });
      console.log(`[SEARCH] Deduplication: ${beforeCount} -> ${allResults.length} TMDB results (removed ${beforeCount - allResults.length} duplicates)`);
    }
    
    // Transform TMDB results to our format
    const tmdbMovies = (allResults || []).slice(0, 50).map((m) => {
      // Safely handle potentially missing fields
      const year = m.release_date ? parseInt(m.release_date.substring(0, 4)) : null;
      const overview = m.overview || '';
      const overviewShort = overview.length > 100 ? overview.substring(0, 100) + '...' : overview;
      
      return {
        tmdb_id: m.id?.toString() || '',
        title: m.title || 'Unknown',
        year: (year && !isNaN(year)) ? year : null,
        poster_url: m.poster_path ? buildImageUrl(m.poster_path, 'w154') : null,
        overview_short: overviewShort || null,
        vote_average: m.vote_average || 0,
        vote_count: m.vote_count || 0,
      };
    });
    
    // Combine local results (preferred) with TMDB results
    // Local results come first, then TMDB results
    const movies = [...localResults, ...tmdbMovies].slice(0, 50);
    
    console.log(`[SEARCH] Query: "${queryTrimmed || '(none)'}", Year: ${yearFromInt || 'any'}-${yearToInt || 'any'}, Genres: ${genreIds.length > 0 ? genreIds.join(',') : 'any'}, Results: ${movies.length} (${localResults.length} local + ${tmdbMovies.length} TMDB), API Calls: ${apiCallsMade}`);
    
    // Always return a valid response with movies array
    const responseBody = { movies: movies || [] };
    console.log(`[SEARCH] Returning response with ${movies.length} movies`);
    
    return new Response(
      JSON.stringify(responseBody), 
      { 
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        } 
      }
    );
    
  } catch (error) {
    console.error('Search movies error:', error);
    console.error('Error stack:', error.stack);
    // Return error but still include movies array to prevent parsing errors
    const errorResponse = { 
      error: error.message || 'Unknown error',
      movies: [] // Always include movies array
    };
    console.log(`[SEARCH] Returning error response:`, JSON.stringify(errorResponse));
    
    const errorJson = JSON.stringify(errorResponse);
    console.log(`[SEARCH] Error response JSON: ${errorJson}`);
    
    return new Response(
      errorJson, 
      { 
        status: 500, 
        headers: { 
          'Content-Type': 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        } 
      }
    );
  }
});


