//  TMDB_INGESTION_DISCOVERY_REPORT.md
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:45 (America/Los_Angeles - Pacific Time)
//  Notes: Comprehensive discovery report for TMDB Scheduled Ingest + Daily Refresh (v3)

# TMDB Scheduled Ingest + Daily Refresh Discovery Report

## 0) Current Ingest Implementation

### Entrypoints
- **Primary**: `supabase/functions/scheduled-ingest/index.ts`
  - Edge Function: `scheduled-ingest`
  - Entrypoint: HTTP POST to `/functions/v1/scheduled-ingest`
  - Can be triggered manually or via scheduled job

- **Core Ingestion**: `supabase/functions/ingest-movie/index.ts`
  - Edge Function: `ingest-movie`
  - Entrypoint: HTTP POST to `/functions/v1/ingest-movie`
  - Called internally by `scheduled-ingest` for each movie

- **Batch Processing**: `supabase/functions/batch-ingest/index.ts`
  - Edge Function: `batch-ingest`
  - Used for bulk re-ingestion with pagination

### Architecture
- **Platform**: Supabase Edge Functions (Deno runtime)
- **Type**: Serverless Edge Functions, not standalone scripts
- **Scheduling**: Currently **NOT configured** - function exists but no cron/scheduler found

### TMDB Endpoints Called

#### From `scheduled-ingest`:
1. **`GET /movie/popular`** - Popular movies list
   - Params: `api_key`, `language=en-US`, `page={1-5}`
   - Max pages: 5 per source (hard-coded)
   
2. **`GET /movie/now_playing`** - Currently playing movies
   - Params: `api_key`, `language=en-US`, `page={1-5}`
   
3. **`GET /trending/movie/week`** - Weekly trending movies
   - Params: `api_key`, `language=en-US`, `page={1-5}`

#### From `ingest-movie` (per movie, ~8-10 calls):
1. **`GET /movie/{id}`** - Movie details
   - Params: `api_key`, `language=en-US`
   
2. **`GET /movie/{id}/credits`** - Cast & crew
   - Params: `api_key`
   
3. **`GET /movie/{id}/videos`** - Trailers/clips
   - Params: `api_key`
   
4. **`GET /movie/{id}/similar`** - Similar movies (limited to 10)
   - Params: `api_key`, `language=en-US`
   
5. **`GET /movie/{id}/release_dates`** - Release dates & certifications
   - Params: `api_key`
   
6. **`GET /movie/{id}/images`** - Posters & backdrops
   - Params: `api_key`
   
7. **`GET /movie/{id}/keywords`** - Keywords/tags
   - Params: `api_key`
   
8. **`GET /movie/{id}/watch/providers`** - Streaming providers
   - Params: `api_key`

### TMDB API Credentials
- **Storage**: Supabase Edge Function Secrets
- **Environment Variable**: `TMDB_API_KEY`
- **Loading**: `Deno.env.get('TMDB_API_KEY')` in `scheduled-ingest/index.ts` and `_shared/tmdb.ts`
- **Configuration**: Set via Supabase Dashboard → Project Settings → Edge Functions → Secrets

---

## 1) Database Layer and Schema

### Platform
- **Database**: Supabase Postgres (PostgreSQL)

### Core Tables

#### `works` (Master Movie Index)
- **Primary Key**: `work_id` (BIGSERIAL)
- **Unique Constraint**: `tmdb_id` (TEXT UNIQUE NOT NULL)
- **Other Keys**: `imdb_id` (TEXT UNIQUE, nullable)
- **Columns**:
  - `work_id` BIGSERIAL PRIMARY KEY
  - `tmdb_id` TEXT UNIQUE NOT NULL
  - `imdb_id` TEXT UNIQUE (nullable)
  - `title` TEXT NOT NULL
  - `original_title` TEXT
  - `year` INT
  - `release_date` DATE
  - `last_refreshed_at` TIMESTAMPTZ DEFAULT now()
  - `request_count` INT DEFAULT 0
  - `ingestion_status` TEXT DEFAULT 'pending' CHECK (IN ('pending', 'ingesting', 'complete', 'failed'))
  - `created_at` TIMESTAMPTZ DEFAULT now()
  - `updated_at` TIMESTAMPTZ DEFAULT now()

- **Indexes**:
  - `idx_works_tmdb_id` ON `tmdb_id`
  - `idx_works_imdb_id` ON `imdb_id`
  - `idx_works_title` ON `title`
  - `idx_works_year` ON `year`
  - `idx_works_release_date` ON `release_date`
  - `idx_works_last_refreshed` ON `last_refreshed_at`
  - `idx_works_ingestion_status` ON `ingestion_status`

#### `works_meta` (Rich Metadata)
- **Primary Key**: `work_id` (references `works.work_id`)
- **One-to-one** relationship with `works`
- **Key Columns**:
  - `runtime_minutes`, `runtime_display`
  - `tagline`, `overview`, `overview_short`
  - `genres` TEXT[]
  - `certification` TEXT (MPAA rating)
  - `poster_url_small`, `poster_url_medium`, `poster_url_large`, `poster_url_original`
  - `backdrop_url`, `backdrop_url_mobile`
  - `cast_members` JSONB (array of cast objects)
  - `crew_members` JSONB (array of crew objects)
  - `trailers` JSONB (array of trailer objects)
  - `still_images` JSONB (array of image URLs)
  - `streaming` JSONB (watch providers)
  - `keywords` TEXT[]
  - `production_companies` JSONB
  - `production_countries` TEXT[]
  - `budget` BIGINT
  - `revenue_worldwide` BIGINT
  - `schema_version` INTEGER DEFAULT 1
  - `fetched_at` TIMESTAMPTZ DEFAULT now()
  - `updated_at` TIMESTAMPTZ DEFAULT now()

#### `rating_sources` (Rating Inputs)
- **Primary Key**: `rating_id` (BIGSERIAL)
- **Unique Constraint**: `(work_id, source_name)`
- **Columns**: `work_id`, `source_name`, `scale_type`, `value_raw`, `value_0_100`, `votes_count`, `last_seen_at`

#### `aggregates` (AI Scores)
- **Primary Key**: `(work_id, method_version)`
- **Columns**: `work_id`, `method_version`, `ai_score`, `ai_score_low`, `ai_score_high`, `source_scores` JSONB, `computed_at`

#### `work_cards_cache` (Pre-built Cards)
- **Primary Key**: `work_id`
- **Columns**: `work_id`, `payload` JSONB, `payload_short` JSONB, `etag`, `computed_at`

#### `similar_movies` (Similar Movie Links)
- **Columns**: `work_id`, `similar_tmdb_id`, `source`, `rank_order`, `confidence`, `notes`, `created_at`
- **Unique Constraint**: `(work_id, similar_tmdb_id, source)`

### Content Type
- **Current**: Movies only (no TV shows)
- **TMDB Type**: Uses `/movie/` endpoints exclusively

### Duplicate Prevention
- **Unique Constraint**: `tmdb_id` UNIQUE on `works` table
- **Upsert Logic**: Uses `ON CONFLICT (tmdb_id)` in `ingest-movie`

---

## 2) How TMDB Data is Stored

### Core Fields Storage
- **Location**: `works` table (identity) + `works_meta` table (metadata)
- **Fields Stored**:
  - Title, year, release_date → `works`
  - Overview, runtime, genres → `works_meta`
  - Budget, revenue → `works_meta`
  - TMDB ratings → `rating_sources` table (source_name='TMDB')

### Credits/Cast/Crew Storage
- **Format**: **JSONB arrays** in `works_meta` table
- **Cast**: `cast_members` JSONB column
  - Structure: `[{person_id, name, character, order, photo_url_small, photo_url_medium, photo_url_large, gender}, ...]`
- **Crew**: `crew_members` JSONB column
  - Structure: `[{person_id, name, job, department, photo_url_small, photo_url_medium}, ...]`
- **NOT normalized** - stored as JSONB blobs, not separate join tables

### Images and Videos Storage
- **Strategy**: **Downloaded and re-hosted** in Supabase Storage
- **Bucket**: `movie-images`
- **Structure**:
  - `posters/{work_id}_medium.jpg` (342px)
  - `posters/{work_id}_large.jpg` (500px)
  - `backdrops/{work_id}.jpg` (780px)
  - `trailers/{work_id}_thumb.jpg` (YouTube thumbnail)
  - `trailers/{work_id}_{index}.jpg` (trailer thumbnails)
  - `cast/{person_id}.jpg` (cast photos)
  - `stills/{work_id}_{index}.jpg` (still images)
- **URLs Stored**: Full Supabase Storage URLs in `works_meta` columns
- **Fallback**: TMDB URLs stored if download fails

### External IDs Storage
- **IMDb ID**: Stored in `works.imdb_id` (TEXT, nullable)
- **TMDB ID**: Stored in `works.tmdb_id` (TEXT, primary identifier)
- **Other IDs**: Not currently stored

---

## 3) Ingest Pipeline Behavior

### Ingest Sources (from `scheduled-ingest`)
1. **Popular** (`/movie/popular`)
2. **Now Playing** (`/movie/now_playing`)
3. **Trending** (`/trending/movie/week`)

### Filters Applied
- **Language**: `language=en-US` (hard-coded)
- **Pagination**: Up to 5 pages per source (hard-coded limit)
- **Max Movies**: Default 20, configurable via `max_movies` parameter
- **Deduplication**: By `tmdb_id` before ingestion

### Pagination
- **Yes**: Fetches multiple pages
- **Pages per source**: Up to 5 pages (hard-coded `maxPagesPerSource = 5`)
- **Movies per page**: ~20 (TMDB default)
- **Total potential**: Up to 300 movies (3 sources × 5 pages × 20 movies), deduplicated

### Enrichment Strategy
- **One-pass ingestion**: All endpoints called in sequence
- **Endpoints used**: 8 endpoints per movie (details, credits, videos, similar, release_dates, images, keywords, watch_providers)
- **No `append_to_response`**: Each endpoint called separately
- **Rate limiting**: 250ms delay between calls (hard-coded)

### Works Table Population
- **Code Path**: `ingest-movie/index.ts` lines 478-494
- **Upsert Logic**: `upsert(workData, { onConflict: 'tmdb_id' })`
- **Status Tracking**: Sets `ingestion_status` to 'ingesting' → 'complete' or 'failed'

### Duplicate Prevention
- **Pre-check**: `scheduled-ingest` checks existing `tmdb_id`s before calling `ingest-movie`
- **Upsert**: `ingest-movie` uses `ON CONFLICT (tmdb_id)` to prevent duplicates
- **Status Check**: If `ingestion_status='ingesting'`, waits up to 30 seconds for completion
- **Cache Check**: If `ingestion_status='complete'` and not stale, returns cached card

### Staleness Logic
- **Function**: `is_stale(work_id)` database function
- **Logic**: Based on `release_date` and `last_refreshed_at`
  - Movies ≤30 days old: refresh every 2 days
  - Movies 31-180 days old: refresh every 7 days
  - Movies 181-365 days old: refresh every 14 days
  - Movies >365 days old: refresh every 30 days
- **Schema Version**: Also checks `schema_version` in `works_meta` (current version: 4)

---

## 4) Cron / Scheduled Job Architecture

### Current Scheduling
- **Status**: **NOT CONFIGURED**
- **Function Exists**: `scheduled-ingest` Edge Function exists
- **No Cron Found**: No Supabase cron jobs, pg_cron, GitHub Actions, or external scheduler found
- **Manual Trigger**: Currently must be triggered manually via HTTP POST

### Schedule Configuration
- **Location**: **MISSING** - no configuration file found
- **How to Change**: Would need to set up Supabase cron or external scheduler

### Observability
- **Logs**: Edge Function logs available in Supabase Dashboard → Edge Functions → scheduled-ingest → Logs
- **Database Logging**: `scheduled_ingestion_log` table referenced in code but **MIGRATION NOT FOUND**
  - Code expects columns: `source`, `movies_checked`, `movies_skipped`, `movies_ingested`, `movies_failed`, `ingested_titles`, `failed_titles`, `duration_ms`, `trigger_type`, `created_at`
- **API Call Logging**: `tmdb_api_logs` table exists (migration `011_add_tmdb_api_logs.sql`)
  - Tracks all TMDB API calls with endpoint, status, response time, edge function, etc.

### Job Failure Handling
- **No Retry Logic**: Failures are logged but not automatically retried
- **Status Tracking**: `ingestion_status='failed'` set on error
- **Error Logging**: Errors logged to console and `scheduled_ingestion_log` (if table exists)

---

## 5) Daily Refresh Existing Movies - Feasibility

### Last Refreshed Tracking
- **✅ EXISTS**: `works.last_refreshed_at` TIMESTAMPTZ column
- **Updated**: Set to `now()` on each ingestion (line 486 in `ingest-movie/index.ts`)

### Sync Cursor Storage
- **❌ MISSING**: No table or column for storing sync cursor (e.g., last successful TMDB change window end date)
- **Would Need**: New table or column to track last sync timestamp

### Queue Table Pattern
- **❌ MISSING**: No queue table pattern found
- **Would Need**: New table like `refresh_queue` with columns: `work_id`, `priority`, `status`, `queued_at`, `processed_at`, `retry_count`

### Existing Workers/Queues
- **❌ NONE**: No existing worker/queue infrastructure
- **Options**: Would need to implement:
  - Supabase Edge Function worker (polling-based)
  - pg_cron job that processes queue
  - External queue service (Redis, etc.)

---

## 6) Dashboard Requirements

### Dashboard Location
- **Path**: `src/app/page.tsx` (Next.js app)
- **Components**:
  - `src/components/TMDBAnalytics.tsx` - TMDB API analytics
  - `src/components/MoviesList.tsx` - Movies list
  - `src/components/StatsBar.tsx` - Stats display
  - `src/components/DataTable.tsx` - Data table component

### Current Metrics Loading
- **Method**: Direct Supabase client queries
- **Client**: `src/lib/supabase.ts` - Supabase JS client
- **Queries**: Direct `from('tmdb_api_logs')` and `from('works')` queries

### Job Run Tracking
- **Table**: `scheduled_ingestion_log` **REFERENCED BUT NOT CREATED**
  - Code in `scheduled-ingest/index.ts` line 313 tries to insert
  - Migration file **NOT FOUND**
  - **Schema Expected** (from code):
    ```sql
    CREATE TABLE scheduled_ingestion_log (
      id BIGSERIAL PRIMARY KEY,
      source TEXT, -- 'popular', 'now_playing', 'trending', 'mixed'
      movies_checked INT,
      movies_skipped INT,
      movies_ingested INT,
      movies_failed INT,
      ingested_titles TEXT[], -- Array of "Title (Year)" strings
      failed_titles TEXT[], -- Array of "Title: Error" strings
      duration_ms INT,
      trigger_type TEXT, -- 'scheduled' or 'manual'
      created_at TIMESTAMPTZ DEFAULT now()
    );
    ```

### Recommended Dashboard Additions
1. **Run History Table**
   - Show `scheduled_ingestion_log` entries
   - Columns: Start time, end time, source, movies checked/skipped/ingested/failed, duration, trigger type
   
2. **TMDB Calls Breakdown**
   - Already exists in `tmdb_api_logs` table
   - Show counts by endpoint, edge function, time period
   - Error counts and top errors
   
3. **Queue Backlog** (if daily refresh implemented)
   - Show `refresh_queue` table entries
   - Status: queued / processing / failed
   - Priority, retry count, last error

---

## 7) Performance, Cost, and Compliance

### Current TMDB Request Rate
- **Scheduled Ingest**: 
  - List endpoints: 3 sources × 5 pages = 15 calls
  - Per movie: 8-10 calls
  - Total for 20 movies: ~15 + (20 × 8) = ~175 calls per run
- **Rate Limiting**: 
  - 500ms delay between list page fetches
  - 250ms delay between movie detail calls
  - 1000ms delay between `ingest-movie` calls
- **Estimated Duration**: ~20-30 seconds for 20 movies

### Throttling/Backoff/Retry
- **✅ Basic Throttling**: Fixed delays (250ms, 500ms, 1000ms)
- **❌ No Backoff**: No exponential backoff on 429 errors
- **❌ No Retry**: Failed calls are logged but not retried
- **TMDB Rate Limit**: 40 requests per 10 seconds (per API key)
- **Current Rate**: ~4 requests/second (within limit)

### Response Caching
- **✅ Cached**: `work_cards_cache` table stores pre-built movie cards
- **✅ Staleness Check**: `is_stale()` function prevents unnecessary refreshes
- **❌ No Raw TMDB JSON**: Only processed data stored, not raw API responses

### TMDB Attribution
- **Status**: **UNKNOWN** - need to verify app UI shows TMDB attribution
- **Requirement**: TMDB requires attribution in UI

### Bulk Mirroring
- **❌ NOT Doing**: Only uses list endpoints (popular, now_playing, trending)
- **✅ Limited**: No iteration over ID ranges
- **✅ List-Based**: Only fetches from curated TMDB lists

---

## 8) Current State Summary

### Ingest Entrypoints
- ✅ `scheduled-ingest` Edge Function exists
- ✅ `ingest-movie` Edge Function exists
- ❌ **No scheduler configured** - must trigger manually

### Schemas
- ✅ `works` table with `last_refreshed_at` and `ingestion_status`
- ✅ `works_meta` table with rich metadata
- ✅ `tmdb_api_logs` table for API call tracking
- ❌ **`scheduled_ingestion_log` table MISSING** (referenced but not created)

### Schedules
- ❌ **No cron/scheduler found**
- ❌ **No schedule configuration**

### What's Missing for Daily Refresh
1. **Queue Table**: `refresh_queue` table for tracking movies to refresh
2. **Sync Cursor**: Table/column to track last sync timestamp
3. **Worker/Processor**: Edge Function or pg_cron job to process queue
4. **Scheduler**: Cron job to trigger daily refresh
5. **`scheduled_ingestion_log` Table**: Migration needed

### What's Missing for Dashboard Visibility
1. **`scheduled_ingestion_log` Migration**: Create the table
2. **Dashboard Component**: Add "Ingestion Runs" tab/section
3. **Queue Dashboard**: If daily refresh implemented, show queue status

---

## 9) Proposed Next State Plan

### Minimal New Tables Needed

#### 1. `scheduled_ingestion_log` (Create Missing Table)
```sql
CREATE TABLE scheduled_ingestion_log (
  id BIGSERIAL PRIMARY KEY,
  source TEXT NOT NULL, -- 'popular', 'now_playing', 'trending', 'mixed'
  movies_checked INT NOT NULL,
  movies_skipped INT NOT NULL,
  movies_ingested INT NOT NULL,
  movies_failed INT NOT NULL,
  ingested_titles TEXT[],
  failed_titles TEXT[],
  duration_ms INT NOT NULL,
  trigger_type TEXT NOT NULL, -- 'scheduled' or 'manual'
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_scheduled_ingestion_log_created_at ON scheduled_ingestion_log(created_at DESC);
CREATE INDEX idx_scheduled_ingestion_log_source ON scheduled_ingestion_log(source);
```

#### 2. `refresh_queue` (For Daily Refresh)
```sql
CREATE TABLE refresh_queue (
  id BIGSERIAL PRIMARY KEY,
  work_id BIGINT NOT NULL REFERENCES works(work_id) ON DELETE CASCADE,
  priority INT DEFAULT 0, -- Higher = more urgent
  status TEXT DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
  queued_at TIMESTAMPTZ DEFAULT now(),
  processed_at TIMESTAMPTZ,
  retry_count INT DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_refresh_queue_status ON refresh_queue(status, priority DESC, queued_at);
CREATE INDEX idx_refresh_queue_work_id ON refresh_queue(work_id);
```

#### 3. `sync_state` (For Sync Cursor)
```sql
CREATE TABLE sync_state (
  id BIGSERIAL PRIMARY KEY,
  sync_type TEXT UNIQUE NOT NULL, -- 'daily_refresh', 'scheduled_ingest', etc.
  last_sync_at TIMESTAMPTZ,
  last_sync_cursor TEXT, -- e.g., ISO timestamp or TMDB change window end
  sync_count INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### Job Schedule Recommendations

#### Weekly Scheduled Ingest (New Movies)
- **Frequency**: Once per week (e.g., Sunday 2 AM PST)
- **Function**: `scheduled-ingest`
- **Params**: `{ source: 'all', max_movies: 50, trigger_type: 'scheduled' }`
- **Scheduler**: Supabase cron or external (GitHub Actions, Vercel Cron)

#### Daily Refresh Existing Movies
- **Frequency**: Once per day (e.g., 3 AM PST)
- **Function**: New `daily-refresh` Edge Function
- **Logic**:
  1. Query `works` where `is_stale(work_id) = true`
  2. Insert into `refresh_queue` (batch of 100-200)
  3. Process queue (call `ingest-movie` with `force_refresh=false`)
  4. Update `sync_state.last_sync_at`

### Endpoints and Params (v3)

#### Daily Refresh Endpoints
- **Same as current**: Use existing `ingest-movie` function
- **No new endpoints needed**: Reuse `/movie/{id}`, `/movie/{id}/credits`, etc.

#### Recommended Params
- **Batch Size**: Process 50-100 movies per run
- **Rate Limiting**: Keep 250ms delays between calls
- **Priority**: Newer movies (≤30 days) get higher priority

### API Usage Safety

#### Current Rate Limits
- **TMDB Limit**: 40 requests per 10 seconds
- **Current Usage**: ~4 requests/second (safe)

#### Daily Refresh Safety
- **Estimated**: 100 movies × 8 calls = 800 calls
- **Duration**: ~200 seconds (3.3 minutes) with 250ms delays
- **Rate**: ~4 calls/second (within limit)
- **Recommendation**: Add exponential backoff on 429 errors

#### Compliance
- **Attribution**: Verify TMDB attribution in app UI
- **No Bulk Mirroring**: Continue using list endpoints only
- **Rate Respect**: Current delays are appropriate

---

## 10) Implementation Priority

### Phase 1: Fix Missing Infrastructure (High Priority)
1. ✅ Create `scheduled_ingestion_log` migration
2. ✅ Set up Supabase cron or external scheduler for `scheduled-ingest`
3. ✅ Add dashboard component for ingestion run history

### Phase 2: Daily Refresh Foundation (Medium Priority)
1. ✅ Create `refresh_queue` table migration
2. ✅ Create `sync_state` table migration
3. ✅ Create `daily-refresh` Edge Function
4. ✅ Set up daily cron job

### Phase 3: Enhanced Observability (Low Priority)
1. ✅ Add queue backlog dashboard
2. ✅ Add error tracking and retry logic
3. ✅ Add performance metrics dashboard

---

## Summary

**Current State**: Scheduled ingest function exists but is not scheduled. Daily refresh infrastructure is missing.

**Key Gaps**:
1. No scheduler configured
2. `scheduled_ingestion_log` table missing
3. No queue system for daily refresh
4. No sync cursor tracking

**Next Steps**: Create missing tables, set up scheduler, implement daily refresh queue processor.

