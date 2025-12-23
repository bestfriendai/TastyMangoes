//  tmdb.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-22 at 12:58 (America/Los_Angeles - Pacific Time)
//  Notes: Shared TMDB API utilities for Edge Functions with API call logging

const TMDB_API_KEY = Deno.env.get('TMDB_API_KEY');
const TMDB_BASE = 'https://api.themoviedb.org/3';
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';

// Get Supabase client for logging (lazy initialization)
let supabaseClient: any = null;
async function getSupabaseClient() {
  if (!supabaseClient) {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    // Try both possible env var names (Supabase uses SERVICE_ROLE_KEY)
    const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('[TMDB] Missing environment variables:', {
        hasUrl: !!supabaseUrl,
        hasServiceKey: !!supabaseServiceKey,
        envVars: Object.keys(Deno.env.toObject()).filter(k => k.includes('SERVICE') || k.includes('SUPABASE')),
      });
      throw new Error('Missing SUPABASE_URL or SERVICE_ROLE_KEY');
    }
    
    supabaseClient = createClient(supabaseUrl, supabaseServiceKey);
    console.log('[TMDB] Supabase client initialized for logging');
  }
  return supabaseClient;
}

// Log TMDB API call to database (async, fire-and-forget)
export async function logTMDBCall(params: {
  endpoint: string;
  method: string;
  httpStatus: number;
  queryParams?: Record<string, any>;
  requestBody?: any;
  responseSizeBytes?: number;
  responseTimeMs: number;
  resultsCount?: number;
  edgeFunction?: string;
  userQuery?: string;
  tmdbId?: string;
  voiceEventId?: string;
  errorMessage?: string;
  retryCount?: number;
  metadata?: Record<string, any>;
}) {
  try {
    console.log('[TMDB] Attempting to log API call:', {
      endpoint: params.endpoint,
      edgeFunction: params.edgeFunction,
      userQuery: params.userQuery,
      tmdbId: params.tmdbId,
    });
    
    const supabase = await getSupabaseClient();
    
    // Verify we have a valid client
    if (!supabase) {
      console.error('[TMDB] Supabase client is null, cannot log API call');
      return;
    }
    
    const insertData = {
      endpoint: params.endpoint,
      method: params.method,
      http_status: params.httpStatus,
      query_params: params.queryParams || null,
      request_body: params.requestBody || null,
      response_size_bytes: params.responseSizeBytes || null,
      response_time_ms: params.responseTimeMs,
      results_count: params.resultsCount || null,
      edge_function: params.edgeFunction || null,
      user_query: params.userQuery || null,
      tmdb_id: params.tmdbId || null,
      voice_event_id: params.voiceEventId || null,
      error_message: params.errorMessage || null,
      retry_count: params.retryCount || 0,
      metadata: params.metadata || null,
    };
    
    console.log('[TMDB] Inserting log data:', JSON.stringify(insertData, null, 2));
    
    const { data, error } = await supabase.from('tmdb_api_logs').insert(insertData).select();
    
    if (error) {
      console.error('[TMDB] Failed to insert log:', error);
      console.error('[TMDB] Error code:', error.code);
      console.error('[TMDB] Error message:', error.message);
      console.error('[TMDB] Error details:', JSON.stringify(error, null, 2));
      console.error('[TMDB] Error hint:', error.hint);
    } else {
      console.log('[TMDB] Successfully logged API call. ID:', data?.[0]?.id);
    }
  } catch (error) {
    // Don't fail the main request if logging fails
    console.error('[TMDB] Exception while logging API call:', error);
    console.error('[TMDB] Error type:', typeof error);
    console.error('[TMDB] Error stack:', error instanceof Error ? error.stack : String(error));
    if (error instanceof Error) {
      console.error('[TMDB] Error name:', error.name);
      console.error('[TMDB] Error message:', error.message);
    }
  }
}

// Helper to extract endpoint from full URL
function extractEndpoint(url: string): string {
  try {
    const urlObj = new URL(url);
    return urlObj.pathname;
  } catch {
    return url;
  }
}

export interface TMDBMovie {
  id: number;
  imdb_id?: string;
  title: string;
  original_title: string;
  release_date: string;
  runtime: number;
  tagline: string;
  overview: string;
  genres: { id: number; name: string }[];
  poster_path: string;
  backdrop_path: string;
  vote_average: number;
  vote_count: number;
  adult?: boolean;
  budget?: number;
  homepage?: string;
  original_language?: string;
  popularity?: number;
  production_companies?: Array<{ id: number; name: string; logo_path?: string }>;
  production_countries?: Array<{ iso_3166_1: string; name: string }>;
  revenue?: number;
  spoken_languages?: Array<{ iso_639_1: string; name: string; english_name?: string }>;
  status?: string;
  video?: boolean;
  belongs_to_collection?: {
    id: number;
    name: string;
    poster_path?: string;
    backdrop_path?: string;
  } | null;
}

export interface TMDBCastMember {
  id: number;
  name: string;
  character: string;
  order: number;
  profile_path: string;
  gender: number;
  known_for_department: string;
}

export interface TMDBCrewMember {
  id: number;
  name: string;
  job: string;
  department: string;
  profile_path: string;
}

export interface TMDBCredits {
  cast: TMDBCastMember[];
  crew: TMDBCrewMember[];
}

export interface TMDBVideo {
  key: string;
  name: string;
  type: string;
  site: string;
  size?: number;
  official?: boolean;
  published_at?: string;
  id?: string;
}

export interface TMDBVideos {
  results: TMDBVideo[];
}

export interface TMDBSearchResult {
  id: number;
  title: string;
  release_date: string;
  poster_path: string;
  overview: string;
  vote_average: number;
  vote_count: number;
  genre_ids?: number[]; // Genre IDs from TMDB
}

export interface TMDBSearchResponse {
  page: number;
  results: TMDBSearchResult[];
  total_pages: number;
  total_results: number;
}

export async function fetchMovieDetails(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string }
): Promise<TMDBMovie> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}`;
  
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}&language=en-US`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        queryParams: { language: 'en-US' },
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    
    // Log successful call
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      queryParams: { language: 'en-US' },
      responseTimeMs,
      responseSizeBytes,
      edgeFunction: context?.edgeFunction,
      tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        queryParams: { language: 'en-US' },
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export async function fetchMovieCredits(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBCredits> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/credits`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB credits error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = (data?.cast?.length || 0) + (data?.crew?.length || 0);
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB credits error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export async function fetchMovieVideos(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBVideos> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/videos`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB videos error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = data?.results?.length || 0;
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB videos error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export async function searchMovies(
  query: string, 
  year?: number, 
  page: number = 1,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string }
): Promise<TMDBSearchResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = '/search/movie';
  const queryParams: Record<string, any> = { query, page };
  if (year) queryParams.year = year;
  
  let url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}&query=${encodeURIComponent(query)}&page=${page}`;
  if (year) {
    url += `&year=${year}`;
  }
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB search error: ${response.status} ${response.statusText}`;
      // Log error
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        queryParams,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        userQuery: context?.userQuery || query,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = data?.results?.length || 0;
    
    // Log successful call (async, don't wait)
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      queryParams,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      userQuery: context?.userQuery || query,
      voiceEventId: context?.voiceEventId,
      metadata: {
        total_pages: data?.total_pages,
        total_results: data?.total_results,
      },
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    // Log error if not already logged
    if (!(error instanceof Error && error.message.includes('TMDB search error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        queryParams,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        userQuery: context?.userQuery || query,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export interface TMDBDiscoverParams {
  primaryReleaseDateGte?: string; // Format: YYYY-MM-DD
  primaryReleaseDateLte?: string; // Format: YYYY-MM-DD
  withGenres?: number[]; // Array of genre IDs
  sortBy?: string; // e.g., "popularity.desc"
  page?: number;
}

export async function discoverMovies(
  params: TMDBDiscoverParams,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string }
): Promise<TMDBSearchResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = '/discover/movie';
  
  const urlParams = new URLSearchParams({
    api_key: TMDB_API_KEY,
    page: String(params.page || 1),
    sort_by: params.sortBy || 'popularity.desc',
  });
  
  if (params.primaryReleaseDateGte) {
    urlParams.append('primary_release_date.gte', params.primaryReleaseDateGte);
  }
  
  if (params.primaryReleaseDateLte) {
    urlParams.append('primary_release_date.lte', params.primaryReleaseDateLte);
  }
  
  if (params.withGenres && params.withGenres.length > 0) {
    urlParams.append('with_genres', params.withGenres.join(','));
  }
  
  const queryParams: Record<string, any> = {
    page: params.page || 1,
    sort_by: params.sortBy || 'popularity.desc',
  };
  if (params.primaryReleaseDateGte) queryParams.primary_release_date_gte = params.primaryReleaseDateGte;
  if (params.primaryReleaseDateLte) queryParams.primary_release_date_lte = params.primaryReleaseDateLte;
  if (params.withGenres && params.withGenres.length > 0) queryParams.with_genres = params.withGenres;
  
  const url = `${TMDB_BASE}${endpoint}?${urlParams.toString()}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB discover error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        queryParams,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = data?.results?.length || 0;
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      queryParams,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
      metadata: {
        total_pages: data?.total_pages,
        total_results: data?.total_results,
      },
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB discover error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        queryParams,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export interface TMDBSimilarMoviesResponse {
  page: number;
  results: Array<{
    id: number;
    title: string;
    release_date: string;
    poster_path: string;
    vote_average: number;
  }>;
  total_pages: number;
  total_results: number;
}

export async function fetchSimilarMovies(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBSimilarMoviesResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/similar`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}&language=en-US`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB similar movies error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        queryParams: { language: 'en-US' },
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = data?.results?.length || 0;
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      queryParams: { language: 'en-US' },
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
      metadata: {
        total_pages: data?.total_pages,
        total_results: data?.total_results,
      },
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB similar movies error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        queryParams: { language: 'en-US' },
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export interface TMDBReleaseDatesResponse {
  id: number;
  results: Array<{
    iso_3166_1: string;
    release_dates: Array<{
      certification?: string;
      release_date?: string;
      type?: number;
    }>;
  }>;
}

export async function fetchMovieReleaseDates(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBReleaseDatesResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/release_dates`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB release dates error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = data?.results?.length || 0;
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB release dates error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export interface TMDBImage {
  file_path: string;
  width?: number;
  height?: number;
  aspect_ratio?: number;
  iso_639_1?: string | null;
  vote_average?: number;
  vote_count?: number;
}

export interface TMDBImagesResponse {
  id: number;
  backdrops: TMDBImage[];
  posters: TMDBImage[];
  logos: TMDBImage[];
}

export async function fetchMovieImages(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBImagesResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/images`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB images error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = (data?.posters?.length || 0) + (data?.backdrops?.length || 0) + (data?.logos?.length || 0);
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB images error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export interface TMDBKeywordsResponse {
  id: number;
  keywords: Array<{ id: number; name: string }>;
}

export async function fetchMovieKeywords(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBKeywordsResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/keywords`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB keywords error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const resultsCount = data?.keywords?.length || 0;
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      responseTimeMs,
      responseSizeBytes,
      resultsCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB keywords error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export interface TMDBWatchProvider {
  provider_id: number;
  provider_name: string;
  logo_path: string | null;
  display_priority: number;
}

export interface TMDBWatchProviderCountry {
  link?: string;
  flatrate?: TMDBWatchProvider[];  // Subscription streaming (Netflix, etc.)
  rent?: TMDBWatchProvider[];      // Rent (Apple TV, Amazon, etc.)
  buy?: TMDBWatchProvider[];       // Purchase
  ads?: TMDBWatchProvider[];       // Free with ads (Tubi, etc.)
  free?: TMDBWatchProvider[];      // Free (Kanopy, etc.)
}

export interface TMDBWatchProvidersResponse {
  id: number;
  results: {
    [countryCode: string]: TMDBWatchProviderCountry;
  };
}

export async function fetchMovieWatchProviders(
  tmdbId: string,
  context?: { edgeFunction?: string; userQuery?: string; voiceEventId?: string; tmdbId?: string }
): Promise<TMDBWatchProvidersResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const startTime = Date.now();
  const endpoint = `/movie/${tmdbId}/watch/providers`;
  const url = `${TMDB_BASE}${endpoint}?api_key=${TMDB_API_KEY}`;
  
  try {
    const response = await fetch(url);
    const responseTimeMs = Date.now() - startTime;
    const responseText = await response.text();
    const responseSizeBytes = new TextEncoder().encode(responseText).length;
    
    if (!response.ok) {
      const errorMsg = `TMDB watch providers error: ${response.status} ${response.statusText}`;
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: response.status,
        responseTimeMs,
        responseSizeBytes,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: errorMsg,
      });
      throw new Error(errorMsg);
    }
    
    const data = JSON.parse(responseText);
    const providerCount = Object.keys(data?.results || {}).reduce((sum, country) => {
      const countryProviders = data.results[country];
      return sum + (countryProviders?.flatrate?.length || 0) + 
                    (countryProviders?.rent?.length || 0) + 
                    (countryProviders?.buy?.length || 0) +
                    (countryProviders?.ads?.length || 0) +
                    (countryProviders?.free?.length || 0);
    }, 0);
    
    logTMDBCall({
      endpoint,
      method: 'GET',
      httpStatus: response.status,
      responseTimeMs,
      responseSizeBytes,
      resultsCount: providerCount,
      edgeFunction: context?.edgeFunction,
      tmdbId: context?.tmdbId || tmdbId,
      userQuery: context?.userQuery,
      voiceEventId: context?.voiceEventId,
    });
    
    return data;
  } catch (error) {
    const responseTimeMs = Date.now() - startTime;
    if (!(error instanceof Error && error.message.includes('TMDB watch providers error'))) {
      logTMDBCall({
        endpoint,
        method: 'GET',
        httpStatus: 0,
        responseTimeMs,
        edgeFunction: context?.edgeFunction,
        tmdbId: context?.tmdbId || tmdbId,
        userQuery: context?.userQuery,
        voiceEventId: context?.voiceEventId,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
    throw error;
  }
}

export function buildImageUrl(path: string | null, size: string = 'w500'): string {
  if (!path) return '';
  return `${TMDB_IMAGE_BASE}/${size}${path}`;
}

export function formatRuntime(minutes: number | null | undefined): string {
  if (!minutes) return '';
  
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  
  if (hours > 0 && mins > 0) {
    return `${hours}h ${mins}m`;
  } else if (hours > 0) {
    return `${hours}h`;
  } else {
    return `${mins}m`;
  }
}

/**
 * Download an image from a URL and return as ArrayBuffer
 */
export async function downloadImage(url: string): Promise<ArrayBuffer | null> {
  if (!url) return null;
  
  try {
    const response = await fetch(url);
    if (!response.ok) {
      console.warn(`Failed to download image from ${url}: ${response.status}`);
      return null;
    }
    return await response.arrayBuffer();
  } catch (error) {
    console.warn(`Error downloading image from ${url}:`, error);
    return null;
  }
}

/**
 * Download YouTube thumbnail
 * Tries maxresdefault first, falls back to hqdefault
 */
export async function downloadYouTubeThumbnail(youtubeId: string): Promise<ArrayBuffer | null> {
  if (!youtubeId) return null;
  
  // Try maxresdefault first
  const maxresUrl = `https://img.youtube.com/vi/${youtubeId}/maxresdefault.jpg`;
  const maxresImage = await downloadImage(maxresUrl);
  
  if (maxresImage) {
    // Check if it's actually an image (not the default "video unavailable" placeholder)
    // YouTube returns a 120x90 placeholder if maxres doesn't exist
    const view = new Uint8Array(maxresImage.slice(0, 100));
    const header = Array.from(view.slice(0, 4));
    
    // If it's a valid JPEG, return it
    if (header[0] === 0xFF && header[1] === 0xD8) {
      // Check file size - placeholder is usually very small
      if (maxresImage.byteLength > 5000) {
        return maxresImage;
      }
    }
  }
  
  // Fallback to hqdefault
  const hqUrl = `https://img.youtube.com/vi/${youtubeId}/hqdefault.jpg`;
  return await downloadImage(hqUrl);
}

