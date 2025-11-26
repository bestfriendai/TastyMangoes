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
  spoken_languages?: Array<{ iso_639_1: string; name: string }>;
  status?: string;
  video?: boolean;
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

export async function searchMovies(query: string, year?: number): Promise<TMDBSearchResponse> {
  if (!TMDB_API_KEY) {
    throw new Error('TMDB_API_KEY environment variable not set');
  }
  
  let url = `${TMDB_BASE}/search/movie?api_key=${TMDB_API_KEY}&query=${encodeURIComponent(query)}`;
  if (year) {
    url += `&year=${year}`;
  }
  
  const response = await fetch(url);
  
  if (!response.ok) {
    throw new Error(`TMDB search error: ${response.status} ${response.statusText}`);
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

