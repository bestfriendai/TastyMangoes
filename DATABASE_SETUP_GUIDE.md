# TastyMangoes Database & Ingestion Pipeline Setup Guide

## Overview

This guide walks you through setting up the complete database infrastructure and ingestion pipeline for TastyMangoes. The system fetches movie data from TMDB, computes AI scores, and pre-builds movie cards for fast app delivery.

## Prerequisites

- Supabase project created
- TMDB API key (get one at https://www.themoviedb.org/settings/api)
- Supabase CLI installed (optional, for local development)

## Step 1: Database Schema Setup

1. **Open Supabase Dashboard** → SQL Editor

2. **Run the migration file:**
   - Open `supabase/migrations/tasty_mangoes_schema.sql`
   - Copy the entire contents
   - Paste into Supabase SQL Editor
   - Click "Run"

3. **Verify tables were created:**
   - Go to Table Editor
   - You should see these tables:
     - `works` (25 seed movies should be inserted)
     - `works_meta`
     - `rating_sources`
     - `aggregates`
     - `work_cards_cache`
     - Plus stubbed tables for future features

## Step 2: Configure Environment Variables

1. **In Supabase Dashboard:**
   - Go to Project Settings → Edge Functions → Secrets
   - Add these secrets:
     ```
     TMDB_API_KEY=your_tmdb_api_key_here
     ```

2. **Verify existing environment variables:**
   - `SUPABASE_URL` (auto-set)
   - `SUPABASE_ANON_KEY` (auto-set)
   - `SUPABASE_SERVICE_ROLE_KEY` (auto-set)

## Step 3: Deploy Edge Functions

### Option A: Using Supabase CLI (Recommended)

1. **Install Supabase CLI:**
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase:**
   ```bash
   supabase login
   ```

3. **Link your project:**
   ```bash
   supabase link --project-ref your-project-ref
   ```

4. **Deploy all functions:**
   ```bash
   supabase functions deploy ingest-movie
   supabase functions deploy get-movie-card
   supabase functions deploy search-movies
   supabase functions deploy batch-ingest
   ```

### Option B: Using Supabase Dashboard

1. **For each function:**
   - Go to Edge Functions in Supabase Dashboard
   - Click "Create a new function"
   - Name it (e.g., `ingest-movie`)
   - Copy the contents from `supabase/functions/[function-name]/index.ts`
   - Paste into the editor
   - Click "Deploy"

2. **Deploy these functions:**
   - `ingest-movie`
   - `get-movie-card`
   - `search-movies`
   - `batch-ingest`

## Step 4: Test the Pipeline

### Test 1: Batch Ingest Seed Movies

1. **Call the batch-ingest function:**
   ```bash
   curl -X POST \
     'https://your-project.supabase.co/functions/v1/batch-ingest' \
     -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
     -H 'Content-Type: application/json'
   ```

2. **Check results:**
   - Should process 10 movies at a time
   - Check `works_meta` table for populated data
   - Check `work_cards_cache` for cached cards

### Test 2: Get a Movie Card

1. **Call get-movie-card:**
   ```bash
   curl 'https://your-project.supabase.co/functions/v1/get-movie-card?tmdb_id=496243' \
     -H 'Authorization: Bearer YOUR_ANON_KEY'
   ```

2. **Expected response:**
   - JSON object with complete movie card
   - Includes cast, crew, AI score, etc.

### Test 3: Search Movies

1. **Call search-movies:**
   ```bash
   curl 'https://your-project.supabase.co/functions/v1/search-movies?q=batman' \
     -H 'Authorization: Bearer YOUR_ANON_KEY'
   ```

2. **Expected response:**
   - Array of movie search results
   - Each with tmdb_id, title, poster, etc.

## Step 5: iOS App Integration

The Swift code has been updated to use the new endpoints:

### New Models
- `MovieCard.swift` - Pre-built movie card model
- `MovieSearchResult` - Search result model

### Updated Service
- `SupabaseService.swift` now includes:
  - `fetchMovieCard(tmdbId:)` - Get movie card
  - `searchMovies(query:year:)` - Search movies
  - `ingestMovie(tmdbId:forceRefresh:)` - Trigger ingestion

### Usage Example

```swift
// Fetch a movie card
let card = try await SupabaseService.shared.fetchMovieCard(tmdbId: "496243")

// Search for movies
let results = try await SupabaseService.shared.searchMovies(query: "batman")

// Force refresh a movie
let refreshedCard = try await SupabaseService.shared.ingestMovie(tmdbId: "496243", forceRefresh: true)
```

## Step 6: Verify Everything Works

### Checklist

- [ ] Database schema created successfully
- [ ] 25 seed movies inserted into `works` table
- [ ] Edge Functions deployed
- [ ] TMDB_API_KEY configured
- [ ] Batch ingest processes movies successfully
- [ ] Movie cards are cached in `work_cards_cache`
- [ ] AI scores computed in `aggregates` table
- [ ] iOS app can fetch movie cards
- [ ] iOS app can search movies

## Troubleshooting

### TMDB Rate Limits
- TMDB allows ~40 requests per 10 seconds
- Batch ingest uses 250ms delays between requests
- If you hit limits, increase delay to 500ms in `batch-ingest/index.ts`

### Missing Posters
- Some movies don't have posters in TMDB
- Code handles null `poster_path` gracefully
- Consider adding placeholder images

### RLS Errors
- Edge Functions use `service_role` key (bypasses RLS)
- Client calls use `anon` key (read-only for movie data)
- Verify RLS policies allow public read access

### Function Not Found
- Ensure functions are deployed
- Check function names match exactly
- Verify project URL is correct

## Next Steps

1. **Populate all 25 seed movies:**
   - Run `batch-ingest` multiple times until all movies are processed
   - Or increase the limit in the function

2. **Test staleness refresh:**
   - Manually set `last_refreshed_at` to 30 days ago on a movie
   - Request that movie via `get-movie-card`
   - Verify it was refreshed

3. **Integrate with iOS app:**
   - Update views to use `MovieCard` instead of `Movie`
   - Replace TMDB direct calls with Edge Function calls
   - Test end-to-end: search → add to list → view card

## File Structure

```
supabase/
├── migrations/
│   └── tasty_mangoes_schema.sql    # Database schema
├── functions/
│   ├── _shared/
│   │   └── tmdb.ts                  # TMDB API utilities
│   ├── ingest-movie/
│   │   └── index.ts                 # Main ingestion pipeline
│   ├── get-movie-card/
│   │   └── index.ts                 # Fetch movie card
│   ├── search-movies/
│   │   └── index.ts                 # Search TMDB
│   └── batch-ingest/
│       └── index.ts                 # Batch process seed movies
```

## Support

If you encounter issues:
1. Check Supabase function logs in Dashboard
2. Verify environment variables are set
3. Test TMDB API key directly
4. Check database RLS policies
5. Review Edge Function error responses

