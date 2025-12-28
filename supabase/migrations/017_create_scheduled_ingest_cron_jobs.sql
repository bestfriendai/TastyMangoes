--  017_create_scheduled_ingest_cron_jobs.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
--  Notes: Create pg_cron jobs for scheduled ingestion (daily and weekly)

-- Helper function to get Supabase project URL from cron_settings table
CREATE OR REPLACE FUNCTION get_supabase_url()
RETURNS TEXT AS $$
BEGIN
  RETURN get_cron_setting('supabase_url');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_supabase_url() IS 
'Returns the Supabase project URL from cron_settings table. Set via: INSERT INTO cron_settings (setting_key, setting_value) VALUES (''supabase_url'', ''https://your-project.supabase.co'');';

-- Function to call scheduled-ingest Edge Function via pg_net
CREATE OR REPLACE FUNCTION call_scheduled_ingest(
  source_param TEXT,
  max_movies_param INT,
  trigger_type_param TEXT DEFAULT 'scheduled'
)
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
    service_key := get_cron_setting('service_role_key');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Missing configuration: Set cron_settings via SQL: INSERT INTO cron_settings (setting_key, setting_value) VALUES (''supabase_url'', ''your-url''), (''service_role_key'', ''your-key'');';
  END;
  
  -- Construct Edge Function URL
  edge_function_url := supabase_url || '/functions/v1/scheduled-ingest';
  
  -- Make async HTTP POST request via pg_net
  SELECT net.http_post(
    url := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object(
      'source', source_param,
      'max_movies', max_movies_param,
      'trigger_type', trigger_type_param
    )
  ) INTO request_id;
  
  -- Log the request (optional, for debugging)
  RAISE NOTICE 'Scheduled ingest triggered: source=%, max_movies=%, request_id=%', 
    source_param, max_movies_param, request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION call_scheduled_ingest(TEXT, INT, TEXT) IS 
'Calls the scheduled-ingest Edge Function via pg_net. Used by pg_cron jobs.';

-- Schedule ingest jobs ONLY if pg_cron is installed
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN

    -- Schedule Daily Ingest Job
    PERFORM cron.schedule(
      'scheduled_ingest_daily',
      '0 11 * * *',
      $cron$SELECT call_scheduled_ingest('mixed_daily', 30, 'scheduled');$cron$
    );

    -- Schedule Weekly Ingest Job
    PERFORM cron.schedule(
      'scheduled_ingest_weekly',
      '0 10 * * 0',
      $cron$SELECT call_scheduled_ingest('mixed_weekly', 80, 'scheduled');$cron$
    );

  END IF;
END;
$$;

-- Add comments for documentation
COMMENT ON FUNCTION call_scheduled_ingest(TEXT, INT, TEXT) IS 
'Calls scheduled-ingest Edge Function. Used by cron jobs scheduled_ingest_daily and scheduled_ingest_weekly.';

