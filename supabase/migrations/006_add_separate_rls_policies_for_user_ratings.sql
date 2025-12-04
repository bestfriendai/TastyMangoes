--  006_add_separate_rls_policies_for_user_ratings.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-12-03 at 17:08 (America/Los_Angeles - Pacific Time)
--  Notes: Add separate INSERT and UPDATE policies for user_ratings table for better security and clarity. The existing "Users can manage own ratings" policy uses FOR ALL, but separate policies are more explicit and easier to audit.

-- Drop the existing "FOR ALL" policy if it exists (we'll replace it with separate INSERT and UPDATE policies)
DROP POLICY IF EXISTS "Users can manage own ratings" ON public.user_ratings;

-- Ensure RLS is enabled (should already be enabled, but being explicit)
ALTER TABLE public.user_ratings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own ratings
CREATE POLICY "Users can insert their own ratings"
    ON public.user_ratings
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own ratings
CREATE POLICY "Users can update their own ratings"
    ON public.user_ratings
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own ratings (if not already covered)
CREATE POLICY "Users can delete their own ratings"
    ON public.user_ratings
    FOR DELETE
    USING (auth.uid() = user_id);

-- Note: The SELECT policy "Ratings are viewable by everyone" remains unchanged
-- as it allows all users to view ratings for displaying on movie pages

