--  018_create_refresh_queue_and_sync_state.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
--  Notes: Create works table (if missing), refresh_queue and sync_state tables for daily refresh

-- ============================================================================
-- STEP 1: Create works table with full minimal schema required by all Edge Functions
-- This ensures works exists before creating foreign keys in refresh_queue
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.works (
    work_id             BIGSERIAL PRIMARY KEY,
    tmdb_id             TEXT UNIQUE NOT NULL,
    imdb_id             TEXT UNIQUE,
    title               TEXT NOT NULL,
    original_title      TEXT,
    year                INT,
    release_date        DATE,
    
    -- Staleness tracking (required by is_stale() function and refresh queue)
    last_refreshed_at   TIMESTAMPTZ DEFAULT now(),
    request_count       INT DEFAULT 0,
    
    -- Ingestion status (required by ingest-movie and refresh-worker)
    ingestion_status    TEXT DEFAULT 'pending' NOT NULL
        CHECK (ingestion_status IN ('pending', 'ingesting', 'complete', 'failed')),
    
    -- Metadata
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Indexes required by Edge Functions and migrations
CREATE INDEX IF NOT EXISTS idx_works_tmdb_id ON public.works(tmdb_id);
CREATE INDEX IF NOT EXISTS idx_works_imdb_id ON public.works(imdb_id);
CREATE INDEX IF NOT EXISTS idx_works_title ON public.works(title);
CREATE INDEX IF NOT EXISTS idx_works_year ON public.works(year);
CREATE INDEX IF NOT EXISTS idx_works_release_date ON public.works(release_date);
CREATE INDEX IF NOT EXISTS idx_works_last_refreshed ON public.works(last_refreshed_at);
CREATE INDEX IF NOT EXISTS idx_works_ingestion_status ON public.works(ingestion_status);

-- Enable RLS
ALTER TABLE public.works ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Service role can manage, users can read
CREATE POLICY "Service role can manage works"
    ON public.works
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Users can read works"
    ON public.works
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Add comments
COMMENT ON TABLE public.works IS 
'The master index of all movies. One row per movie, minimal fields. Canonical source of truth for movie identity.';
COMMENT ON COLUMN public.works.work_id IS 
'Primary key, auto-incrementing BIGSERIAL';
COMMENT ON COLUMN public.works.tmdb_id IS 
'TMDB movie ID (unique, required). Used as primary identifier for ingestion.';
COMMENT ON COLUMN public.works.imdb_id IS 
'IMDb ID (unique, nullable). Alternative identifier.';
COMMENT ON COLUMN public.works.last_refreshed_at IS 
'Timestamp of last metadata refresh. Used by is_stale() function for refresh queue.';
COMMENT ON COLUMN public.works.ingestion_status IS 
'Status of ingestion: pending, ingesting, complete, or failed. Used by ingest-movie and refresh-worker.';
COMMENT ON COLUMN public.works.request_count IS 
'Number of times this movie has been requested. For analytics.';

-- ============================================================================
-- STEP 2: Create refresh_queue table (now that works is guaranteed to exist)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.refresh_queue (
    id BIGSERIAL PRIMARY KEY,
    work_id BIGINT NOT NULL REFERENCES works(work_id) ON DELETE CASCADE,
    priority INT DEFAULT 0, -- Higher priority = processed first
    status TEXT DEFAULT 'queued' NOT NULL
        CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    queued_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    processed_at TIMESTAMPTZ,
    retry_count INT DEFAULT 0 NOT NULL,
    last_error TEXT,
    UNIQUE(work_id) -- One entry per movie
);

-- Indexes for efficient queue processing
CREATE INDEX IF NOT EXISTS idx_refresh_queue_status_priority_queued 
    ON public.refresh_queue(status, priority DESC, queued_at);
CREATE INDEX IF NOT EXISTS idx_refresh_queue_work_id 
    ON public.refresh_queue(work_id);
CREATE INDEX IF NOT EXISTS idx_refresh_queue_queued_at 
    ON public.refresh_queue(queued_at);

-- Enable RLS
ALTER TABLE public.refresh_queue ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can manage refresh_queue (for Edge Functions)
CREATE POLICY "Service role can manage refresh_queue"
    ON public.refresh_queue
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: Authenticated users can read refresh_queue (for dashboard)
CREATE POLICY "Users can read refresh_queue"
    ON public.refresh_queue
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Add comments
COMMENT ON TABLE public.refresh_queue IS 
'Queue for movies that need metadata refresh. Populated by daily-refresh Edge Function, processed by refresh-worker.';
COMMENT ON COLUMN public.refresh_queue.priority IS 
'Higher priority values are processed first. Default is 0.';
COMMENT ON COLUMN public.refresh_queue.status IS 
'queued: Waiting to be processed; processing: Currently being refreshed; completed: Successfully refreshed; failed: Failed after retries';
COMMENT ON COLUMN public.refresh_queue.retry_count IS 
'Number of times this item has been retried. Max retries: 3.';

-- ============================================================================
-- TABLE: sync_state
-- Tracks the last sync time for various sync operations
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.sync_state (
    sync_type TEXT PRIMARY KEY, -- e.g., 'daily_refresh_stale'
    last_sync_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.sync_state ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can manage sync_state
CREATE POLICY "Service role can manage sync_state"
    ON public.sync_state
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: Users can read sync_state
CREATE POLICY "Users can read sync_state"
    ON public.sync_state
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Initialize sync_state for daily refresh
INSERT INTO public.sync_state (sync_type, last_sync_at, updated_at)
VALUES ('daily_refresh_stale', NULL, now())
ON CONFLICT (sync_type) DO NOTHING;

-- Add comments
COMMENT ON TABLE public.sync_state IS 
'Tracks last sync time for various sync operations (e.g., daily refresh enqueue).';
COMMENT ON COLUMN public.sync_state.sync_type IS 
'Unique identifier for the sync operation (e.g., ''daily_refresh_stale'').';
COMMENT ON COLUMN public.sync_state.last_sync_at IS 
'Timestamp of the last successful sync. NULL if never synced.';

