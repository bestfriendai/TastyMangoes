--  013_add_scheduled_ingestion_log.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-01-15 at 23:50 (America/Los_Angeles - Pacific Time)
--  Notes: Create scheduled_ingestion_log table to track scheduled ingestion runs

-- ============================================
-- SCHEDULED INGESTION LOG TABLE
-- ============================================
-- Tracks each run of the scheduled-ingest Edge Function

CREATE TABLE IF NOT EXISTS public.scheduled_ingestion_log (
    id BIGSERIAL PRIMARY KEY,
    source TEXT NOT NULL, -- 'popular', 'now_playing', 'trending', 'mixed'
    movies_checked INT NOT NULL,
    movies_skipped INT NOT NULL,
    movies_ingested INT NOT NULL,
    movies_failed INT NOT NULL,
    ingested_titles TEXT[], -- Array of "Title (Year)" strings
    failed_titles TEXT[], -- Array of "Title: Error" strings
    duration_ms INT NOT NULL,
    trigger_type TEXT NOT NULL CHECK (trigger_type IN ('scheduled', 'manual')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_scheduled_ingestion_log_created_at ON public.scheduled_ingestion_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scheduled_ingestion_log_source ON public.scheduled_ingestion_log(source);
CREATE INDEX IF NOT EXISTS idx_scheduled_ingestion_log_trigger_type ON public.scheduled_ingestion_log(trigger_type);

-- Enable RLS
ALTER TABLE public.scheduled_ingestion_log ENABLE ROW LEVEL SECURITY;

-- Policy: Allow service role to insert (edge functions use service role)
CREATE POLICY "Service role can insert scheduled_ingestion_log"
    ON public.scheduled_ingestion_log
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Policy: Allow authenticated users to read (for dashboard)
CREATE POLICY "Authenticated users can read scheduled_ingestion_log"
    ON public.scheduled_ingestion_log
    FOR SELECT
    TO authenticated
    USING (true);

-- Add comments for documentation
COMMENT ON TABLE public.scheduled_ingestion_log IS 'Tracks scheduled ingestion runs from the scheduled-ingest Edge Function';
COMMENT ON COLUMN public.scheduled_ingestion_log.source IS 'TMDB source list: popular, now_playing, trending, or mixed (all)';
COMMENT ON COLUMN public.scheduled_ingestion_log.movies_checked IS 'Total movies checked from TMDB lists';
COMMENT ON COLUMN public.scheduled_ingestion_log.movies_skipped IS 'Movies that already existed in database';
COMMENT ON COLUMN public.scheduled_ingestion_log.movies_ingested IS 'Movies successfully ingested';
COMMENT ON COLUMN public.scheduled_ingestion_log.movies_failed IS 'Movies that failed ingestion';
COMMENT ON COLUMN public.scheduled_ingestion_log.duration_ms IS 'Total duration of ingestion run in milliseconds';
COMMENT ON COLUMN public.scheduled_ingestion_log.trigger_type IS 'How the run was triggered: scheduled or manual';

