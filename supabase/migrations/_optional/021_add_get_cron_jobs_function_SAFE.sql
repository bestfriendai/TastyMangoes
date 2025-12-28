--  021_add_get_cron_jobs_function_SAFE.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-24 at 00:00 (America/Los_Angeles - Pacific Time)
--  Notes: SAFE VERSION - Only use if Edge Function approach doesn't work
--  This migration is OPTIONAL and should only be applied if get-cron-jobs Edge Function fails

-- Function to get cron jobs (for dashboard)
-- This is a FALLBACK - Edge Function should be tried first
CREATE OR REPLACE FUNCTION get_cron_jobs()
RETURNS TABLE (
    jobid BIGINT,
    schedule TEXT,
    command TEXT,
    nodename TEXT,
    nodeport INTEGER,
    database TEXT,
    username TEXT,
    active BOOLEAN,
    jobname TEXT
) AS $$
BEGIN
    -- Safety check: Ensure cron schema exists
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
        RAISE NOTICE 'Cron schema does not exist';
        RETURN; -- Return empty result set
    END IF;
    
    -- Safety check: Ensure cron.job table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'cron' AND table_name = 'job'
    ) THEN
        RAISE NOTICE 'Cron.job table does not exist';
        RETURN; -- Return empty result set
    END IF;
    
    -- Query cron.job table
    RETURN QUERY
    SELECT 
        j.jobid,
        j.schedule::TEXT,
        j.command::TEXT,
        j.nodename,
        j.nodeport,
        j.database,
        j.username,
        j.active,
        j.jobname
    FROM cron.job j
    ORDER BY j.jobname ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_cron_jobs() IS 
'OPTIONAL FALLBACK: Returns all cron jobs for dashboard visibility. Only use if Edge Function get-cron-jobs fails. Edge Function approach is preferred to avoid migration drift.';

-- Grant execute to authenticated users (for dashboard)
GRANT EXECUTE ON FUNCTION get_cron_jobs() TO authenticated, anon;

