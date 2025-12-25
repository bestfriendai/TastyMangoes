# Phase 2 Implementation Summary: Automated Scheduling and Daily Refresh

## Overview
Phase 2 implements automated scheduling using Supabase pg_cron + pg_net for both scheduled ingestion and daily refresh of existing movies.

## Implementation Complete ✅

### Phase A: Scheduled Ingest (pg_cron + pg_net)

#### Migrations Created:
1. **016_enable_pg_net_and_setup_cron_auth.sql**
   - Enables `pg_net` extension
   - Creates `get_service_role_key()` function (secure auth helper)
   - Creates `get_supabase_url()` function (secure URL helper)
   - No hardcoded secrets - uses database settings

2. **017_create_scheduled_ingest_cron_jobs.sql**
   - Creates `call_scheduled_ingest()` function
   - Schedules `scheduled_ingest_daily` (03:00 PT, mixed_daily, 30 movies)
   - Schedules `scheduled_ingest_weekly` (Sundays 02:00 PT, mixed_weekly, 80 movies)

#### Edge Function Updates:
- **scheduled-ingest/index.ts**: Added support for `mixed_daily` and `mixed_weekly` sources
  - `mixed_daily`: fetches `now_playing` + `trending/movie/week`
  - `mixed_weekly`: fetches `popular` + `trending/movie/week`

### Phase B: Daily Refresh (Stale-Driven Queue)

#### Migrations Created:
3. **018_create_refresh_queue_and_sync_state.sql**
   - Creates `refresh_queue` table (work_id, status, priority, retry_count, etc.)
   - Creates `sync_state` table (tracks last sync time)
   - Adds RLS policies for service role and users

4. **019_add_get_stale_movies_function.sql**
   - Creates `get_stale_movies(limit_count)` helper function
   - Efficiently queries stale movies using `is_stale()` function

5. **020_create_refresh_cron_jobs.sql**
   - Creates `call_daily_refresh()` function
   - Creates `call_refresh_worker()` function
   - Schedules `daily_refresh_enqueue` (03:30 PT daily)
   - Schedules `refresh_worker` (every 10 minutes)

#### Edge Functions Created:
- **daily-refresh/index.ts**: Enqueues stale movies into refresh_queue
  - Uses `get_stale_movies()` or manual `is_stale()` check
  - Limits to 100 movies per run
  - Updates `sync_state.last_sync_at`

- **refresh-worker/index.ts**: Processes refresh_queue
  - Claims up to 10 items atomically per run
  - Calls `ingest-movie` Edge Function to refresh metadata
  - Handles retries (max 3 attempts)
  - Updates `last_refreshed_at` automatically (via ingest-movie)

### Phase C: Documentation

- **docs/cron-jobs.md**: Comprehensive documentation updated
  - Configuration instructions
  - Job schedules and purposes
  - Observability tables
  - Management commands
  - Security notes

## Configuration Required

**Before running migrations**, set these database settings:

```sql
-- Set Supabase URL
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project-ref.supabase.co';

-- Set Service Role Key (get from Supabase Dashboard: Settings > API)
ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key';
```

Or set via Supabase Dashboard: Settings > Database > Custom Config

## Verification Checklist

After running migrations, verify:

1. **Extensions enabled**:
   ```sql
   SELECT * FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net');
   ```

2. **Cron jobs exist**:
   ```sql
   SELECT jobname, schedule, command FROM cron.job;
   ```
   Should show 4 jobs: `scheduled_ingest_daily`, `scheduled_ingest_weekly`, `daily_refresh_enqueue`, `refresh_worker`

3. **Tables created**:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name IN ('refresh_queue', 'sync_state');
   ```

4. **Functions exist**:
   ```sql
   SELECT routine_name FROM information_schema.routines 
   WHERE routine_schema = 'public' 
   AND routine_name IN ('get_service_role_key', 'get_supabase_url', 'call_scheduled_ingest', 'call_daily_refresh', 'call_refresh_worker', 'get_stale_movies');
   ```

5. **Edge Functions deployed**:
   - `scheduled-ingest` (updated)
   - `daily-refresh` (new)
   - `refresh-worker` (new)

## Testing

### Manual Test Scheduled Ingest:
```sql
-- Test the function directly
SELECT call_scheduled_ingest('mixed_daily', 5, 'manual');
```

### Manual Test Daily Refresh:
```sql
-- Test enqueue
SELECT call_daily_refresh();

-- Check queue
SELECT * FROM refresh_queue ORDER BY queued_at DESC LIMIT 10;

-- Test worker
SELECT call_refresh_worker();
```

### Check Logs:
```sql
-- Scheduled ingest logs
SELECT * FROM scheduled_ingestion_log ORDER BY created_at DESC LIMIT 10;

-- Refresh queue status
SELECT status, COUNT(*) FROM refresh_queue GROUP BY status;

-- Sync state
SELECT * FROM sync_state;
```

## Security Notes

✅ **No hardcoded secrets** - All credentials stored in database settings  
✅ **RLS enabled** - Tables have proper Row Level Security policies  
✅ **Service role only** - Edge Functions use service role key for admin operations  
✅ **Secure functions** - Helper functions use `SECURITY DEFINER` appropriately  

## Next Steps

1. Run migrations in order (016 → 017 → 018 → 019 → 020)
2. Configure database settings (supabase_url and service_role_key)
3. Deploy Edge Functions (`daily-refresh` and `refresh-worker`)
4. Verify cron jobs are scheduled
5. Monitor `scheduled_ingestion_log` and `refresh_queue` tables
6. Check `tmdb_api_logs` for API usage

## Files Changed/Created

### Migrations:
- `supabase/migrations/016_enable_pg_net_and_setup_cron_auth.sql` (NEW)
- `supabase/migrations/017_create_scheduled_ingest_cron_jobs.sql` (NEW)
- `supabase/migrations/018_create_refresh_queue_and_sync_state.sql` (NEW)
- `supabase/migrations/019_add_get_stale_movies_function.sql` (NEW)
- `supabase/migrations/020_create_refresh_cron_jobs.sql` (NEW)

### Edge Functions:
- `supabase/functions/scheduled-ingest/index.ts` (UPDATED)
- `supabase/functions/daily-refresh/index.ts` (NEW)
- `supabase/functions/refresh-worker/index.ts` (NEW)

### Documentation:
- `docs/cron-jobs.md` (UPDATED)

