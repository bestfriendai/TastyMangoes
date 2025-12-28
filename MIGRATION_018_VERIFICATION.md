# Migration 018 Verification: works Table Schema

## ✅ Confirmation: No Dependencies on `movies` Table

**Checked all migrations (001-020):**
- ✅ `movies` table only exists in `001_initial_schema.sql` (legacy)
- ✅ No migrations after 001 reference `movies` table
- ✅ `watchlist_movies`, `watch_history`, `user_ratings` use `movie_id TEXT` (just a string, no FK)
- ✅ All Edge Functions use `works` table exclusively

## ✅ works Table Schema (Complete Minimal Schema)

Migration 018 creates `works` table with all columns required by Edge Functions:

### Required Columns (from Edge Function analysis):

1. **`work_id`** (BIGSERIAL PRIMARY KEY)
   - Used by: All Edge Functions, refresh_queue FK, all related tables

2. **`tmdb_id`** (TEXT UNIQUE NOT NULL)
   - Used by: `ingest-movie`, `scheduled-ingest`, `daily-refresh`, `refresh-worker`
   - Primary identifier for all ingestion operations

3. **`imdb_id`** (TEXT UNIQUE, nullable)
   - Used by: `ingest-movie` (optional)

4. **`title`** (TEXT NOT NULL)
   - Used by: `daily-refresh`, `get-similar-movies`, `batch-ingest`

5. **`original_title`** (TEXT, nullable)
   - Used by: `ingest-movie` (optional)

6. **`year`** (INT, nullable)
   - Used by: `get-similar-movies`, `batch-ingest`

7. **`release_date`** (DATE, nullable)
   - Used by: `is_stale()` function (critical for refresh queue)
   - Used by: `ingest-movie`

8. **`last_refreshed_at`** (TIMESTAMPTZ DEFAULT now())
   - Used by: `is_stale()` function (critical for refresh queue)
   - Used by: `daily-refresh`, `ingest-movie`

9. **`ingestion_status`** (TEXT DEFAULT 'pending' NOT NULL CHECK)
   - Used by: `ingest-movie`, `refresh-worker`, `batch-ingest`, `get-similar-movies`
   - Values: 'pending', 'ingesting', 'complete', 'failed'

10. **`request_count`** (INT DEFAULT 0)
    - Used by: Schema definition (for analytics)

11. **`created_at`** (TIMESTAMPTZ DEFAULT now())
    - Standard metadata

12. **`updated_at`** (TIMESTAMPTZ DEFAULT now())
    - Standard metadata

### Required Indexes:

- ✅ `idx_works_tmdb_id` - Used by all lookups
- ✅ `idx_works_imdb_id` - Used by optional lookups
- ✅ `idx_works_title` - Used by search
- ✅ `idx_works_year` - Used by filtering
- ✅ `idx_works_release_date` - Used by `is_stale()`
- ✅ `idx_works_last_refreshed` - Used by refresh queue queries
- ✅ `idx_works_ingestion_status` - Used by status filtering

### Required RLS Policies:

- ✅ Service role can manage (for Edge Functions)
- ✅ Users can read (for app queries)

## ✅ Verification: No Later Migrations Expect Different works Definition

**Checked migrations 019-020:**
- ✅ `019_add_get_stale_movies_function.sql` - Uses `works.work_id`, `works.tmdb_id`, `works.last_refreshed_at` ✅
- ✅ `020_create_refresh_cron_jobs.sql` - No direct works references ✅

**Checked Edge Functions:**
- ✅ All Edge Functions use columns that exist in migration 018's `works` definition ✅

## ✅ Summary

Migration 018 creates a **complete, minimal `works` table** that:
1. ✅ Includes all columns required by Edge Functions
2. ✅ Includes all indexes for performance
3. ✅ Includes correct defaults and constraints
4. ✅ Includes RLS policies
5. ✅ No later migrations expect different schema
6. ✅ No dependencies on `movies` table

**The migration is ready to use!**

