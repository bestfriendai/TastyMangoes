--  024_create_user_movie_reasons_table.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-01-15 at 23:30 (America/Los_Angeles - Pacific Time)
--  Notes: Table to store user-specific movie reasons from semantic search (mangoReason)

-- Create table for user-specific movie reasons
CREATE TABLE IF NOT EXISTS public.user_movie_reasons (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tmdb_id TEXT NOT NULL,
    work_id BIGINT REFERENCES public.works(work_id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    query TEXT NOT NULL, -- The original search query that led to this recommendation
    session_id TEXT, -- Optional: link to semantic search session
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    
    -- Ensure one reason per user per movie per query (user can get different reasons for different queries)
    UNIQUE(user_id, tmdb_id, query)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_movie_reasons_user_tmdb ON public.user_movie_reasons(user_id, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_user_movie_reasons_work_id ON public.user_movie_reasons(work_id);

-- Update updated_at on change
CREATE OR REPLACE FUNCTION update_user_movie_reasons_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_movie_reasons_updated_at
    BEFORE UPDATE ON public.user_movie_reasons
    FOR EACH ROW
    EXECUTE FUNCTION update_user_movie_reasons_updated_at();

-- RLS: Users can only see their own reasons
ALTER TABLE public.user_movie_reasons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own movie reasons"
    ON public.user_movie_reasons
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own movie reasons"
    ON public.user_movie_reasons
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own movie reasons"
    ON public.user_movie_reasons
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Service role can do everything (for Edge Functions)
CREATE POLICY "Service role can manage all movie reasons"
    ON public.user_movie_reasons
    FOR ALL
    USING (true)
    WITH CHECK (true);

