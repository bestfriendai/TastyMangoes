--  008_add_handler_result_fields.sql
--  Created automatically by Cursor Assistant
--  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
--  Notes: Add handler_result, result_count, and error_message fields to voice_utterance_events table

-- ============================================
-- ADD HANDLER RESULT FIELDS TO VOICE UTTERANCE EVENTS
-- ============================================
ALTER TABLE public.voice_utterance_events
ADD COLUMN IF NOT EXISTS handler_result TEXT,
ADD COLUMN IF NOT EXISTS result_count INTEGER,
ADD COLUMN IF NOT EXISTS error_message TEXT;

-- Add index for handler_result for analytics queries
CREATE INDEX IF NOT EXISTS idx_voice_utterance_events_handler_result 
ON public.voice_utterance_events(handler_result);

-- Add policy for UPDATE operations (users can update their own voice events)
CREATE POLICY "Users can update own voice events"
    ON public.voice_utterance_events FOR UPDATE
    USING (auth.uid() = user_id OR user_id IS NULL)
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
