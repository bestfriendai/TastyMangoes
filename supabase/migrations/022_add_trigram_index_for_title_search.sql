--  022_add_trigram_index_for_title_search.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-24 at 00:00 (America/Los_Angeles - Pacific Time)
--  Notes: Add trigram index for efficient ILIKE title searches (performance improvement)

-- Enable pg_trgm extension for trigram indexing
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add trigram index on works.title for fast ILIKE queries
-- This makes queries like "WHERE title ILIKE '%query%'" use index instead of sequential scan
CREATE INDEX IF NOT EXISTS idx_works_title_trgm 
  ON public.works USING gin(title gin_trgm_ops);

COMMENT ON INDEX idx_works_title_trgm IS 
'Trigram index for efficient ILIKE title searches. Enables fast partial text matching for movie search.';

-- Verify index was created
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_works_title_trgm'
  ) THEN
    RAISE NOTICE 'Trigram index created successfully';
  ELSE
    RAISE WARNING 'Trigram index creation may have failed';
  END IF;
END $$;

