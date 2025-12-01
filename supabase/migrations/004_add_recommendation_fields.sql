--  004_add_recommendation_fields.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-01-15 at 18:00 (America/Los_Angeles - Pacific Time)
--  Notes: Add recommendation fields to watchlist_movies table to support storing who recommended a movie and their notes

-- Add recommendation fields to watchlist_movies table
ALTER TABLE public.watchlist_movies
ADD COLUMN IF NOT EXISTS recommender_name TEXT,
ADD COLUMN IF NOT EXISTS recommended_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS recommender_notes TEXT;

-- Add comment for documentation
COMMENT ON COLUMN public.watchlist_movies.recommender_name IS 'Name of the person who recommended this movie (e.g., "Charlie", "Sarah")';
COMMENT ON COLUMN public.watchlist_movies.recommended_at IS 'When the movie was recommended';
COMMENT ON COLUMN public.watchlist_movies.recommender_notes IS 'Notes from the recommender about why they recommended this movie';

