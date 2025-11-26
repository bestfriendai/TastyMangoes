-- 002_add_ingestion_status.sql
-- Created automatically by Cursor Assistant
-- Created on: 2025-01-15 at 22:00 (America/Los_Angeles - Pacific Time)
-- Notes: Add ingestion_status column to works table and similar_movie_ids to works_meta

-- Add ingestion_status column to works table
ALTER TABLE works 
ADD COLUMN IF NOT EXISTS ingestion_status TEXT DEFAULT 'pending' 
CHECK (ingestion_status IN ('pending', 'ingesting', 'complete', 'failed'));

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_works_ingestion_status ON works(ingestion_status);

-- Add similar_movie_ids column to works_meta (array of TMDB IDs as integers)
ALTER TABLE works_meta 
ADD COLUMN IF NOT EXISTS similar_movie_ids INTEGER[];

-- Add index for similar movies lookups
CREATE INDEX IF NOT EXISTS idx_works_meta_similar_movie_ids ON works_meta USING GIN(similar_movie_ids);

-- Update existing works to have 'complete' status if they have metadata
UPDATE works 
SET ingestion_status = 'complete' 
WHERE work_id IN (SELECT work_id FROM works_meta);

-- Set 'pending' for works without metadata
UPDATE works 
SET ingestion_status = 'pending' 
WHERE ingestion_status IS NULL;

