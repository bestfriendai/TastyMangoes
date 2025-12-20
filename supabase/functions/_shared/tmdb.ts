//  tmdb.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Shared TMDB API utilities for Edge Functions

const TMDB_API_KEY = Deno.env.get('TMDB_API_KEY');
const TMDB_BASE = 'https://api.themoviedb.org/3';
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';

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

export async function fetchMovieDetails(tmdbId: string): Promise<TMDBMovie> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}?api_key=${TMDB_API_KEY}&language=en-US`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
}

export async function fetchMovieCredits(tmdbId: string): Promise<TMDBCredits> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/credits?api_key=${TMDB_API_KEY}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB credits error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
}

export async function fetchMovieVideos(tmdbId: string): Promise<TMDBVideos> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/videos?api_key=${TMDB_API_KEY}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB videos error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
}

export async function searchMovies(query: string, year?: number, page: number = 1): Promise<TMDBSearchResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  let url = `${TMDB_BASE}/search/movie?api_key=${TMDB_API_KEY}&query=${encodeURIComponent(query)}&page=${page}`;
  if (year) {
    url += `&year=${year}`;
  }
  
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB search error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
}

export interface TMDBDiscoverParams {
  primaryReleaseDateGte?: string; // Format: YYYY-MM-DD
  primaryReleaseDateLte?: string; // Format: YYYY-MM-DD
  withGenres?: number[]; // Array of genre IDs
  sortBy?: string; // e.g., "popularity.desc"
  page?: number;
}

export async function discoverMovies(params: TMDBDiscoverParams): Promise<TMDBSearchResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
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
  
  const url = `${TMDB_BASE}/discover/movie?${urlParams.toString()}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB discover error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
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

export async function fetchSimilarMovies(tmdbId: string): Promise<TMDBSimilarMoviesResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/similar?api_key=${TMDB_API_KEY}&language=en-US`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB similar movies error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
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

export async function fetchMovieReleaseDates(tmdbId: string): Promise<TMDBReleaseDatesResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/release_dates?api_key=${TMDB_API_KEY}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB release dates error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
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

export async function fetchMovieImages(tmdbId: string): Promise<TMDBImagesResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/images?api_key=${TMDB_API_KEY}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB images error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
}

export interface TMDBKeywordsResponse {
  id: number;
  keywords: Array<{ id: number; name: string }>;
}

export async function fetchMovieKeywords(tmdbId: string): Promise<TMDBKeywordsResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/keywords?api_key=${TMDB_API_KEY}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB keywords error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
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

export async function fetchMovieWatchProviders(tmdbId: string): Promise<TMDBWatchProvidersResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  const url = `${TMDB_BASE}/movie/${tmdbId}/watch/providers?api_key=${TMDB_API_KEY}`;
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB watch providers error: ${response.status} ${response.statusText}`);
  }
  
  return response.json();
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

