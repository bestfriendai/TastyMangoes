-- 001_initial_schema.sql
-- Created automatically by Cursor Assistant
-- Created on: 2025-01-15 at 15:45 (America/Los_Angeles - Pacific Time)
-- Updated on: 2025-01-15 at 16:15 (America/Los_Angeles - Pacific Time)
-- Notes: Initial database schema for TastyMangoes app - users, profiles, watchlists, watch history, ratings, movies, subscriptions

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES TABLE (extends Supabase auth.users)
-- ============================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all profiles
CREATE POLICY "Public profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Policy: Users can insert their own profile
CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- ============================================
-- USER SUBSCRIPTIONS TABLE
-- ============================================
CREATE TABLE public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN (
        'Netflix', 'Prime Video', 'Disney+', 'Max', 'Hulu', 
        'Criterion', 'Paramount+', 'Apple TV+', 'Peacock', 'Tubi'
    )),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform)
);

-- Enable Row Level Security
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all subscriptions (for search filtering)
CREATE POLICY "Subscriptions are viewable by everyone"
    ON public.user_subscriptions FOR SELECT
    USING (true);

-- Policy: Users can manage their own subscriptions
CREATE POLICY "Users can manage own subscriptions"
    ON public.user_subscriptions FOR ALL
    USING (auth.uid() = user_id);

-- ============================================
-- WATCHLISTS TABLE
-- ============================================
CREATE TABLE public.watchlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    sort_order INTEGER DEFAULT 0
);

-- Enable Row Level Security
ALTER TABLE public.watchlists ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own watchlists
CREATE POLICY "Users can view own watchlists"
    ON public.watchlists FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can create their own watchlists
CREATE POLICY "Users can create own watchlists"
    ON public.watchlists FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own watchlists
CREATE POLICY "Users can update own watchlists"
    ON public.watchlists FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can delete their own watchlists
CREATE POLICY "Users can delete own watchlists"
    ON public.watchlists FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- WATCHLIST MOVIES TABLE (simplified - just "want to watch")
-- ============================================
CREATE TABLE public.watchlist_movies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    watchlist_id UUID NOT NULL REFERENCES public.watchlists(id) ON DELETE CASCADE,
    movie_id TEXT NOT NULL, -- TMDB movie ID or custom ID
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(watchlist_id, movie_id)
);

-- Enable Row Level Security
ALTER TABLE public.watchlist_movies ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view movies in their own watchlists
CREATE POLICY "Users can view own watchlist movies"
    ON public.watchlist_movies FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.watchlists
            WHERE watchlists.id = watchlist_movies.watchlist_id
            AND watchlists.user_id = auth.uid()
        )
    );

-- Policy: Users can manage movies in their own watchlists
CREATE POLICY "Users can manage own watchlist movies"
    ON public.watchlist_movies FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.watchlists
            WHERE watchlists.id = watchlist_movies.watchlist_id
            AND watchlists.user_id = auth.uid()
        )
    );

-- ============================================
-- WATCH HISTORY TABLE (movies user has watched)
-- ============================================
CREATE TABLE public.watch_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    movie_id TEXT NOT NULL, -- TMDB movie ID or custom ID
    watched_at TIMESTAMPTZ DEFAULT NOW(),
    platform TEXT, -- Which streaming service they watched it on (nullable)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, movie_id) -- One entry per movie per user
);

-- Enable Row Level Security
ALTER TABLE public.watch_history ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own watch history
CREATE POLICY "Users can view own watch history"
    ON public.watch_history FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can manage their own watch history
CREATE POLICY "Users can manage own watch history"
    ON public.watch_history FOR ALL
    USING (auth.uid() = user_id);

-- ============================================
-- USER RATINGS TABLE (ratings for any movie)
-- ============================================
CREATE TABLE public.user_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    movie_id TEXT NOT NULL, -- TMDB movie ID or custom ID
    rating INTEGER NOT NULL CHECK (rating >= 0 AND rating <= 5), -- 0-5 stars
    review_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, movie_id) -- One rating per movie per user
);

-- Enable Row Level Security
ALTER TABLE public.user_ratings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all ratings (for displaying on movie pages)
CREATE POLICY "Ratings are viewable by everyone"
    ON public.user_ratings FOR SELECT
    USING (true);

-- Policy: Users can manage their own ratings
CREATE POLICY "Users can manage own ratings"
    ON public.user_ratings FOR ALL
    USING (auth.uid() = user_id);

-- ============================================
-- MOVIES TABLE (cache of movie data)
-- ============================================
CREATE TABLE public.movies (
    id TEXT PRIMARY KEY, -- TMDB ID or custom ID
    tmdb_id INTEGER, -- Original TMDB ID if available
    title TEXT NOT NULL,
    year INTEGER,
    poster_url TEXT,
    backdrop_url TEXT,
    overview TEXT,
    runtime INTEGER, -- in minutes
    release_date DATE,
    genres TEXT[], -- Array of genre names
    rating TEXT, -- MPAA rating (PG-13, R, etc.)
    director TEXT,
    language TEXT,
    tasty_score DOUBLE PRECISION, -- Keep as-is, will be 0 or NULL for now
    ai_score DOUBLE PRECISION, -- Keep as-is, shows TMDB rating as placeholder
    trailer_url TEXT,
    trailer_duration INTEGER, -- in seconds
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.movies ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read movies
CREATE POLICY "Movies are viewable by everyone"
    ON public.movies FOR SELECT
    USING (true);

-- Policy: Authenticated users can insert/update movies
CREATE POLICY "Authenticated users can manage movies"
    ON public.movies FOR ALL
    USING (auth.role() = 'authenticated');

-- ============================================
-- INDEXES for performance
-- ============================================
CREATE INDEX idx_watchlists_user_id ON public.watchlists(user_id);
CREATE INDEX idx_watchlist_movies_watchlist_id ON public.watchlist_movies(watchlist_id);
CREATE INDEX idx_watchlist_movies_movie_id ON public.watchlist_movies(movie_id);
CREATE INDEX idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX idx_movies_tmdb_id ON public.movies(tmdb_id);
CREATE INDEX idx_profiles_username ON public.profiles(username);
CREATE INDEX idx_watch_history_user_id ON public.watch_history(user_id);
CREATE INDEX idx_watch_history_movie_id ON public.watch_history(movie_id);
CREATE INDEX idx_user_ratings_user_id ON public.user_ratings(user_id);
CREATE INDEX idx_user_ratings_movie_id ON public.user_ratings(movie_id);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username)
    VALUES (
        NEW.id,
        'user_' || substr(NEW.id::text, 1, 8) -- Default username
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile when user signs up
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_watchlists_updated_at
    BEFORE UPDATE ON public.watchlists
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_movies_updated_at
    BEFORE UPDATE ON public.movies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_ratings_updated_at
    BEFORE UPDATE ON public.user_ratings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

