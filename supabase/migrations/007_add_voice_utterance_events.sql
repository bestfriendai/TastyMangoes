--  007_add_voice_utterance_events.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
--  Notes: Add voice_utterance_events table for logging voice interactions and LLM fallback analytics

-- ============================================
-- VOICE UTTERANCE EVENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.voice_utterance_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    utterance TEXT NOT NULL,
    mango_command_type TEXT NOT NULL,
    mango_command_raw TEXT NOT NULL,
    mango_command_movie_title TEXT,
    mango_command_recommender TEXT,
    llm_used BOOLEAN DEFAULT false,
    final_command_type TEXT NOT NULL,
    final_command_raw TEXT NOT NULL,
    final_command_movie_title TEXT,
    final_command_recommender TEXT,
    llm_intent TEXT,
    llm_movie_title TEXT,
    llm_recommender TEXT,
    llm_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.voice_utterance_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own voice events
CREATE POLICY "Users can insert own voice events"
    ON public.voice_utterance_events FOR INSERT
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Policy: Users can view their own voice events
CREATE POLICY "Users can view own voice events"
    ON public.voice_utterance_events FOR SELECT
    USING (auth.uid() = user_id OR user_id IS NULL);

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_voice_utterance_events_user_id ON public.voice_utterance_events(user_id);
CREATE INDEX IF NOT EXISTS idx_voice_utterance_events_created_at ON public.voice_utterance_events(created_at);
CREATE INDEX IF NOT EXISTS idx_voice_utterance_events_llm_used ON public.voice_utterance_events(llm_used);

