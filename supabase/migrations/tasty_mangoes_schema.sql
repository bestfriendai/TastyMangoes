-- ============================================================================
-- TASTY MANGOES DATABASE SCHEMA
-- Version: 1.0.0
-- Date: 2025-11-25
-- 
-- This migration creates the core tables for the TastyMangoes movie platform.
-- Run this in your Supabase SQL Editor.
-- ============================================================================

-- ============================================================================
-- PART 1: CORE MOVIE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLE: works
-- The master index of all movies. One row per movie, minimal fields.
-- This is the canonical source of truth for movie identity.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS works (
    work_id             BIGSERIAL PRIMARY KEY,
    tmdb_id             TEXT UNIQUE NOT NULL,
    imdb_id             TEXT UNIQUE,
    title               TEXT NOT NULL,
    original_title      TEXT,
    year                INT,
    release_date        DATE,
    
    -- Staleness tracking
    last_refreshed_at   TIMESTAMPTZ DEFAULT now(),
    request_count       INT DEFAULT 0,
    
    -- Metadata
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common lookups
CREATE INDEX IF NOT EXISTS idx_works_tmdb_id ON works(tmdb_id);
CREATE INDEX IF NOT EXISTS idx_works_imdb_id ON works(imdb_id);
CREATE INDEX IF NOT EXISTS idx_works_title ON works(title);
CREATE INDEX IF NOT EXISTS idx_works_year ON works(year);
CREATE INDEX IF NOT EXISTS idx_works_release_date ON works(release_date);
CREATE INDEX IF NOT EXISTS idx_works_last_refreshed ON works(last_refreshed_at);

-- ----------------------------------------------------------------------------
-- TABLE: works_meta
-- Rich metadata, cast, crew, and assets for each movie.
-- One-to-one relationship with works table.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS works_meta (
    work_id             BIGINT PRIMARY KEY REFERENCES works(work_id) ON DELETE CASCADE,
    
    -- Runtime & Format
    runtime_minutes     INT,
    runtime_display     TEXT,                       -- Pre-formatted "2h 12m"
    
    -- Text Content
    tagline             TEXT,
    overview            TEXT,
    overview_short      TEXT,                       -- 1-2 sentence version
    keywords            TEXT[],
    
    -- Classification
    genres              TEXT[],                     -- ['Drama', 'Thriller']
    subgenres           TEXT[],                     -- ['Dark Comedy', 'Social Thriller']
    moods               TEXT[],                     -- ['Tense', 'Suspenseful']
    themes              TEXT[],                     -- ['Class Divide', 'Family']
    
    -- Ratings & Certification
    certification       TEXT,                       -- 'R', 'PG-13', etc.
    certification_reason TEXT,
    content_warnings    TEXT[],
    
    -- Visual Assets (paths to our storage bucket)
    poster_url_small    TEXT,                       -- ~154px
    poster_url_medium   TEXT,                       -- ~342px
    poster_url_large    TEXT,                       -- ~500px
    poster_url_original TEXT,
    backdrop_url        TEXT,
    backdrop_url_mobile TEXT,
    logo_url            TEXT,
    still_images        JSONB,                      -- [{url, caption}, ...]
    
    -- Cast & Crew (JSONB arrays)
    -- Cast: [{person_id, name, character, order, photo_url_small, photo_url_medium, photo_url_large, gender, known_for}, ...]
    cast_members        JSONB,
    -- Crew: [{person_id, name, job, department, photo_url_small, photo_url_medium, known_for}, ...]
    crew_members        JSONB,
    
    -- Trailer & Media
    trailer_youtube_id  TEXT,
    trailer_thumbnail   TEXT,
    trailer_duration    INT,                        -- seconds
    trailers            JSONB,                      -- Array of all trailers
    
    -- Technical Specs
    aspect_ratio        TEXT,                       -- '2.35:1'
    color               TEXT,                       -- 'Color' or 'Black and White'
    sound_mix           TEXT[],                     -- ['Dolby Digital', 'Dolby Atmos']
    imax_available      BOOLEAN DEFAULT false,
    dolby_cinema        BOOLEAN DEFAULT false,
    dolby_atmos         BOOLEAN DEFAULT false,
    dolby_vision        BOOLEAN DEFAULT false,
    filming_locations   TEXT[],
    
    -- Production Info
    production_companies JSONB,                     -- [{name, logo_url}, ...]
    production_countries TEXT[],
    spoken_languages    TEXT[],
    original_language   TEXT,
    
    -- Box Office (optional)
    budget              BIGINT,
    budget_display      TEXT,
    revenue_worldwide   BIGINT,
    revenue_display     TEXT,
    opening_weekend_us  BIGINT,
    
    -- Awards (optional)
    awards              JSONB,                      -- [{event, year, category, result, recipient}, ...]
    
    -- Streaming Availability
    streaming           JSONB,                      -- {US: {subscription: [...], rent: [...], buy: [...]}}
    
    -- Connections
    collection          JSONB,                      -- {collection_id, name, poster_url, movies: [...]}
    similar_movies      JSONB,                      -- [work_id, work_id, ...]
    
    -- Data freshness
    fetched_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- TABLE: rating_sources
-- Individual rating inputs from various sources (license-safe only).
-- One row per movie per source.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rating_sources (
    rating_id           BIGSERIAL PRIMARY KEY,
    work_id             BIGINT REFERENCES works(work_id) ON DELETE CASCADE,
    source_name         TEXT NOT NULL,              -- 'TMDB', 'MetacriticCritic', 'MetacriticUser', 'Letterboxd'
    scale_type          TEXT NOT NULL,              -- '0_100', '0_10', '0_5'
    value_raw           REAL NOT NULL,              -- As reported by source
    value_0_100         REAL NOT NULL,              -- Normalized to 0-100
    votes_count         INT,
    last_seen_at        TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE (work_id, source_name)
);

CREATE INDEX IF NOT EXISTS idx_rating_sources_work ON rating_sources(work_id);
CREATE INDEX IF NOT EXISTS idx_rating_sources_source ON rating_sources(source_name);

-- ----------------------------------------------------------------------------
-- TABLE: aggregates
-- The computed AI Score combining all rating inputs.
-- Supports versioned algorithms for A/B testing.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aggregates (
    work_id             BIGINT REFERENCES works(work_id) ON DELETE CASCADE,
    method_version      TEXT NOT NULL,              -- 'v1_2025_11'
    
    -- Source counts
    n_critics           INT DEFAULT 0,
    n_audience          INT DEFAULT 0,
    n_excerpts          INT DEFAULT 0,
    n_buzz_sources      INT DEFAULT 0,
    
    -- Component scores (0-100)
    critics_score       REAL,
    audience_score      REAL,
    sentiment_score     REAL,
    buzz_score          REAL,
    
    -- Final AI Score
    ai_score            REAL,                       -- The number we show users
    ai_score_low        REAL,                       -- Confidence range low
    ai_score_high       REAL,                       -- Confidence range high
    
    -- Breakdown for display
    source_scores       JSONB,                      -- {tmdb: {score, votes}, metacritic_critic: {...}, ...}
    
    -- Computation metadata
    inputs_fingerprint  TEXT,                       -- Hash to detect changes
    computed_at         TIMESTAMPTZ DEFAULT now(),
    
    PRIMARY KEY (work_id, method_version)
);

CREATE INDEX IF NOT EXISTS idx_aggregates_work ON aggregates(work_id);
CREATE INDEX IF NOT EXISTS idx_aggregates_ai_score ON aggregates(ai_score);

-- ----------------------------------------------------------------------------
-- TABLE: work_cards_cache
-- Pre-built JSON payloads ready to serve to the app.
-- Avoids expensive joins on every request.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS work_cards_cache (
    work_id             BIGINT PRIMARY KEY REFERENCES works(work_id) ON DELETE CASCADE,
    payload             JSONB NOT NULL,             -- Complete movie card
    payload_short       JSONB,                      -- Abbreviated version for lists
    etag                TEXT,                       -- Hash for HTTP caching
    computed_at         TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- PART 2: STUBBED TABLES (For Future AI/Sentiment Features)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLE: review_excerpts (STUBBED)
-- Short text excerpts from reviews for sentiment analysis.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_excerpts (
    excerpt_id          BIGSERIAL PRIMARY KEY,
    work_id             BIGINT REFERENCES works(work_id) ON DELETE CASCADE,
    source_name         TEXT,                       -- 'Wikipedia', 'NYTimes', etc.
    url                 TEXT,
    excerpt_text        TEXT NOT NULL,
    language            TEXT DEFAULT 'en',
    created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_review_excerpts_work ON review_excerpts(work_id);

-- ----------------------------------------------------------------------------
-- TABLE: review_sentiment (STUBBED)
-- AI-generated sentiment analysis of review excerpts.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_sentiment (
    excerpt_id          BIGINT PRIMARY KEY REFERENCES review_excerpts(excerpt_id) ON DELETE CASCADE,
    sentiment_0_100     REAL NOT NULL,
    strength_0_1        REAL,
    aspects             JSONB,                      -- {acting: 90, pacing: 70, ...}
    model_version       TEXT NOT NULL,
    inferred_at         TIMESTAMPTZ DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- TABLE: buzz_signals (STUBBED)
-- Social media and YouTube buzz metrics.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS buzz_signals (
    buzz_id             BIGSERIAL PRIMARY KEY,
    work_id             BIGINT REFERENCES works(work_id) ON DELETE CASCADE,
    source_name         TEXT NOT NULL,              -- 'YouTubeTrailer', 'Reddit', 'Twitter'
    metric_name         TEXT NOT NULL,              -- 'like_ratio', 'comment_sentiment'
    value_0_100         REAL NOT NULL,
    sample_size         INT,
    collected_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_buzz_signals_work ON buzz_signals(work_id);

-- ============================================================================
-- PART 3: USER CAPTURE & IMPORT TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLE: user_captures
-- Quick voice/text captures like "Hey Siri, Olga said Parasite is good"
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_captures (
    capture_id          BIGSERIAL PRIMARY KEY,
    user_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    raw_input           TEXT NOT NULL,              -- Original voice/text input
    source              TEXT,                       -- 'siri', 'manual', 'share_sheet'
    recommender_name    TEXT,                       -- Extracted: "Olga"
    matched_work_id     BIGINT REFERENCES works(work_id) ON DELETE SET NULL,
    match_confidence    REAL,                       -- 0-1
    status              TEXT DEFAULT 'pending',    -- 'pending', 'matched', 'dismissed'
    created_at          TIMESTAMPTZ DEFAULT now(),
    resolved_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_user_captures_user ON user_captures(user_id);
CREATE INDEX IF NOT EXISTS idx_user_captures_status ON user_captures(status);

-- ----------------------------------------------------------------------------
-- TABLE: user_imports
-- Bulk imports from iPhone Notes or other text sources.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_imports (
    import_id           BIGSERIAL PRIMARY KEY,
    user_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    raw_text            TEXT NOT NULL,              -- The messy notes they shared
    source              TEXT,                       -- 'apple_notes', 'text_paste', 'share_sheet'
    
    -- Parsed results
    parsed_items        JSONB,                      -- [{line, matched, work_id, confidence, suggestions}, ...]
    matched_count       INT DEFAULT 0,
    unmatched_count     INT DEFAULT 0,
    
    -- For returning cleaned-up notes
    cleaned_text        TEXT,                       -- Bulleted, formatted version
    
    created_at          TIMESTAMPTZ DEFAULT now(),
    processed_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_user_imports_user ON user_imports(user_id);

-- ============================================================================
-- PART 4: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all new tables
ALTER TABLE works ENABLE ROW LEVEL SECURITY;
ALTER TABLE works_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE rating_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE aggregates ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_cards_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_excerpts ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_sentiment ENABLE ROW LEVEL SECURITY;
ALTER TABLE buzz_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_captures ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_imports ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- MOVIE DATA: Public read, server-only write
-- ----------------------------------------------------------------------------

-- Works: Everyone can read
CREATE POLICY "Works are viewable by everyone" ON works
    FOR SELECT USING (true);

-- Works: Only service role can insert/update/delete
CREATE POLICY "Works are managed by service role" ON works
    FOR ALL USING (auth.role() = 'service_role');

-- Works Meta: Everyone can read
CREATE POLICY "Works meta viewable by everyone" ON works_meta
    FOR SELECT USING (true);

CREATE POLICY "Works meta managed by service role" ON works_meta
    FOR ALL USING (auth.role() = 'service_role');

-- Rating Sources: Everyone can read
CREATE POLICY "Rating sources viewable by everyone" ON rating_sources
    FOR SELECT USING (true);

CREATE POLICY "Rating sources managed by service role" ON rating_sources
    FOR ALL USING (auth.role() = 'service_role');

-- Aggregates: Everyone can read
CREATE POLICY "Aggregates viewable by everyone" ON aggregates
    FOR SELECT USING (true);

CREATE POLICY "Aggregates managed by service role" ON aggregates
    FOR ALL USING (auth.role() = 'service_role');

-- Work Cards Cache: Everyone can read
CREATE POLICY "Work cards viewable by everyone" ON work_cards_cache
    FOR SELECT USING (true);

CREATE POLICY "Work cards managed by service role" ON work_cards_cache
    FOR ALL USING (auth.role() = 'service_role');

-- Stubbed tables: Same pattern
CREATE POLICY "Review excerpts viewable by everyone" ON review_excerpts
    FOR SELECT USING (true);

CREATE POLICY "Review excerpts managed by service role" ON review_excerpts
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Review sentiment viewable by everyone" ON review_sentiment
    FOR SELECT USING (true);

CREATE POLICY "Review sentiment managed by service role" ON review_sentiment
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Buzz signals viewable by everyone" ON buzz_signals
    FOR SELECT USING (true);

CREATE POLICY "Buzz signals managed by service role" ON buzz_signals
    FOR ALL USING (auth.role() = 'service_role');

-- ----------------------------------------------------------------------------
-- USER DATA: Users can only see/manage their own
-- ----------------------------------------------------------------------------

-- User Captures: Users see only their own
CREATE POLICY "Users can view own captures" ON user_captures
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own captures" ON user_captures
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own captures" ON user_captures
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own captures" ON user_captures
    FOR DELETE USING (auth.uid() = user_id);

-- User Imports: Users see only their own
CREATE POLICY "Users can view own imports" ON user_imports
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own imports" ON user_imports
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own imports" ON user_imports
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own imports" ON user_imports
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- PART 5: HELPER FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: normalize_rating
-- Converts ratings from various scales to 0-100.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION normalize_rating(value REAL, scale_type TEXT)
RETURNS REAL AS $$
BEGIN
    CASE scale_type
        WHEN '0_10' THEN RETURN value * 10;
        WHEN '0_5' THEN RETURN value * 20;
        WHEN '0_100' THEN RETURN value;
        WHEN '0_4' THEN RETURN value * 25;  -- Letterboxd uses 0-5 but often shown as stars
        ELSE RETURN value;  -- Assume already 0-100
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Function: calculate_staleness_days
-- Determines how many days before a movie should be refreshed.
-- Newer movies refresh more frequently.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_staleness_days(release_date DATE)
RETURNS INT AS $$
DECLARE
    days_since_release INT;
BEGIN
    days_since_release := CURRENT_DATE - release_date;
    
    -- Movies in theaters (last 30 days): refresh every 2 days
    IF days_since_release <= 30 THEN
        RETURN 2;
    -- Recent releases (1-6 months): refresh weekly
    ELSIF days_since_release <= 180 THEN
        RETURN 7;
    -- Older movies (6-12 months): refresh every 2 weeks
    ELSIF days_since_release <= 365 THEN
        RETURN 14;
    -- Catalog movies (1+ years): refresh monthly
    ELSE
        RETURN 30;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Function: is_stale
-- Checks if a movie needs refreshing based on its release date and last refresh.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_stale(work_id_input BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    work_record RECORD;
    staleness_days INT;
BEGIN
    SELECT release_date, last_refreshed_at INTO work_record
    FROM works WHERE work_id = work_id_input;
    
    IF work_record IS NULL THEN
        RETURN true;
    END IF;
    
    staleness_days := calculate_staleness_days(work_record.release_date);
    
    RETURN work_record.last_refreshed_at < (now() - (staleness_days || ' days')::INTERVAL);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 6: TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Trigger: Auto-update updated_at on works
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER works_updated_at
    BEFORE UPDATE ON works
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER works_meta_updated_at
    BEFORE UPDATE ON works_meta
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- PART 7: SEED DATA - 25 TEST MOVIES
-- Run this after the schema to have movies to test with.
-- The TMDB IDs are real; metadata will be fetched by the ingestion pipeline.
-- ============================================================================

-- We'll insert just the identity rows. The pipeline will fill in metadata.
INSERT INTO works (tmdb_id, title, year, release_date) VALUES
    ('496243', 'Parasite', 2019, '2019-05-30'),
    ('155', 'The Dark Knight', 2008, '2008-07-16'),
    ('680', 'Pulp Fiction', 1994, '1994-09-10'),
    ('238', 'The Godfather', 1972, '1972-03-14'),
    ('550', 'Fight Club', 1999, '1999-10-15'),
    ('13', 'Forrest Gump', 1994, '1994-06-23'),
    ('278', 'The Shawshank Redemption', 1994, '1994-09-23'),
    ('27205', 'Inception', 2010, '2010-07-15'),
    ('157336', 'Interstellar', 2014, '2014-11-05'),
    ('603', 'The Matrix', 1999, '1999-03-30'),
    ('244786', 'Whiplash', 2014, '2014-10-10'),
    ('120467', 'The Grand Budapest Hotel', 2014, '2014-02-26'),
    ('98', 'Gladiator', 2000, '2000-05-01'),
    ('769', 'GoodFellas', 1990, '1990-09-12'),
    ('389', 'Twelve Monkeys', 1995, '1995-12-29'),
    ('11', 'Star Wars', 1977, '1977-05-25'),
    ('1891', 'The Empire Strikes Back', 1980, '1980-05-17'),
    ('78', 'Blade Runner', 1982, '1982-06-25'),
    ('335984', 'Blade Runner 2049', 2017, '2017-10-04'),
    ('286217', 'The Martian', 2015, '2015-09-30'),
    ('862', 'Toy Story', 1995, '1995-10-30'),
    ('105', 'Back to the Future', 1985, '1985-07-03'),
    ('599', 'Titanic', 1997, '1997-11-18'),
    ('671', 'Harry Potter and the Philosopher''s Stone', 2001, '2001-11-16'),
    ('101', 'Leon: The Professional', 1994, '1994-09-14')
ON CONFLICT (tmdb_id) DO NOTHING;

-- ============================================================================
-- DONE!
-- 
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Use Cursor to build the ingestion pipeline (see CURSOR_INSTRUCTIONS.md)
-- 3. The pipeline will fetch metadata for the 25 seed movies
-- 4. Test the flow: request movie → ingest → compute AI Score → cache card
-- ============================================================================
