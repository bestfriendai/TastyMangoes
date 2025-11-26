//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Main ingestion pipeline for fetching movie data from TMDB and storing in database

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { 
  fetchMovieDetails, 
  fetchMovieCredits, 
  fetchMovieVideos,
  buildImageUrl,
  formatRuntime 
} from '../_shared/tmdb.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    const { tmdb_id, force_refresh = false } = await req.json();
    
    if (!tmdb_id) {
      return new Response(
        JSON.stringify({ error: 'tmdb_id required' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Check if movie exists and if it needs refresh
    const { data: existingWork, error: lookupError } = await supabase
      .from('works')
      .select('work_id, last_refreshed_at, release_date')
      .eq('tmdb_id', tmdb_id.toString())
      .maybeSingle();
    
    if (lookupError && lookupError.code !== 'PGRST116') {
      throw lookupError;
    }
    
    if (existingWork && !force_refresh) {
      // Check staleness using the database function
      const { data: isStale, error: staleError } = await supabase
        .rpc('is_stale', { work_id_input: existingWork.work_id });
      
      if (staleError) {
        console.warn('Error checking staleness:', staleError);
        // Continue with refresh if staleness check fails
      } else if (!isStale) {
        // Return cached card
        const { data: cachedCard } = await supabase
          .from('work_cards_cache')
          .select('payload')
          .eq('work_id', existingWork.work_id)
          .single();
        
        if (cachedCard) {
          return new Response(
            JSON.stringify({ 
              status: 'cached', 
              work_id: existingWork.work_id,
              card: cachedCard.payload 
            }),
            { headers: { 'Content-Type': 'application/json' } }
          );
        }
      }
    }
    
    // Fetch fresh data from TMDB
    const [details, credits, videos] = await Promise.all([
      fetchMovieDetails(tmdb_id.toString()),
      fetchMovieCredits(tmdb_id.toString()),
      fetchMovieVideos(tmdb_id.toString())
    ]);
    
    // Find the official trailer
    const trailer = videos.results.find(v => 
      v.type === 'Trailer' && v.site === 'YouTube' && v.official
    ) || videos.results.find(v => 
      v.type === 'Trailer' && v.site === 'YouTube'
    ) || videos.results[0];
    
    // Build cast array (top 15)
    const castMembers = credits.cast.slice(0, 15).map(c => ({
      person_id: c.id.toString(),
      name: c.name,
      character: c.character,
      order: c.order,
      photo_url_small: buildImageUrl(c.profile_path, 'w92'),
      photo_url_medium: buildImageUrl(c.profile_path, 'w185'),
      photo_url_large: buildImageUrl(c.profile_path, 'h632'),
      gender: c.gender === 1 ? 'female' : c.gender === 2 ? 'male' : 'unknown',
    }));
    
    // Build crew array (key roles only)
    const keyRoles = ['Director', 'Writer', 'Screenplay', 'Producer', 'Director of Photography', 'Original Music Composer'];
    const crewMembers = credits.crew
      .filter(c => keyRoles.includes(c.job))
      .slice(0, 10)
      .map(c => ({
        person_id: c.id.toString(),
        name: c.name,
        job: c.job,
        department: c.department,
        photo_url_small: buildImageUrl(c.profile_path, 'w92'),
        photo_url_medium: buildImageUrl(c.profile_path, 'w185'),
      }));
    
    // Extract year from release_date
    const year = details.release_date ? parseInt(details.release_date.substring(0, 4)) : null;
    
    // Upsert into works table
    const workData = {
      tmdb_id: tmdb_id.toString(),
      imdb_id: details.imdb_id || null,
      title: details.title,
      original_title: details.original_title,
      year: year,
      release_date: details.release_date || null,
      last_refreshed_at: new Date().toISOString(),
    };
    
    const { data: work, error: workError } = await supabase
      .from('works')
      .upsert(workData, { onConflict: 'tmdb_id' })
      .select('work_id')
      .single();
    
    if (workError) throw workError;
    
    // Upsert into works_meta table
    const metaData = {
      work_id: work.work_id,
      runtime_minutes: details.runtime || null,
      runtime_display: formatRuntime(details.runtime),
      tagline: details.tagline || null,
      overview: details.overview || null,
      overview_short: details.overview ? (details.overview.substring(0, 150) + (details.overview.length > 150 ? '...' : '')) : null,
      genres: details.genres.map(g => g.name),
      poster_url_small: buildImageUrl(details.poster_path, 'w154'),
      poster_url_medium: buildImageUrl(details.poster_path, 'w342'),
      poster_url_large: buildImageUrl(details.poster_path, 'w500'),
      poster_url_original: buildImageUrl(details.poster_path, 'original'),
      backdrop_url: buildImageUrl(details.backdrop_path, 'w1280'),
      backdrop_url_mobile: buildImageUrl(details.backdrop_path, 'w780'),
      trailer_youtube_id: trailer?.key || null,
      cast_members: castMembers,
      crew_members: crewMembers,
      fetched_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    
    const { error: metaError } = await supabase
      .from('works_meta')
      .upsert(metaData, { onConflict: 'work_id' });
    
    if (metaError) throw metaError;
    
    // Insert TMDB rating
    const { error: ratingError } = await supabase
      .from('rating_sources')
      .upsert({
        work_id: work.work_id,
        source_name: 'TMDB',
        scale_type: '0_10',
        value_raw: details.vote_average,
        value_0_100: details.vote_average * 10,
        votes_count: details.vote_count,
        last_seen_at: new Date().toISOString(),
      }, { onConflict: 'work_id,source_name' });
    
    if (ratingError) throw ratingError;
    
    // Compute AI Score (for now, just use TMDB; expand later)
    const aiScore = details.vote_average * 10;
    
    const { error: aggregateError } = await supabase
      .from('aggregates')
      .upsert({
        work_id: work.work_id,
        method_version: 'v1_2025_11',
        n_audience: 1,
        audience_score: aiScore,
        ai_score: aiScore,
        ai_score_low: Math.max(0, aiScore - 5),
        ai_score_high: Math.min(100, aiScore + 5),
        source_scores: {
          tmdb: { score: aiScore, votes: details.vote_count }
        },
        computed_at: new Date().toISOString(),
      }, { onConflict: 'work_id,method_version' });
    
    if (aggregateError) throw aggregateError;
    
    // Build and cache movie card
    const movieCard = {
      work_id: work.work_id,
      tmdb_id: tmdb_id.toString(),
      imdb_id: details.imdb_id || null,
      title: details.title,
      original_title: details.original_title,
      year: year,
      release_date: details.release_date || null,
      runtime_minutes: details.runtime || null,
      runtime_display: formatRuntime(details.runtime),
      tagline: details.tagline || null,
      overview: details.overview || null,
      overview_short: metaData.overview_short,
      genres: metaData.genres,
      poster: {
        small: metaData.poster_url_small,
        medium: metaData.poster_url_medium,
        large: metaData.poster_url_large,
      },
      backdrop: metaData.backdrop_url,
      trailer_youtube_id: metaData.trailer_youtube_id,
      cast: castMembers.slice(0, 8), // Top 8 for card
      director: crewMembers.find(c => c.job === 'Director')?.name || null,
      ai_score: aiScore,
      ai_score_range: [Math.max(0, aiScore - 5), Math.min(100, aiScore + 5)],
      source_scores: {
        tmdb: { score: aiScore, votes: details.vote_count }
      },
      last_updated: new Date().toISOString(),
    };
    
    const { error: cacheError } = await supabase
      .from('work_cards_cache')
      .upsert({
        work_id: work.work_id,
        payload: movieCard,
        payload_short: {
          work_id: work.work_id,
          title: details.title,
          year: year,
          poster: metaData.poster_url_medium,
          ai_score: aiScore,
        },
        etag: btoa(JSON.stringify({ work_id: work.work_id, updated: Date.now() })),
        computed_at: new Date().toISOString(),
      }, { onConflict: 'work_id' });
    
    if (cacheError) throw cacheError;
    
    return new Response(
      JSON.stringify({
        status: 'ingested',
        work_id: work.work_id,
        card: movieCard,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('Ingest error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

