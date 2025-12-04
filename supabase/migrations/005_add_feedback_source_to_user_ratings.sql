--  005_add_feedback_source_to_user_ratings.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-03 at 16:57 (America/Los_Angeles - Pacific Time)
--  Notes: Add feedback_source column to user_ratings table to track the source of each rating (quick_star, talk_to_mango, imported, other)

-- Add feedback_source column to user_ratings table
ALTER TABLE public.user_ratings
ADD COLUMN IF NOT EXISTS feedback_source TEXT
  CHECK (feedback_source IN ('quick_star', 'talk_to_mango', 'imported', 'other'))
  DEFAULT 'quick_star';

-- Add comment to document the column
COMMENT ON COLUMN public.user_ratings.feedback_source IS 'Source of the rating: quick_star (from RateBottomSheet), talk_to_mango (from voice interaction), imported (from bulk import), or other';

-- Create index for filtering by feedback source (useful for analytics)
CREATE INDEX IF NOT EXISTS idx_user_ratings_feedback_source ON public.user_ratings(feedback_source);

