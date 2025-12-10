--  009_add_voice_events_column_comments.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-01-15 at 16:30 (America/Los_Angeles - Pacific Time)
--  Updated on: 2025-01-15 at 16:45 (America/Los_Angeles - Pacific Time)
--  Notes: Add human-friendly column headers for voice_utterance_events table display. Includes "Who" column from profiles and formatted timestamp in Pacific time.

-- ============================================
-- CREATE VIEW WITH HUMAN-FRIENDLY COLUMN HEADERS
-- ============================================
-- This view provides human-friendly column names for display purposes
-- The underlying table structure remains unchanged
CREATE OR REPLACE VIEW public.voice_events_view AS
SELECT 
    vee.id,
    vee.user_id,
    -- Format timestamp in Pacific timezone
    to_char(vee.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Los_Angeles', 'YYYY-MM-DD HH24:MI:SS TZ') AS "When",
    -- Get username from profiles table
    COALESCE(p.username, 'Unknown') AS "Who",
    vee.utterance AS "Said",
    vee.mango_command_type AS "Type",
    vee.handler_result AS "Result",
    vee.llm_used AS "AI?",
    -- Keep all other columns with original names for detail panel
    vee.created_at,
    vee.mango_command_raw,
    vee.mango_command_movie_title,
    vee.mango_command_recommender,
    vee.final_command_type,
    vee.final_command_raw,
    vee.final_command_movie_title,
    vee.final_command_recommender,
    vee.llm_intent,
    vee.llm_movie_title,
    vee.llm_recommender,
    vee.llm_error,
    vee.result_count,
    vee.error_message
FROM public.voice_utterance_events vee
LEFT JOIN public.profiles p ON vee.user_id = p.id;

-- Grant access to authenticated users
GRANT SELECT ON public.voice_events_view TO authenticated;
GRANT SELECT ON public.voice_events_view TO anon;

-- Add column comments for database tools that support them
COMMENT ON COLUMN public.voice_utterance_events.created_at IS 'When';
COMMENT ON COLUMN public.voice_utterance_events.utterance IS 'Said';
COMMENT ON COLUMN public.voice_utterance_events.mango_command_type IS 'Type';
COMMENT ON COLUMN public.voice_utterance_events.handler_result IS 'Result';
COMMENT ON COLUMN public.voice_utterance_events.llm_used IS 'AI?';
