--  014_add_pacific_time_to_scheduled_ingestion_log.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-23 at 19:45 (America/Los_Angeles - Pacific Time)
--  Notes: Add Pacific time display columns to scheduled_ingestion_log table using triggers

-- Add regular columns (will be populated by trigger)
ALTER TABLE public.scheduled_ingestion_log
ADD COLUMN IF NOT EXISTS created_at_pacific_formatted TEXT;

ALTER TABLE public.scheduled_ingestion_log
ADD COLUMN IF NOT EXISTS created_at_utc_formatted TEXT;

-- Create function to update formatted timestamps
CREATE OR REPLACE FUNCTION update_scheduled_ingestion_log_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  -- Update UTC formatted timestamp (24-hour format)
  NEW.created_at_utc_formatted := TO_CHAR(NEW.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS');
  
  -- Update Pacific formatted timestamp (24-hour format)
  NEW.created_at_pacific_formatted := TO_CHAR(
    (NEW.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Los_Angeles',
    'YYYY-MM-DD HH24:MI:SS'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to populate formatted timestamps on insert/update
DROP TRIGGER IF EXISTS trigger_update_scheduled_ingestion_log_timestamps ON public.scheduled_ingestion_log;
CREATE TRIGGER trigger_update_scheduled_ingestion_log_timestamps
  BEFORE INSERT OR UPDATE ON public.scheduled_ingestion_log
  FOR EACH ROW
  EXECUTE FUNCTION update_scheduled_ingestion_log_timestamps();

-- Backfill existing rows
UPDATE public.scheduled_ingestion_log
SET 
  created_at_utc_formatted = TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS'),
  created_at_pacific_formatted = TO_CHAR(
    (created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Los_Angeles',
    'YYYY-MM-DD HH24:MI:SS'
  );

-- Add comments
COMMENT ON COLUMN public.scheduled_ingestion_log.created_at_pacific_formatted IS 'Pacific Time formatted as YYYY-MM-DD HH24:MI:SS (24-hour format)';
COMMENT ON COLUMN public.scheduled_ingestion_log.created_at_utc_formatted IS 'UTC time formatted as YYYY-MM-DD HH24:MI:SS (24-hour format)';
COMMENT ON COLUMN public.scheduled_ingestion_log.created_at IS 'UTC timestamp (stored as TIMESTAMPTZ)';

