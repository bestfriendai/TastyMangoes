--  020_create_refresh_cron_jobs.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
--  Notes: Create pg_cron jobs for daily refresh enqueue and refresh worker

-- Function to call daily-refresh Edge Function via pg_net
CREATE OR REPLACE FUNCTION call_daily_refresh()
RETURNS void AS $$
DECLARE
  supabase_url TEXT;
  service_key TEXT;
  edge_function_url TEXT;
  request_id BIGINT;
BEGIN
  -- Get configuration from cron_settings table
  BEGIN
    supabase_url := get_supabase_url();
    service_key := get_service_role_key();
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Missing configuration: Set cron_settings via SQL: INSERT INTO cron_settings (setting_key, setting_value) VALUES (''supabase_url'', ''your-url''), (''service_role_key'', ''your-key'');';
  END;
  
  -- Construct Edge Function URL
  edge_function_url := supabase_url || '/functions/v1/daily-refresh';
  
  -- Make async HTTP POST request via pg_net
  SELECT net.http_post(
    url := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := '{}'::jsonb
  ) INTO request_id;
  
  RAISE NOTICE 'Daily refresh enqueue triggered: request_id=%', request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION call_daily_refresh() IS 
'Calls the daily-refresh Edge Function via pg_net. Used by pg_cron job daily_refresh_enqueue.';

-- Function to call refresh-worker Edge Function via pg_net
CREATE OR REPLACE FUNCTION call_refresh_worker()
RETURNS void AS $$
DECLARE
  supabase_url TEXT;
  service_key TEXT;
  edge_function_url TEXT;
  request_id BIGINT;
BEGIN
  -- Get configuration from cron_settings table
  BEGIN
    supabase_url := get_supabase_url();
    service_key := get_service_role_key();
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Missing configuration: Set cron_settings via SQL: INSERT INTO cron_settings (setting_key, setting_value) VALUES (''supabase_url'', ''your-url''), (''service_role_key'', ''your-key'');';
  END;
  
  -- Construct Edge Function URL
  edge_function_url := supabase_url || '/functions/v1/refresh-worker';
  
  -- Make async HTTP POST request via pg_net
  SELECT net.http_post(
    url := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := '{}'::jsonb
  ) INTO request_id;
  
  RAISE NOTICE 'Refresh worker triggered: request_id=%', request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION call_refresh_worker() IS 
'Calls the refresh-worker Edge Function via pg_net. Used by pg_cron job refresh_worker.';

-- Schedule refresh jobs ONLY if pg_cron is installed
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN

    -- Daily refresh enqueue (03:30 America/Los_Angeles ≈ 11:30 UTC)
    PERFORM cron.schedule(
      'daily_refresh_enqueue',
      '30 11 * * *',
      $cron$
SELECT call_daily_refresh();
$cron$
    );

    -- Refresh worker every 10 minutes
    PERFORM cron.schedule(
      'refresh_worker',
      '*/10 * * * *',
      $cron$
SELECT call_refresh_worker();
$cron$
    );

  END IF;
END;
$$;

