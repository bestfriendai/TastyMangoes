--  019_add_get_stale_movies_function.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
--  Notes: Add helper function to efficiently get stale movies for refresh queue

-- Function to get stale movies (optimized for daily-refresh Edge Function)
CREATE OR REPLACE FUNCTION get_stale_movies(limit_count INT DEFAULT 100)
RETURNS TABLE (
    work_id BIGINT,
    tmdb_id TEXT,
    title TEXT,
    last_refreshed_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.work_id,
        w.tmdb_id,
        w.title,
        w.last_refreshed_at
    FROM works w
    WHERE w.tmdb_id IS NOT NULL
      AND is_stale(w.work_id) = true
    ORDER BY w.last_refreshed_at ASC NULLS FIRST
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_stale_movies(INT) IS 
'Returns stale movies that need refreshing, ordered by last_refreshed_at (oldest first). Used by daily-refresh Edge Function.';

