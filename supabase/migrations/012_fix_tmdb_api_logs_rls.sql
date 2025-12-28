--  012_fix_tmdb_api_logs_rls.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-22 at 19:40 (America/Los_Angeles - Pacific Time)
--  Notes: Fix RLS policy to allow anon users (dashboard) to read tmdb_api_logs

-- Drop existing policy if it exists (to avoid conflicts)
DROP POLICY IF EXISTS "Anon users can read tmdb_api_logs" ON public.tmdb_api_logs;

-- Add policy to allow anon users to read (for dashboard access)
-- This allows the dashboard to query logs without requiring authentication
CREATE POLICY "Anon users can read tmdb_api_logs"
    ON public.tmdb_api_logs
    FOR SELECT
    TO anon
    USING (true);

-- Note: If you want to restrict this later, you can drop this policy:
-- DROP POLICY IF EXISTS "Anon users can read tmdb_api_logs" ON public.tmdb_api_logs;
