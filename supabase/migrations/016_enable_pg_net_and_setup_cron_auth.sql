--  016_enable_pg_net_and_setup_cron_auth.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
--  Notes: Enable pg_net extension and set up secure authentication for cron jobs

-- Enable pg_net extension for async HTTP calls from pg_cron
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================================
-- TABLE: cron_settings
-- Secure storage for cron job configuration (URLs, keys, etc.)
-- Only service_role can read/write, users can't access
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cron_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.cron_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Only service_role can manage cron_settings
CREATE POLICY "Service role can manage cron_settings"
    ON public.cron_settings
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: No one else can access (not even authenticated users)
-- This ensures secrets stay secure

-- Add comments
COMMENT ON TABLE public.cron_settings IS 
'Secure storage for cron job configuration. Only service_role can access. Set values via Supabase Dashboard SQL Editor or Edge Functions.';
COMMENT ON COLUMN public.cron_settings.setting_key IS 
'Setting key (e.g., ''supabase_url'', ''service_role_key'')';
COMMENT ON COLUMN public.cron_settings.setting_value IS 
'Setting value (URLs, keys, etc.)';

-- Create a secure function to get settings (only service_role can execute)
CREATE OR REPLACE FUNCTION get_cron_setting(setting_key_param TEXT)
RETURNS TEXT AS $$
DECLARE
  setting_value TEXT;
BEGIN
  -- Only service_role can execute this function
  IF current_setting('request.jwt.role', true) != 'service_role' THEN
    RAISE EXCEPTION 'Permission denied: Only service_role can access cron settings';
  END IF;
  
  SELECT setting_value INTO setting_value
  FROM public.cron_settings
  WHERE setting_key = setting_key_param;
  
  IF setting_value IS NULL THEN
    RAISE EXCEPTION 'Setting not found: %. Set it via: INSERT INTO cron_settings (setting_key, setting_value) VALUES (''%'', ''your-value'');', 
      setting_key_param, setting_key_param;
  END IF;
  
  RETURN setting_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_cron_setting(TEXT) IS 
'Returns a cron setting value. Only service_role can execute. Settings are stored in cron_settings table.';
