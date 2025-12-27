-- Migration: 025_create_user_ai_recommendations
-- Created automatically by Cursor Assistant
-- Created on: 2025-01-15 at 23:45 (America/Los_Angeles - Pacific Time)
-- Notes: Store AI-generated movie recommendations per user
-- Note: Separate from mango_tips which is for learned preferences and curated content

-- Create the table
CREATE TABLE IF NOT EXISTS public.user_ai_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    work_id INTEGER REFERENCES public.works(work_id) ON DELETE CASCADE,
    tmdb_id TEXT NOT NULL,
    mango_reason TEXT NOT NULL,
    query_context TEXT NOT NULL,           -- The search query that generated this
    match_strength TEXT,                   -- 'strong', 'good', 'worth_considering'
    tags TEXT[],                           -- ['christmas', 'comedy', 'family']
    session_id TEXT,                       -- Group related searches
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    -- Each user can have one recommendation per movie per query
    UNIQUE(user_id, tmdb_id, query_context)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_ai_recs_user_id ON public.user_ai_recommendations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_ai_recs_tmdb_id ON public.user_ai_recommendations(tmdb_id);
CREATE INDEX IF NOT EXISTS idx_user_ai_recs_user_tmdb ON public.user_ai_recommendations(user_id, tmdb_id);

-- Enable RLS
ALTER TABLE public.user_ai_recommendations ENABLE ROW LEVEL SECURITY;

-- Users can only see their own recommendations
DROP POLICY IF EXISTS "Users can view own AI recommendations" ON public.user_ai_recommendations;
CREATE POLICY "Users can view own AI recommendations"
    ON public.user_ai_recommendations
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own recommendations
DROP POLICY IF EXISTS "Users can insert own AI recommendations" ON public.user_ai_recommendations;
CREATE POLICY "Users can insert own AI recommendations"
    ON public.user_ai_recommendations
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own recommendations
DROP POLICY IF EXISTS "Users can update own AI recommendations" ON public.user_ai_recommendations;
CREATE POLICY "Users can update own AI recommendations"
    ON public.user_ai_recommendations
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own recommendations
DROP POLICY IF EXISTS "Users can delete own AI recommendations" ON public.user_ai_recommendations;
CREATE POLICY "Users can delete own AI recommendations"
    ON public.user_ai_recommendations
    FOR DELETE
    USING (auth.uid() = user_id);

-- Service role can do everything (for Edge Functions)
DROP POLICY IF EXISTS "Service role full access to AI recommendations" ON public.user_ai_recommendations;
CREATE POLICY "Service role full access to AI recommendations"
    ON public.user_ai_recommendations
    FOR ALL
    USING (auth.role() = 'service_role');

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_user_ai_recommendations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_user_ai_recommendations_updated_at ON public.user_ai_recommendations;
CREATE TRIGGER trigger_user_ai_recommendations_updated_at
    BEFORE UPDATE ON public.user_ai_recommendations
    FOR EACH ROW
    EXECUTE FUNCTION update_user_ai_recommendations_updated_at();

-- Add comment
COMMENT ON TABLE public.user_ai_recommendations IS 
'Stores AI-generated movie recommendations per user from semantic search. 
Separate from mango_tips which stores learned preferences and curated content.';

