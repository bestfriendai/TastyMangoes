//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Search TMDB and return matching movies

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { searchMovies, buildImageUrl } from '../_shared/tmdb.ts';

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const query = url.searchParams.get('q');
    const year = url.searchParams.get('year');
    
    if (!query) {
      return new Response(
        JSON.stringify({ error: 'q (query) required' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    const results = await searchMovies(query, year ? parseInt(year) : undefined);
    
    // Transform to our format
    const movies = results.results.slice(0, 20).map((m) => ({
      tmdb_id: m.id.toString(),
      title: m.title,
      year: m.release_date ? parseInt(m.release_date.substring(0, 4)) : null,
      poster_url: buildImageUrl(m.poster_path, 'w154'),
      overview_short: m.overview ? (m.overview.substring(0, 100) + (m.overview.length > 100 ? '...' : '')) : null,
      vote_average: m.vote_average,
      vote_count: m.vote_count,
    }));
    
    return new Response(
      JSON.stringify({ movies }), 
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('Search movies error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

