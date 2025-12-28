# How to Check Supabase Edge Function Logs

## Method 1: Supabase Dashboard (Easiest)

1. **Go to your Supabase Dashboard:**
   - URL: https://app.supabase.com/project/zyywpjddzvkqvjosifiy
   - Or navigate to: https://app.supabase.com → Select your project

2. **Navigate to Edge Functions:**
   - Click "Edge Functions" in the left sidebar
   - You'll see a list of all your functions

3. **View Logs:**
   - Click on a function (e.g., `ingest-movie` or `search-movies`)
   - Click the "Logs" tab
   - You'll see real-time logs from that function

4. **Filter Logs:**
   - Use the search box to filter by `[TMDB]` to see only TMDB logging messages
   - Or filter by `error` to see any errors

## Method 2: Supabase CLI (More Detailed)

### Install Supabase CLI (if not already installed):
```bash
npm install -g supabase
```

### Login to Supabase:
```bash
supabase login
```

### Link your project:
```bash
supabase link --project-ref zyywpjddzvkqvjosifiy
```

### View logs for a specific function:
```bash
# View logs for ingest-movie
supabase functions logs ingest-movie

# View logs for search-movies
supabase functions logs search-movies

# View logs with follow (real-time updates)
supabase functions logs ingest-movie --follow

# View logs with filter for TMDB messages
supabase functions logs ingest-movie | grep "\[TMDB\]"
```

### View all function logs:
```bash
supabase functions logs
```

## What to Look For

### ✅ Success Indicators:
- `[TMDB] Attempting to log API call:` - Logging function is being called
- `[TMDB] Successfully logged API call. ID: X` - Log was inserted successfully
- `[TMDB] Inserting log data:` - Shows the data being inserted

### ❌ Error Indicators:
- `[TMDB] Failed to insert log:` - Insert failed, check error details
- `[TMDB] Error code:` - Database error code
- `[TMDB] Error message:` - Error description
- `[TMDB] Missing environment variables:` - SERVICE_ROLE_KEY not set
- `[TMDB] Supabase client is null` - Client initialization failed
- `[TMDB] Exception while logging API call:` - Unexpected error

## Common Issues and Fixes

### Issue 1: "Missing SUPABASE_URL or SERVICE_ROLE_KEY"
**Fix:** Go to Supabase Dashboard → Project Settings → Edge Functions → Secrets
- Verify `SERVICE_ROLE_KEY` is set (it should be auto-set)
- If missing, add it manually from Settings → API → service_role key

### Issue 2: "Failed to insert log" with RLS error
**Fix:** The RLS policy might be blocking inserts. Check:
- Go to Database → Tables → `tmdb_api_logs`
- Check RLS policies allow service role to insert

### Issue 3: No logs appearing at all
**Possible causes:**
- Edge functions haven't been deployed with latest code
- Functions aren't being called
- Logging code isn't executing

**Fix:** 
- Redeploy edge functions: `supabase functions deploy ingest-movie`
- Check that functions are actually being called (look for other log messages)

## Testing Logging

1. **Trigger a voice search** in your iOS app (e.g., "Boston Strangler")
2. **Watch the logs** in real-time:
   ```bash
   supabase functions logs ingest-movie --follow | grep "\[TMDB\]"
   ```
3. **Check for these specific log entries:**
   - `[INGEST] Starting ingestion for TMDB ID: X`
   - `[TMDB] Attempting to log API call:` (should appear multiple times)
   - `[TMDB] Successfully logged API call. ID: X` (for each API call)

## Quick Debug Commands

```bash
# View last 50 log entries for ingest-movie
supabase functions logs ingest-movie --limit 50

# View logs from last hour
supabase functions logs ingest-movie --since 1h

# View logs and filter for errors only
supabase functions logs ingest-movie | grep -i error

# View logs and filter for TMDB logging
supabase functions logs ingest-movie | grep "\[TMDB\]"

# View logs for all functions
supabase functions logs --all
```
