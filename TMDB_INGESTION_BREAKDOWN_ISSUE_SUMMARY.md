# TMDB Movie Ingestion Breakdown Dashboard Issue - Detailed Summary

## What We Want

The user wants to see a **"Movie Ingestion API Call Breakdown"** table in the TMDB Stats v4 dashboard that displays:

- **Per-movie breakdown** of the 8-10 TMDB API calls made during each movie ingestion
- **Columns showing counts** for each API call type:
  - Details (`/movie/{id}`)
  - Credits (`/movie/{id}/credits`)
  - Videos (`/movie/{id}/videos`)
  - Similar (`/movie/{id}/similar`)
  - Release Dates (`/movie/{id}/release_dates`)
  - Images (`/movie/{id}/images`)
  - Keywords (`/movie/{id}/keywords`)
  - Watch Providers (`/movie/{id}/watch/providers`)
  - Other endpoints
- **Additional metrics**: Total calls per movie, average response time, errors, last call timestamp
- **Data source**: Should include ALL movies ingested (scheduled ingestion, manual ingestion, voice search ingestion, etc.)

## Current State

### Dashboard Display
- **Location**: TMDB Stats v4 → "TMDB API Call Analytics v4" section
- **Current Status**: The "Movie Ingestion API Call Breakdown" section shows:
  - Message: "No movie ingestion data found. Try adjusting the time range filter or ensure movies have been ingested recently."
  - The table is empty (no rows displayed)

### Console Logs
The browser console shows debug logs indicating the filtering logic is running but finding zero matches:
- `🔍 [Movie Ingestion Breakdown] Total logs: 33` (or similar number)
- `🔍 [Movie Ingestion Breakdown] Logs with movie endpoints: 0` ⚠️ **This is the problem**
- `🔍 [Movie Ingestion Breakdown] Grouped into 0 movies` ⚠️ **No movies grouped**

### Data Available
- **Total API Calls**: 33 (visible in dashboard stats)
- **Endpoints**: 4 unique endpoints found
- **Edge Functions**: 2 edge functions found
- **Time Range**: Set to "Last 7 Days"
- **Recent API Calls Table**: Shows individual API logs, but the breakdown table is empty

## What Has Been Tried

### Attempt 1: Regex Pattern Fix
**Problem Identified**: The regex pattern `/\/movie\/\d+/` was not matching endpoints with the `/3/` API version prefix.

**Fix Applied**: Updated three regex patterns in `TMDBAPIAnalytics.tsx`:

1. **Line ~249** - Movie endpoint filter:
   ```typescript
   // BEFORE:
   return endpoint.match(/\/movie\/\d+/) // Any endpoint with /movie/{id}
   
   // AFTER:
   return endpoint.match(/(\/3)?\/movie\/\d+/) // Matches both /movie/{id} and /3/movie/{id}
   ```

2. **Line ~269** - TMDB ID extraction:
   ```typescript
   // BEFORE:
   const match = endpoint.match(/\/movie\/(\d+)/)
   if (match) {
     tmdbId = match[1]
   }
   
   // AFTER:
   const match = endpoint.match(/(\/3)?\/movie\/(\d+)/)
   if (match) {
     tmdbId = match[2] // Changed to match[2] because /3/ is now capture group 1
   }
   ```

3. **Line ~280** - isMovieIngestionCall check:
   ```typescript
   // BEFORE:
   endpoint.match(/\/movie\/\d+/) &&
   
   // AFTER:
   endpoint.match(/(\/3)?\/movie\/\d+/) &&
   ```

**Result**: Changes were applied successfully, but the issue persists. Console still shows `Logs with movie endpoints: 0`.

### Attempt 2: Debug Logging
Added extensive console logging to diagnose the issue:
- Logs total number of logs fetched
- Logs all unique endpoints found
- Logs sample of first 5 logs
- Logs count of logs matching movie endpoint pattern
- Logs sample movie endpoints (if any found)
- Logs number of movies grouped

**Result**: Logs show that the filtering is running but finding zero matches, suggesting either:
- The endpoint format in the database is different than expected
- The filtering logic has additional issues beyond the regex pattern
- The data doesn't exist in the expected format

## Potential Root Causes

### 1. Endpoint Format Mismatch
**Hypothesis**: The actual endpoint format in the `tmdb_api_logs` table might be different than expected.

**Possible Formats**:
- `/3/movie/12345` (with `/3/` prefix) ✅ Should now match with our fix
- `/movie/12345` (without prefix) ✅ Should match
- `/api/v3/movie/12345` (full API path) ❌ Won't match
- `movie/12345` (missing leading slash) ❌ Won't match
- `https://api.themoviedb.org/3/movie/12345` (full URL) ❌ Won't match

**How to Verify**:
- Check the console log: `🔍 [Movie Ingestion Breakdown] All unique endpoints: [...]`
- Expand that log entry to see the actual endpoint formats
- Compare with what the regex expects

### 2. Data Doesn't Exist in Time Range
**Hypothesis**: No movies were actually ingested within the "Last 7 Days" time range, or the ingestion calls weren't logged.

**Possible Reasons**:
- Movies were ingested more than 7 days ago
- The `tmdb_api_logs` table wasn't logging calls when movies were ingested
- The logging system wasn't set up when movies were ingested
- Edge functions aren't properly logging API calls

**How to Verify**:
- Check the "Recent API Calls" table - are there any calls with endpoints containing `/movie/` and a numeric ID?
- Check if any calls have `edge_function: 'ingest-movie'`
- Expand the time range to "Last 30 Days" to see if data appears
- Check the database directly: `SELECT endpoint, edge_function, created_at FROM tmdb_api_logs WHERE endpoint LIKE '%/movie/%' ORDER BY created_at DESC LIMIT 20;`

### 3. Filtering Logic Too Restrictive
**Hypothesis**: The `isMovieIngestionCall` condition might be excluding valid ingestion calls.

**Current Logic**:
```typescript
const isMovieIngestionCall = tmdbId && 
  endpoint.match(/(\/3)?\/movie\/\d+/) && 
  !endpoint.includes('/search') && 
  !endpoint.includes('/discover') &&
  !endpoint.includes('/trending') &&
  !endpoint.includes('/popular') &&
  !endpoint.includes('/now_playing')
```

**Potential Issues**:
- The `tmdbId` might be null/undefined even when the endpoint contains a movie ID
- The exclusion list might be too broad (e.g., if an endpoint contains both `/movie/12345` and `/search` in the path)
- The `tmdbId` extraction might be failing silently

**How to Verify**:
- Check console logs for "Sample of first 5 logs" - look at the `tmdb_id` field
- Check if endpoints in the database have `tmdb_id` populated
- Verify the `tmdbId` extraction logic is working correctly

### 4. Edge Function Context Missing
**Hypothesis**: The `tmdb_id` field might not be populated in the logs, and the extraction from endpoint is failing.

**Current Extraction Logic**:
```typescript
let tmdbId = log.tmdb_id

// If no tmdb_id but endpoint contains a movie ID, extract it
if (!tmdbId && endpoint) {
  const match = endpoint.match(/(\/3)?\/movie\/(\d+)/)
  if (match) {
    tmdbId = match[2]
  }
}
```

**Potential Issues**:
- The regex might not be matching (already fixed, but verify)
- The `match[2]` might be incorrect if the regex groups are wrong
- The endpoint might have a different structure (e.g., query parameters, fragments)

**How to Verify**:
- Add more detailed logging around the `tmdbId` extraction
- Log the actual `match` result to see what groups are captured
- Check if `log.tmdb_id` is populated in the database

### 5. Database Schema/Data Issues
**Hypothesis**: The `tmdb_api_logs` table might not have the expected data structure or the data might be malformed.

**Potential Issues**:
- The `endpoint` column might store full URLs instead of paths
- The `tmdb_id` column might not be populated by the logging function
- The `edge_function` column might have different values than expected
- The data might be stored in a different format (e.g., JSON in a different column)

**How to Verify**:
- Query the database directly: `SELECT endpoint, tmdb_id, edge_function, created_at FROM tmdb_api_logs ORDER BY created_at DESC LIMIT 10;`
- Check the actual data format in the database
- Verify the logging function (`logTMDBCall`) is populating fields correctly

### 6. Normalization Function Interference
**Hypothesis**: The `normalizeEndpoint` function might be interfering with the filtering logic.

**Current Normalization**:
```typescript
function normalizeEndpoint(endpoint: string): string {
  if (!endpoint) return endpoint
  return endpoint.replace(/(\/3)?\/movie\/(\d+)/g, '/movie/{id}')
}
```

**Potential Issues**:
- The normalization happens AFTER filtering, so it shouldn't affect the initial filter
- However, if endpoints are normalized before being stored in the database, the filtering regex won't match
- The normalization might be applied inconsistently

**How to Verify**:
- Check if endpoints in the database are already normalized (contain `{id}` instead of actual IDs)
- Verify the normalization is only used for display/grouping, not for filtering

### 7. Time Range Filter Issue
**Hypothesis**: The time range filter might be excluding the relevant data.

**Current Filter**:
```typescript
switch (timeRange) {
  case "24h":
    startDate = subDays(now, 1)
    break
  case "7d":
    startDate = subDays(now, 7)
    break
  case "30d":
    startDate = subDays(now, 30)
    break
}
```

**Potential Issues**:
- The `startDate` calculation might be incorrect
- The timezone might be causing issues
- The `gte` filter might be excluding data at the boundary

**How to Verify**:
- Check the actual `startDate` value being used in the query
- Verify the timezone handling
- Try removing the time range filter temporarily to see if data appears

### 8. Component Not Re-rendering
**Hypothesis**: The component might not be re-rendering after the code changes, or there's a caching issue.

**Potential Issues**:
- Browser cache showing old JavaScript
- Hot reload not working properly
- Build process not picking up changes
- Component state not updating after data fetch

**How to Verify**:
- Hard refresh the browser (Cmd+Shift+R or Ctrl+Shift+R)
- Check the browser's Network tab to see if new JavaScript is being loaded
- Verify the changes are actually in the compiled code
- Check if the component is re-fetching data after changes

## Recommended Next Steps for Debugging

### Step 1: Verify Endpoint Format
1. Open browser console
2. Find the log: `🔍 [Movie Ingestion Breakdown] All unique endpoints: [...]`
3. Expand it to see the actual endpoint formats
4. Compare with what the regex expects

### Step 2: Check Database Directly
Run this SQL query in Supabase SQL Editor:
```sql
SELECT 
  endpoint,
  tmdb_id,
  edge_function,
  created_at,
  http_status
FROM tmdb_api_logs 
WHERE endpoint LIKE '%/movie/%' 
  OR endpoint LIKE '%movie/%'
ORDER BY created_at DESC 
LIMIT 20;
```

This will show:
- The actual endpoint format in the database
- Whether `tmdb_id` is populated
- Which edge functions are making movie-related calls
- When the calls were made

### Step 3: Add More Detailed Logging
Add logging to see exactly what's happening:

```typescript
// After fetching logs
console.log('🔍 [DEBUG] Sample endpoints:', allLogs.slice(0, 10).map(l => ({
  endpoint: l.endpoint,
  tmdb_id: l.tmdb_id,
  edge_function: l.edge_function,
  matches_regex: l.endpoint?.match(/(\/3)?\/movie\/\d+/) ? 'YES' : 'NO'
})))

// In the tmdbId extraction
console.log('🔍 [DEBUG] Extracting tmdbId:', {
  original_tmdb_id: log.tmdb_id,
  endpoint: endpoint,
  match_result: endpoint.match(/(\/3)?\/movie\/(\d+)/),
  extracted_tmdb_id: match ? match[2] : null
})

// In isMovieIngestionCall
console.log('🔍 [DEBUG] isMovieIngestionCall check:', {
  tmdbId: tmdbId,
  endpoint: endpoint,
  matches_regex: endpoint.match(/(\/3)?\/movie\/\d+/),
  excludes_search: !endpoint.includes('/search'),
  result: isMovieIngestionCall
})
```

### Step 4: Test with Known Data
1. Manually ingest a movie (or trigger scheduled ingestion)
2. Watch the console logs in real-time
3. Verify that the ingestion calls are being logged
4. Check if they match the filtering criteria

### Step 5: Simplify the Filter Temporarily
Temporarily simplify the filter to see if ANY movie endpoints are found:

```typescript
// Simplified version - just check if endpoint contains /movie/ and a number
const movieEndpointLogs = allLogs.filter(log => {
  const endpoint = log.endpoint || ''
  return endpoint.includes('/movie/') && /\d+/.test(endpoint)
})
```

If this finds logs but the original doesn't, the regex is still the issue.

## Files Modified

- **File**: `/Users/timrobinson/Developer/mango-dashboard/src/components/TMDBAPIAnalytics.tsx`
- **Changes**: Updated three regex patterns to handle `/3/` prefix
- **Lines Modified**: ~249, ~269, ~280

## Related Files to Check

1. **Logging Function**: `supabase/functions/_shared/tmdb.ts`
   - Check how `logTMDBCall` formats the endpoint
   - Verify it's extracting and storing `tmdb_id` correctly

2. **Ingestion Function**: `supabase/functions/ingest-movie/index.ts`
   - Verify it's calling `logTMDBCall` with correct context
   - Check that `tmdbId` is being passed in the context

3. **Database Schema**: `supabase/migrations/011_add_tmdb_api_logs.sql`
   - Verify the `endpoint` column type and constraints
   - Check if there are any triggers or defaults affecting the data

## Expected Behavior After Fix

Once the issue is resolved, the console should show:
- `🔍 [Movie Ingestion Breakdown] Logs with movie endpoints: X` where X > 0
- `🔍 [Movie Ingestion Breakdown] Grouped into X movies` where X > 0
- The breakdown table should display rows with:
  - TMDB ID
  - Total Calls (8-10 per movie)
  - Individual endpoint counts (Details, Credits, Videos, etc.)
  - Average response time
  - Error count
  - Last call timestamp

## Additional Context

- **Dashboard**: Next.js/React application
- **Database**: Supabase (PostgreSQL)
- **Edge Functions**: Deno/TypeScript
- **Logging**: All TMDB API calls are logged to `tmdb_api_logs` table
- **Component**: `TMDBAPIAnalytics.tsx` (v4) - comprehensive analytics component with charts and breakdowns

## Questions to Answer

1. What is the actual format of endpoints in the `tmdb_api_logs` table?
2. Are the `tmdb_id` fields populated in the logs?
3. When were movies last ingested? (to verify time range)
4. Is the logging function (`logTMDBCall`) being called correctly during ingestion?
5. Are there any errors in the browser console or network tab?
6. Is the component re-rendering after code changes?

---

**Created**: 2025-12-22
**Last Updated**: 2025-12-22
**Status**: Issue persists after regex pattern fixes
