--  011_add_tmdb_api_logs_safe.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-22 at 13:20 (America/Los_Angeles - Pacific Time)
--  Notes: Safe version that adds columns if they don't exist (preserves existing data)

-- ============================================
-- TMDB API LOGS TABLE (Safe Migration)
-- ============================================
-- Tracks every TMDB API call made by edge functions

-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.tmdb_api_logs (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add columns if they don't exist (safe for existing tables)
DO $$ 
BEGIN
    -- API Call Details
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'endpoint') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN endpoint TEXT NOT NULL DEFAULT '';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'method') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN method TEXT NOT NULL DEFAULT 'GET';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'http_status') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN http_status INTEGER;
    END IF;
    
    -- Request Details
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'query_params') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN query_params JSONB;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'request_body') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN request_body JSONB;
    END IF;
    
    -- Response Details
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'response_size_bytes') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN response_size_bytes INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'response_time_ms') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN response_time_ms INTEGER NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'results_count') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN results_count INTEGER;
    END IF;
    
    -- Context
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'edge_function') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN edge_function TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'user_query') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN user_query TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'tmdb_id') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN tmdb_id TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'voice_event_id') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN voice_event_id UUID;
    END IF;
    
    -- Error Tracking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'error_message') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN error_message TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'retry_count') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN retry_count INTEGER DEFAULT 0;
    END IF;
    
    -- Metadata
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'metadata') THEN
        ALTER TABLE public.tmdb_api_logs ADD COLUMN metadata JSONB;
    END IF;
END $$;

-- Remove default from endpoint and method after ensuring they exist (if needed)
DO $$
BEGIN
    -- Only alter if column exists and has default
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tmdb_api_logs' AND column_name = 'endpoint' AND column_default IS NOT NULL) THEN
        ALTER TABLE public.tmdb_api_logs ALTER COLUMN endpoint DROP DEFAULT;
    END IF;
END $$;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_tmdb_api_logs_created_at ON public.tmdb_api_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tmdb_api_logs_endpoint ON public.tmdb_api_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_tmdb_api_logs_edge_function ON public.tmdb_api_logs(edge_function);
CREATE INDEX IF NOT EXISTS idx_tmdb_api_logs_voice_event_id ON public.tmdb_api_logs(voice_event_id);
CREATE INDEX IF NOT EXISTS idx_tmdb_api_logs_tmdb_id ON public.tmdb_api_logs(tmdb_id);
CREATE INDEX IF NOT EXISTS idx_tmdb_api_logs_http_status ON public.tmdb_api_logs(http_status);

-- Enable RLS
ALTER TABLE public.tmdb_api_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Service role can insert tmdb_api_logs" ON public.tmdb_api_logs;
DROP POLICY IF EXISTS "Authenticated users can read tmdb_api_logs" ON public.tmdb_api_logs;

-- Policy: Allow service role to insert (edge functions use service role)
CREATE POLICY "Service role can insert tmdb_api_logs"
    ON public.tmdb_api_logs
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Policy: Allow authenticated users to read (for dashboard)
CREATE POLICY "Authenticated users can read tmdb_api_logs"
    ON public.tmdb_api_logs
    FOR SELECT
    TO authenticated
    USING (true);

-- Add comments for documentation
COMMENT ON TABLE public.tmdb_api_logs IS 'Tracks all TMDB API calls made by edge functions for analytics and monitoring';
COMMENT ON COLUMN public.tmdb_api_logs.endpoint IS 'TMDB API endpoint path (e.g., /search/movie, /movie/123)';
COMMENT ON COLUMN public.tmdb_api_logs.query_params IS 'Query parameters sent to TMDB API';
COMMENT ON COLUMN public.tmdb_api_logs.response_time_ms IS 'Response time in milliseconds';
COMMENT ON COLUMN public.tmdb_api_logs.edge_function IS 'Which edge function made this call';
COMMENT ON COLUMN public.tmdb_api_logs.user_query IS 'Original user query that triggered this API call';
COMMENT ON COLUMN public.tmdb_api_logs.voice_event_id IS 'Link to voice_utterance_events table if triggered by voice search';
