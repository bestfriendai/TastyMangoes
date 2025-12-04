//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: Log voice interaction events to Supabase for analytics
//
//  Expected schema for voice_utterance_events table:
//  CREATE TABLE IF NOT EXISTS voice_utterance_events (
//    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
//    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
//    utterance TEXT NOT NULL,
//    mango_command_type TEXT NOT NULL,
//    mango_command_raw TEXT NOT NULL,
//    mango_command_movie_title TEXT,
//    mango_command_recommender TEXT,
//    llm_used BOOLEAN DEFAULT false,
//    final_command_type TEXT NOT NULL,
//    final_command_raw TEXT NOT NULL,
//    final_command_movie_title TEXT,
//    final_command_recommender TEXT,
//    llm_intent TEXT,
//    llm_movie_title TEXT,
//    llm_recommender TEXT,
//    llm_error TEXT,
//    created_at TIMESTAMPTZ DEFAULT NOW()
//  );

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  // Handle CORS preflight
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

  try {
    console.log(`[LOG-VOICE] Received ${req.method} request`);
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    // Get current user from auth header
    const authHeader = req.headers.get('Authorization');
    let userId: string | null = null;
    
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '');
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (!error && user) {
        userId = user.id;
      }
    }
    
    // Parse request body
    const body = await req.json();
    
    console.log(`[LOG-VOICE] Logging voice event for user: ${userId || 'anonymous'}`);
    console.log(`[LOG-VOICE] Utterance: "${body.utterance}"`);
    console.log(`[LOG-VOICE] LLM used: ${body.llm_used}`);
    
    // Insert into voice_utterance_events table
    const { data, error } = await supabase
      .from('voice_utterance_events')
      .insert({
        user_id: userId,
        utterance: body.utterance,
        mango_command_type: body.mango_command_type,
        mango_command_raw: body.mango_command_raw,
        mango_command_movie_title: body.mango_command_movie_title || null,
        mango_command_recommender: body.mango_command_recommender || null,
        llm_used: body.llm_used || false,
        final_command_type: body.final_command_type,
        final_command_raw: body.final_command_raw,
        final_command_movie_title: body.final_command_movie_title || null,
        final_command_recommender: body.final_command_recommender || null,
        llm_intent: body.llm_intent || null,
        llm_movie_title: body.llm_movie_title || null,
        llm_recommender: body.llm_recommender || null,
        llm_error: body.llm_error || null,
      })
      .select()
      .single();
    
    if (error) {
      console.error(`[LOG-VOICE] Error inserting event:`, error);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[LOG-VOICE] Successfully logged event with id: ${data.id}`);
    
    return new Response(
      JSON.stringify({ success: true, id: data.id }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('[LOG-VOICE] Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

