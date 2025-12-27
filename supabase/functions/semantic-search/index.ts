//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:30 (America/Los_Angeles - Pacific Time)
//  Notes: Semantic search Edge Function using OpenAI to find movies and generate personalized reasons

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { fetchMovieDetails } from '../_shared/tmdb.ts';

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

interface SemanticSearchRequest {
  query: string;
  session_id?: string;
  session_context?: {
    queries?: Array<{ text: string; timestamp: string }>;
    shown_movie_ids?: number[];
    preferences?: Record<string, string>;
  };
  limit?: number;
}

interface SemanticMovie {
  status: 'ready' | 'loading';
  card?: any;
  preview?: {
    title: string;
    year?: number;
    tmdb_id?: number;
    poster_path?: string;
    vote_average?: number;
  };
  mango_reason: string;
  match_strength: 'strong' | 'good' | 'worth_considering';
  tags: string[];
}

interface SemanticSearchResponse {
  mango_voice: {
    text: string;
  };
  movies: SemanticMovie[];
  refinement_chips: string[];
  session_update: {
    add_to_shown: number[];
    detected_preferences: Record<string, string>;
  };
  meta: {
    query: string;
    interpretation: string;
    total_recommended: number;
    available_now: number;
    loading: number;
    confidence: string;
    openai_time_ms?: number;
    total_time_ms?: number;
  };
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }

  const startTime = Date.now();
  
  try {
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    
    // Get user from auth header
    const authHeader = req.headers.get('Authorization');
    let userId: string | null = null;
    
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '');
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (!error && user) {
        userId = user.id;
      }
    }
    
    const body: SemanticSearchRequest = await req.json();
    const { query, session_context, limit = 8 } = body;
    
    if (!query || !query.trim()) {
      return new Response(
        JSON.stringify({ error: 'Query is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    if (!OPENAI_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'OpenAI API key not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[SEMANTIC-SEARCH] Query: "${query}", User: ${userId || 'anonymous'}`);
    
    // Build context for OpenAI
    const queryHistory = session_context?.queries?.map(q => q.text).join(', ') || '';
    const shownIds = session_context?.shown_movie_ids || [];
    const preferences = session_context?.preferences || {};
    
    // Call OpenAI to get movie recommendations with reasons
    const openaiStartTime = Date.now();
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini', // Use cheaper model for cost efficiency
        messages: [
          {
            role: 'system',
            content: `You are Mango, a friendly movie recommendation assistant with personality. 
            When users ask about movies, find relevant movies from TMDB and explain WHY each movie matches their query.
            Be conversational, warm, and specific. Use the user's query history and preferences to personalize recommendations.
            
            Return a JSON object with:
            - interpretation: How you understood the query
            - movies: Array of {tmdb_id, title, year, reason, match_strength: "strong"|"good"|"worth_considering", tags: []}
            - refinement_chips: 3-5 suggested follow-up queries
            - mango_voice: A friendly spoken response (2-3 sentences)
            
            Match strength:
            - "strong": Perfect match, highly relevant
            - "good": Good match, relevant
            - "worth_considering": Related but less direct match
            
            Only include movies that exist in TMDB. Use real TMDB IDs when possible.`
          },
          {
            role: 'user',
            content: `User query: "${query}"
            ${queryHistory ? `Previous queries in this session: ${queryHistory}` : ''}
            ${Object.keys(preferences).length > 0 ? `Detected preferences: ${JSON.stringify(preferences)}` : ''}
            ${shownIds.length > 0 ? `Movies already shown to user: ${shownIds.join(', ')}` : ''}
            
            IMPORTANT: If this query appears to be a refinement (e.g., "war movies based on true stories" after "war movies"), 
            ensure the results match BOTH the original intent AND the refinement. For example:
            - "war movies based on true stories" should return WAR MOVIES that are ALSO based on true stories
            - Don't return general "true story" movies if they're not war movies
            
            Find ${limit} movies that match this query and explain why each one is a good fit.`
          }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.7,
      }),
    });
    
    const openaiTimeMs = Date.now() - openaiStartTime;
    
    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      console.error(`[SEMANTIC-SEARCH] OpenAI error: ${openaiResponse.status} ${errorText}`);
      throw new Error(`OpenAI API error: ${openaiResponse.status}`);
    }
    
    const openaiData = await openaiResponse.json();
    const aiContent = JSON.parse(openaiData.choices[0].message.content);
    
    console.log(`[SEMANTIC-SEARCH] OpenAI response received in ${openaiTimeMs}ms`);
    
    // Fetch movie cards from database for movies that exist
    const movies: SemanticMovie[] = [];
    const tmdbIds: number[] = [];
    
    for (const movie of aiContent.movies || []) {
      if (movie.tmdb_id) {
        tmdbIds.push(movie.tmdb_id);
      }
    }
    
    // Fetch movie cards for existing movies
    const { data: works } = await supabaseAdmin
      .from('works')
      .select('work_id, tmdb_id')
      .in('tmdb_id', tmdbIds.map(String));
    
    const workMap = new Map(works?.map(w => [w.tmdb_id, w.work_id]) || []);
    
    // Fetch movie cards from cache
    const { data: cards } = await supabaseAdmin
      .from('work_cards_cache')
      .select('*')
      .in('tmdb_id', tmdbIds.map(String));
    
    const cardMap = new Map(cards?.map(c => [c.tmdb_id, c]) || []);
    
    // Identify movies that need poster fetching (not in database)
    const moviesNeedingPosters = (aiContent.movies || []).filter(m => {
      const tmdbIdStr = String(m.tmdb_id);
      return !cardMap.has(tmdbIdStr);
    });
    
    // Fetch posters and scores in parallel for movies not in database
    const posterPromises = moviesNeedingPosters.map(async (movie) => {
      try {
        const tmdbDetails = await fetchMovieDetails(String(movie.tmdb_id), {
          edgeFunction: 'semantic-search',
          userQuery: query,
        });
        return { 
          tmdbId: movie.tmdb_id, 
          posterPath: tmdbDetails.poster_path || undefined,
          voteAverage: tmdbDetails.vote_average || undefined
        };
      } catch (err) {
        console.warn(`[SEMANTIC-SEARCH] Failed to fetch poster for ${movie.tmdb_id}:`, err);
        return { tmdbId: movie.tmdb_id, posterPath: undefined, voteAverage: undefined };
      }
    });
    
    const posterResults = await Promise.all(posterPromises);
    const posterMap = new Map(posterResults.map(r => [r.tmdbId, r.posterPath]));
    const scoreMap = new Map(posterResults.map(r => [r.tmdbId, r.voteAverage]));
    
    // Build response movies
    for (const movie of aiContent.movies || []) {
      const tmdbIdStr = String(movie.tmdb_id);
      const card = cardMap.get(tmdbIdStr);
      const workId = workMap.get(tmdbIdStr);
      
      if (card) {
        // Movie is ready (has card)
        movies.push({
          status: 'ready',
          card: card,
          mango_reason: movie.reason || `This movie matches your search for "${query}"`,
          match_strength: movie.match_strength || 'good',
          tags: movie.tags || [],
        });
        
        // Save user-specific AI recommendation if user is authenticated
        if (userId) {
          const recommendation = {
            user_id: userId,
            tmdb_id: tmdbIdStr,
            work_id: workId || null,
            mango_reason: movie.reason || `This movie matches your search for "${query}"`,
            query_context: query,
            match_strength: movie.match_strength || 'good',
            tags: movie.tags || [],
            session_id: body.session_id || null,
          };
          
          await supabaseAdmin
            .from('user_ai_recommendations')
            .upsert(recommendation, {
              onConflict: 'user_id,tmdb_id,query_context',
              ignoreDuplicates: false
            })
            .then(() => {
              console.log(`[SEMANTIC-SEARCH] Saved AI recommendation for user ${userId}, movie ${tmdbIdStr}`);
            })
            .catch(err => {
              console.error(`[SEMANTIC-SEARCH] Failed to save AI recommendation:`, err);
            });
        }
      } else {
        // Movie not in database yet - use poster and score from TMDB fetch
        const posterPath = posterMap.get(movie.tmdb_id);
        const voteAverage = scoreMap.get(movie.tmdb_id);
        
        // Return preview with poster and score
        movies.push({
          status: 'loading',
          preview: {
            title: movie.title,
            year: movie.year,
            tmdb_id: movie.tmdb_id,
            poster_path: posterPath,
            vote_average: voteAverage,
          },
          mango_reason: movie.reason || `This movie matches your search for "${query}"`,
          match_strength: movie.match_strength || 'good',
          tags: movie.tags || [],
        });
        
        // Save AI recommendation for loading movies too (without work_id)
        if (userId) {
          const recommendation = {
            user_id: userId,
            tmdb_id: tmdbIdStr,
            work_id: null, // Not in database yet
            mango_reason: movie.reason || `This movie matches your search for "${query}"`,
            query_context: query,
            match_strength: movie.match_strength || 'good',
            tags: movie.tags || [],
            session_id: body.session_id || null,
          };
          
          await supabaseAdmin
            .from('user_ai_recommendations')
            .upsert(recommendation, {
              onConflict: 'user_id,tmdb_id,query_context',
              ignoreDuplicates: false
            })
            .then(() => {
              console.log(`[SEMANTIC-SEARCH] Saved AI recommendation (loading) for user ${userId}, movie ${tmdbIdStr}`);
            })
            .catch(err => {
              console.error(`[SEMANTIC-SEARCH] Failed to save AI recommendation (loading):`, err);
            });
        }
      }
    }
    
    const totalTimeMs = Date.now() - startTime;
    
    const response: SemanticSearchResponse = {
      mango_voice: {
        text: aiContent.mango_voice || `I found ${movies.length} movies that match "${query}". Here are my top picks!`,
      },
      movies: movies.slice(0, limit),
      refinement_chips: aiContent.refinement_chips || [],
      session_update: {
        add_to_shown: movies.map(m => m.card?.tmdb_id || m.preview?.tmdb_id).filter(Boolean).map(Number),
        detected_preferences: preferences,
      },
      meta: {
        query: query,
        interpretation: aiContent.interpretation || query,
        total_recommended: movies.length,
        available_now: movies.filter(m => m.status === 'ready').length,
        loading: movies.filter(m => m.status === 'loading').length,
        confidence: 'high',
        openai_time_ms: openaiTimeMs,
        total_time_ms: totalTimeMs,
      },
    };
    
    console.log(`[SEMANTIC-SEARCH] Returning ${movies.length} movies (${response.meta.available_now} ready, ${response.meta.loading} loading) in ${totalTimeMs}ms`);
    
    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
    
  } catch (error) {
    console.error('[SEMANTIC-SEARCH] Error:', error);
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Internal server error',
        mango_voice: { text: "Hmm, I hit a snag. Let me try that again." },
        movies: [],
        refinement_chips: [],
        session_update: { add_to_shown: [], detected_preferences: {} },
        meta: {
          query: '',
          interpretation: '',
          total_recommended: 0,
          available_now: 0,
          loading: 0,
          confidence: 'low',
        },
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
});

