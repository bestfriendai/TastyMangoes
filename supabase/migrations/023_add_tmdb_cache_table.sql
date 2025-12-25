--  023_add_tmdb_cache_table.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-24 at 00:00 (America/Los_Angeles - Pacific Time)
--  Notes: Add TMDB response caching to reduce API calls and improve performance

-- ============================================================================
-- TABLE: tmdb_cache
-- Caches TMDB API responses to reduce redundant API calls
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tmdb_cache (
    id BIGSERIAL PRIMARY KEY,
    cache_key TEXT UNIQUE NOT NULL, -- e.g., 'movie_details_123', 'search_movies_avengers'
    endpoint TEXT NOT NULL, -- e.g., '/movie/123', '/search/movie'
    response_data JSONB NOT NULL, -- Cached TMDB response
    expires_at TIMESTAMPTZ NOT NULL, -- When cache expires
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_tmdb_cache_key ON public.tmdb_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_tmdb_cache_endpoint ON public.tmdb_cache(endpoint);
CREATE INDEX IF NOT EXISTS idx_tmdb_cache_expires ON public.tmdb_cache(expires_at);

-- Enable RLS
ALTER TABLE public.tmdb_cache ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can manage cache
CREATE POLICY "Service role can manage tmdb_cache"
    ON public.tmdb_cache
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: Users can read cache (for debugging/monitoring)
CREATE POLICY "Users can read tmdb_cache"
    ON public.tmdb_cache
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Function to clean up expired cache entries (can be called periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_tmdb_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.tmdb_cache
    WHERE expires_at < now();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE public.tmdb_cache IS 
'Caches TMDB API responses to reduce redundant API calls. Cache keys are endpoint-specific (e.g., movie_details_123).';
COMMENT ON COLUMN public.tmdb_cache.cache_key IS 
'Unique cache key combining endpoint and parameters (e.g., "movie_details_123", "search_movies_avengers_page1")';
COMMENT ON COLUMN public.tmdb_cache.expires_at IS 
'When this cache entry expires. Movie details: 24 hours, search results: 1 hour.';
COMMENT ON FUNCTION cleanup_expired_tmdb_cache() IS 
'Removes expired cache entries. Can be called periodically via cron job.';

