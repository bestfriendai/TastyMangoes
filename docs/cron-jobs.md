# Tasty Mangoes – Scheduled Jobs (Cron)

This document tracks all automated jobs running in production.

## Platform
- Scheduler: Supabase pg_cron
- HTTP calls: pg_net → Supabase Edge Functions
- Environment: Production

---

## Configuration Required

**IMPORTANT**: Before cron jobs will work, you must configure database settings:

1. **Set Supabase URL**:
   ```sql
   ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project-ref.supabase.co';
   ```
   Or via Supabase Dashboard: Settings > Database > Custom Config

2. **Set Service Role Key**:
   ```sql
   ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key';
   ```
   Or via Supabase Dashboard: Settings > Database > Custom Config
   
   **Security Note**: Never commit the service role key to git. Store it securely in Supabase Dashboard.

---

## Active Jobs

### 1) Scheduled Ingest – Daily
- **Job name**: `scheduled_ingest_daily`
- **Schedule**: Daily @ 03:00 America/Los_Angeles (11:00 UTC)
- **Cron expression**: `0 11 * * *`
- **Trigger**: pg_cron → pg_net.http_post → `call_scheduled_ingest()`
- **Edge Function**: `scheduled-ingest`
- **Payload**:
  ```json
  {
    "source": "mixed_daily",
    "max_movies": 30,
    "trigger_type": "scheduled"
  }
  ```
- **Sources fetched**: `now_playing` + `trending/movie/week`
- **Purpose**: Import newly released / trending movies daily
- **Logs to**: `scheduled_ingestion_log` table

---

### 2) Scheduled Ingest – Weekly
- **Job name**: `scheduled_ingest_weekly`
- **Schedule**: Sundays @ 02:00 America/Los_Angeles (10:00 UTC Sunday)
- **Cron expression**: `0 10 * * 0`
- **Trigger**: pg_cron → pg_net.http_post → `call_scheduled_ingest()`
- **Edge Function**: `scheduled-ingest`
- **Payload**:
  ```json
  {
    "source": "mixed_weekly",
    "max_movies": 80,
    "trigger_type": "scheduled"
  }
  ```
- **Sources fetched**: `popular` + `trending/movie/week`
- **Purpose**: Broader catalog refresh (popular + trending)
- **Logs to**: `scheduled_ingestion_log` table

---

### 3) Daily Refresh – Queue Fill
- **Job name**: `daily_refresh_enqueue`
- **Schedule**: Daily @ 03:30 America/Los_Angeles (11:30 UTC)
- **Cron expression**: `30 11 * * *`
- **Trigger**: pg_cron → pg_net.http_post → `call_daily_refresh()`
- **Edge Function**: `daily-refresh`
- **Purpose**: 
  - Find stale movies via `is_stale()` function
  - Enqueue up to 100 stale movies into `refresh_queue`
  - Update `sync_state.last_sync_at`
- **Staleness logic**: Based on `release_date` and `last_refreshed_at`
  - Movies ≤30 days old: refresh every 2 days
  - Movies 31-180 days old: refresh every 7 days
  - Movies 181-365 days old: refresh every 14 days
  - Movies >365 days old: refresh every 30 days

---

### 4) Refresh Worker
- **Job name**: `refresh_worker`
- **Schedule**: Every 10 minutes
- **Cron expression**: `*/10 * * * *`
- **Trigger**: pg_cron → pg_net.http_post → `call_refresh_worker()`
- **Edge Function**: `refresh-worker`
- **Purpose**:
  - Process `refresh_queue` (claims up to 10 items per run)
  - Calls `ingest-movie` Edge Function to refresh metadata
  - Updates `last_refreshed_at` automatically (via `ingest-movie`)
  - Retries failed items up to 3 times with exponential backoff
- **Processing**: Atomic claim using `status='queued'` filter (prevents duplicate processing)

---

## Observability

### Tables
- **`scheduled_ingestion_log`**: All scheduled ingest runs (daily + weekly)
  - Columns: `source`, `movies_checked`, `movies_ingested`, `movies_failed`, `duration_ms`, `trigger_type`, `created_at`
- **`tmdb_api_logs`**: All TMDB API calls (from all Edge Functions)
- **`refresh_queue`**: Queue of movies needing refresh
  - Columns: `work_id`, `status`, `priority`, `queued_at`, `processed_at`, `retry_count`, `last_error`
- **`sync_state`**: Last sync time for `daily_refresh_stale`

### Viewing Jobs
```sql
-- List all cron jobs
SELECT * FROM cron.job;

-- View job run history (if enabled)
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 50;

-- Check refresh queue status
SELECT status, COUNT(*) as count 
FROM refresh_queue 
GROUP BY status;

-- Check sync state
SELECT * FROM sync_state WHERE sync_type = 'daily_refresh_stale';
```

---

## Management

### Pause a Job
```sql
SELECT cron.unschedule('scheduled_ingest_daily');
```

### Resume a Job
```sql
-- Re-run the migration that creates the job, or manually:
SELECT cron.schedule('scheduled_ingest_daily', '0 11 * * *', $$SELECT call_scheduled_ingest('mixed_daily', 30, 'scheduled');$$);
```

### Modify Schedule
```sql
-- Unschedule old job
SELECT cron.unschedule('scheduled_ingest_daily');

-- Schedule with new time
SELECT cron.schedule('scheduled_ingest_daily', '0 12 * * *', $$SELECT call_scheduled_ingest('mixed_daily', 30, 'scheduled');$$);
```

---

## Implementation Details

### Migrations
- `016_enable_pg_net_and_setup_cron_auth.sql`: Enable pg_net, create auth helper functions
- `017_create_scheduled_ingest_cron_jobs.sql`: Create scheduled ingest cron jobs
- `018_create_refresh_queue_and_sync_state.sql`: Create refresh_queue and sync_state tables
- `019_add_get_stale_movies_function.sql`: Helper function for efficient stale movie queries
- `020_create_refresh_cron_jobs.sql`: Create refresh enqueue and worker cron jobs

### Edge Functions
- `scheduled-ingest`: Handles `mixed_daily` and `mixed_weekly` sources
- `daily-refresh`: Enqueues stale movies into refresh_queue
- `refresh-worker`: Processes refresh_queue and calls ingest-movie

### Security
- No hardcoded secrets in SQL migrations
- Service role key stored in database settings (`app.settings.service_role_key`)
- Supabase URL stored in database settings (`app.settings.supabase_url`)
- Set via Supabase Dashboard or `ALTER DATABASE` commands

---

## Notes
- pg_cron + pg_net confirmed working on Supabase free plan
- All jobs use async HTTP calls via `pg_net.http_post()` (non-blocking)
- Jobs are idempotent and safe to run multiple times
- Refresh worker uses atomic claims to prevent duplicate processing
- All Edge Functions log to observability tables for monitoring

