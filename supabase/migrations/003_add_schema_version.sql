--  003_add_schema_version.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
--  Notes: Add schema_version column to works_meta for lazy re-ingestion

-- Add schema_version column to works_meta table
ALTER TABLE works_meta 
ADD COLUMN IF NOT EXISTS schema_version INTEGER DEFAULT 1;

-- Add trailers JSONB column to store video clips array
ALTER TABLE works_meta
ADD COLUMN IF NOT EXISTS trailers JSONB;

-- Set existing records to version 1
UPDATE works_meta SET schema_version = 1 WHERE schema_version IS NULL;

-- Add index on schema_version for efficient querying
CREATE INDEX IF NOT EXISTS idx_works_meta_schema_version ON works_meta(schema_version);

