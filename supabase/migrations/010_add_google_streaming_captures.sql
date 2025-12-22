-- Migration: Add google_streaming_captures table
-- Created on: 2025-12-21 (America/Los_Angeles - Pacific Time)
-- Notes: Table to store streaming availability data captured from Google search results

CREATE TABLE IF NOT EXISTS google_streaming_captures (
  id BIGSERIAL PRIMARY KEY,
  work_id BIGINT REFERENCES works(work_id),
  tmdb_id INTEGER NOT NULL,
  movie_title TEXT NOT NULL,
  movie_year INTEGER,
  
  -- Provider info
  provider_name TEXT NOT NULL,  -- Google's name (e.g., "HBO MAX", "Netflix")
  provider_id INTEGER,  -- TMDB provider ID (matched later)
  provider_logo_url TEXT,  -- If we can extract it
  
  -- Availability type
  availability_type TEXT NOT NULL,  -- 'free', 'subscription', 'subscription_addon', 'primetime_subscription'
  availability_text TEXT,  -- Raw text from Google (e.g., "Subscription (Requires add-on)")
  
  -- Tracking
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  captured_by UUID REFERENCES auth.users(id),  -- User who triggered the capture
  source TEXT DEFAULT 'google',
  
  -- Staleness tracking
  last_verified_at TIMESTAMPTZ,  -- When we last confirmed this is still valid
  is_stale BOOLEAN DEFAULT FALSE,
  stale_since TIMESTAMPTZ,
  
  -- Metadata
  raw_data JSONB,  -- Store full Google entry for debugging
  
  -- Prevent exact duplicates within same capture session
  CONSTRAINT unique_capture UNIQUE(tmdb_id, provider_name, captured_at)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_google_streaming_tmdb ON google_streaming_captures(tmdb_id);
CREATE INDEX IF NOT EXISTS idx_google_streaming_stale ON google_streaming_captures(is_stale, last_verified_at);
CREATE INDEX IF NOT EXISTS idx_google_streaming_captured ON google_streaming_captures(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_google_streaming_provider ON google_streaming_captures(provider_name);
CREATE INDEX IF NOT EXISTS idx_google_streaming_work ON google_streaming_captures(work_id) WHERE work_id IS NOT NULL;

-- Comments for documentation
COMMENT ON TABLE google_streaming_captures IS 'Stores streaming availability data captured from Google search results for movies';
COMMENT ON COLUMN google_streaming_captures.availability_type IS 'Type of availability: free, subscription, subscription_addon, primetime_subscription';
COMMENT ON COLUMN google_streaming_captures.is_stale IS 'Flag indicating if this data is potentially outdated (based on last_verified_at)';
COMMENT ON COLUMN google_streaming_captures.raw_data IS 'Full JSON data from Google for debugging and future processing';

