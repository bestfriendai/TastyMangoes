--  015_fix_scheduled_ingestion_log_rls.sql
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-23 at 20:00 (America/Los_Angeles - Pacific Time)
//  Notes: Fix RLS policy to allow anon users (dashboard uses anon key)

-- Drop existing policy
DROP POLICY IF EXISTS "Authenticated users can read scheduled_ingestion_log" ON public.scheduled_ingestion_log;

-- Allow both authenticated and anon users to read (dashboard uses anon key)
CREATE POLICY "Users can read scheduled_ingestion_log"
    ON public.scheduled_ingestion_log
    FOR SELECT
    TO authenticated, anon
    USING (true);

