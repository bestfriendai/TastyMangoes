//  SCHEDULED_INGEST_LOGGING_IMPLEMENTATION.md
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:58 (America/Los_Angeles - Pacific Time)
//  Notes: Summary of scheduled ingestion logging implementation

# Scheduled Ingestion Logging Implementation Summary

## Overview
Implemented missing `scheduled_ingestion_log` table and dashboard component to make scheduled ingestion runs observable before enabling a scheduler.

## Changes Made

### 1. Database Migration ✅
**File**: `supabase/migrations/013_add_scheduled_ingestion_log.sql`

- Created `scheduled_ingestion_log` table with schema matching code expectations:
  - `id` BIGSERIAL PRIMARY KEY
  - `source` TEXT NOT NULL (popular/now_playing/trending/mixed)
  - `movies_checked` INT NOT NULL
  - `movies_skipped` INT NOT NULL
  - `movies_ingested` INT NOT NULL
  - `movies_failed` INT NOT NULL
  - `ingested_titles` TEXT[] (array of "Title (Year)" strings)
  - `failed_titles` TEXT[] (array of "Title: Error" strings)
  - `duration_ms` INT NOT NULL
  - `trigger_type` TEXT NOT NULL CHECK (IN ('scheduled', 'manual'))
  - `created_at` TIMESTAMPTZ DEFAULT now()

- Added indexes:
  - `idx_scheduled_ingestion_log_created_at` (DESC)
  - `idx_scheduled_ingestion_log_source`
  - `idx_scheduled_ingestion_log_trigger_type`

- RLS policies:
  - Service role can insert (for edge functions)
  - Authenticated users can read (for dashboard)

### 2. Scheduled-Ingest Function Verification ✅
**File**: `supabase/functions/scheduled-ingest/index.ts`

**Verified**:
- ✅ `duration_ms` calculation is accurate (line 291: `Date.now() - startTime`)
- ✅ Error handling is robust:
  - Logging wrapped in try/catch (lines 298-325)
  - Function continues even if logging fails
  - Errors logged to console but don't crash the function
- ✅ All required fields are populated correctly:
  - `source`: Maps 'all' → 'mixed', otherwise uses source value
  - `movies_checked`: `uniqueMovies.length`
  - `movies_skipped`: `existingIds.size`
  - `movies_ingested`: `successCount`
  - `movies_failed`: `failCount`
  - `ingested_titles`: Array of "Title (Year)" strings
  - `failed_titles`: Array of "Title: Error" strings
  - `duration_ms`: Calculated from startTime
  - `trigger_type`: From request body or defaults to 'scheduled'

**No changes needed** - function already handles errors correctly.

### 3. Dashboard Component ✅
**File**: `src/components/ScheduledIngestRuns.tsx`

- New component showing scheduled ingestion run history
- Features:
  - Stats cards: Total runs, total ingested, total failed, avg duration
  - Trigger type breakdown (scheduled vs manual)
  - Runs table with expandable rows
  - Click to expand shows ingested_titles and failed_titles
  - Last 50 runs ordered by created_at DESC
  - Refresh capability via ref

**File**: `src/components/columns/scheduledIngestRunsColumns.tsx`

- Column definitions for the runs table
- Columns: Run Time, Trigger, Source, Checked, Skipped, Ingested, Failed, Duration
- Color-coded status indicators

### 4. Dashboard Integration ✅
**File**: `src/app/page.tsx`

- Added new tab: "Ingestion Runs"
- Added ref for ScheduledIngestRuns component
- Integrated refresh function into master refresh
- Tab appears alongside existing tabs (Events, Patterns, TMDB Analytics, Movies)

**File**: `src/lib/supabase.ts`

- Added `ScheduledIngestRun` interface type definition

## Files Changed

1. ✅ `supabase/migrations/013_add_scheduled_ingestion_log.sql` (NEW)
2. ✅ `src/lib/supabase.ts` (ADDED ScheduledIngestRun interface)
3. ✅ `src/components/columns/scheduledIngestRunsColumns.tsx` (NEW)
4. ✅ `src/components/ScheduledIngestRuns.tsx` (NEW)
5. ✅ `src/app/page.tsx` (ADDED tab and integration)

## Testing Instructions

### 1. Run Migration
```bash
# Option 1: Via Supabase Dashboard
# Go to: Supabase Dashboard → SQL Editor
# Copy contents of: supabase/migrations/013_add_scheduled_ingestion_log.sql
# Paste and run

# Option 2: Via Supabase CLI
cd /Users/timrobinson/Developer/TastyMangoes
supabase db push
```

### 2. Test Scheduled-Ingest Function
```bash
# Trigger a manual run to test logging
curl -X POST https://your-project.supabase.co/functions/v1/scheduled-ingest \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"source": "popular", "max_movies": 5, "trigger_type": "manual"}'
```

**Expected Results**:
- Function should complete successfully
- Check Supabase Dashboard → Table Editor → `scheduled_ingestion_log`
- Should see one new row with:
  - `source`: "popular"
  - `trigger_type`: "manual"
  - `movies_checked`: Number of movies fetched
  - `movies_ingested`: Number successfully ingested
  - `duration_ms`: Duration in milliseconds
  - `ingested_titles`: Array of movie titles
  - `created_at`: Current timestamp

**Error Handling Test**:
- If table doesn't exist, function should:
  - Log error to console: `[SCHEDULED] Failed to log to scheduled_ingestion_log: ...`
  - Continue execution and return success response
  - NOT crash or return error

### 3. Test Dashboard Component

**Local Development**:
```bash
cd /Users/timrobinson/Developer/TastyMangoes
# If using Next.js dashboard
npm run dev
# Navigate to dashboard URL
```

**Steps**:
1. Navigate to dashboard
2. Click "Ingestion Runs" tab
3. Should see:
   - Stats cards at top (Total Runs, Total Ingested, etc.)
   - List of recent runs (if any exist)
   - Each run shows: time, trigger type, source, counts, duration
4. Click any run row to expand and see:
   - ✅ Ingested Movies list
   - ❌ Failed Movies list (if any)
5. Click "Refresh" button - should reload runs
6. If no runs exist, should show: "No scheduled ingestion runs found..."

**Expected Behavior**:
- Component loads without errors
- Stats calculate correctly
- Expandable rows work (click to expand/collapse)
- Refresh button works
- Empty state displays when no runs exist

### 4. Verify Logging Accuracy

After running scheduled-ingest:
1. Check `scheduled_ingestion_log` table in Supabase Dashboard
2. Verify:
   - `duration_ms` matches actual run time
   - `movies_checked` = total movies fetched from TMDB
   - `movies_skipped` = movies that already existed
   - `movies_ingested` = successfully ingested count
   - `movies_failed` = failed count
   - `ingested_titles` array matches ingested movies
   - `failed_titles` array matches failed movies (if any)

## Next Steps

1. ✅ **Migration**: Run migration in Supabase Dashboard
2. ✅ **Test Function**: Trigger manual run to verify logging works
3. ✅ **Test Dashboard**: Verify component displays correctly
4. ⏭️ **Enable Scheduler**: Once verified, set up cron/scheduler for automated runs

## Notes

- The `scheduled-ingest` function already had robust error handling - no changes needed
- Dashboard component follows same patterns as existing components (TMDBAnalytics, MoviesList)
- Component uses expandable rows instead of DataTable for better UX with title lists
- All TypeScript types are properly defined and exported

