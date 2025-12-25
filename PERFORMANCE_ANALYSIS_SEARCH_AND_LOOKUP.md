# Performance Analysis: Movie Search & Lookup

**Date**: 2025-12-24  
**Goal**: Identify latency contributors and optimization opportunities for movie search and detail views

---

## 1. Full Request Lifecycle Trace

### 1.1 User Search Flow

#### **Step 1: User Types Query (Frontend)**
- **Location**: `SearchViewModel.swift` → `search()` method
- **Action**: User types in search field
- **Debounce**: **400ms delay** before search executes (`Task.sleep(nanoseconds: 400_000_000)`)
- **State**: Sets `isSearching = true`, clears previous results
- **Latency**: 400ms artificial delay

#### **Step 2: Frontend → Edge Function (Network)**
- **Location**: `SupabaseService.swift` → `searchMovies()`
- **Endpoint**: `GET /functions/v1/search-movies?q={query}&year_from={from}&year_to={to}&genres={genres}`
- **Headers**: `Authorization: Bearer {anon_key}`
- **Network Latency**: ~50-200ms (browser → Supabase Edge)
- **Cold Start Risk**: Edge Function cold start ~500-2000ms (Deno)

#### **Step 3: Edge Function - Local Database Query**
- **Location**: `supabase/functions/search-movies/index.ts` → Lines 118-225
- **Query**: 
  ```sql
  SELECT tmdb_id, title, year, release_date, 
         works_meta(poster_url_small, poster_url_medium, poster_url_large, overview_short, genres),
         aggregates(ai_score, source_scores)
  FROM works
  WHERE title ILIKE '%{query}%'
  LIMIT 20
  ```
- **Joins**: Left joins to `works_meta` and `aggregates`
- **RLS**: Evaluated for each row (if enabled)
- **Database Latency**: ~20-100ms (indexed query)
- **Index Used**: `idx_works_title` (if exists, otherwise sequential scan)

#### **Step 4: Edge Function - TMDB API Calls (If Needed)**
- **Location**: `supabase/functions/search-movies/index.ts` → Lines 270-400
- **Logic**:
  - If query + filters: Up to **3 pages** of TMDB search (up to 3 API calls)
  - If filters only: 1 TMDB discover call
  - If query only: 1 TMDB search call
- **Rate Limiting**: **100ms delay** between TMDB calls (`setTimeout(resolve, 100)`)
- **TMDB Latency**: ~200-500ms per call
- **Total TMDB Time**: 300-1500ms (1-3 calls × 200-500ms + delays)

#### **Step 5: Deduplication & Merging**
- **Location**: `supabase/functions/search-movies/index.ts` → Lines 400-450
- **Action**: Merge local + TMDB results, dedupe by `tmdb_id` (prefer local)
- **Processing**: In-memory array operations
- **Latency**: ~5-20ms

#### **Step 6: Response Serialization**
- **Location**: Edge Function response
- **Action**: JSON.stringify results array
- **Latency**: ~5-10ms

#### **Step 7: Network Response → Frontend**
- **Network Latency**: ~50-200ms (Supabase Edge → browser)
- **Parsing**: JSON.decode in Swift
- **Latency**: ~5-10ms

#### **Step 8: Frontend Rendering**
- **Location**: `SearchViewModel.swift` → `performSearch()`
- **Action**: Convert `MovieSearchResult` → `Movie`, update `@Published` properties
- **UI Update**: SwiftUI re-renders search results list
- **Latency**: ~10-50ms

**Total Search Latency**: **~1.2-4.5 seconds** (worst case with cold start + 3 TMDB calls)

---

### 1.2 Movie Detail View Flow

#### **Step 1: User Taps Movie**
- **Location**: `MoviePageView.swift` → `init(movieId:)`
- **Action**: Creates `MovieDetailViewModel`, triggers `.task { await viewModel.loadMovie() }`
- **Latency**: Immediate (UI state change)

#### **Step 2: Frontend Cache Check**
- **Location**: `MovieDetailService.swift` → `fetchMovieDetail()`
- **Cache**: `NSCache<NSNumber, MovieDetailWrapper>` (in-memory)
- **Latency**: <1ms if cached
- **Cache Hit Rate**: Unknown (no metrics)

#### **Step 3: Database Cache Check (If Not in Memory)**
- **Location**: `SupabaseService.swift` → `fetchMovieCardFromCache()`
- **Query**: 
  ```sql
  SELECT payload FROM work_cards_cache WHERE work_id = (SELECT work_id FROM works WHERE tmdb_id = ?)
  ```
- **Database Latency**: ~20-50ms (indexed lookup)
- **Index**: `work_cards_cache.work_id` (PRIMARY KEY)

#### **Step 4: Edge Function Call (If Not Cached)**
- **Location**: `supabase/functions/get-movie-card/index.ts`
- **Endpoint**: `GET /functions/v1/get-movie-card?tmdb_id={id}`
- **Network Latency**: ~50-200ms
- **Cold Start**: ~500-2000ms

#### **Step 5: Edge Function - Schema Version Check**
- **Location**: `get-movie-card/index.ts` → Lines 94-132
- **Query**: Check `works_meta.schema_version`
- **If Outdated**: Triggers **synchronous upgrade** via `ingest-movie` (blocks response)
- **Upgrade Latency**: **5-30 seconds** (full TMDB ingestion)
- **Problem**: Blocks user from seeing movie details

#### **Step 6: Edge Function - Certification Check**
- **Location**: `get-movie-card/index.ts` → Lines 141-167
- **Check**: If cached card missing `certification` field
- **If Missing**: Triggers **synchronous refresh** via `ingest-movie` (blocks response)
- **Refresh Latency**: **5-30 seconds**
- **Problem**: Blocks user from seeing movie details

#### **Step 7: Auto-Ingest (If Movie Not in DB)**
- **Location**: `get-movie-card/index.ts` → Lines 62-91
- **Action**: If `works` lookup fails, calls `ingest-movie` synchronously
- **Ingestion Latency**: **5-30 seconds**
- **Problem**: Blocks user from seeing movie details

#### **Step 8: Response → Frontend**
- **Network Latency**: ~50-200ms
- **Parsing**: JSON.decode → `MovieCard` → `MovieDetail`
- **Latency**: ~10-20ms

#### **Step 9: Additional Data Loading (Parallel)**
- **Location**: `MovieDetailViewModel.swift` → `loadMovie()`
- **Actions** (after main movie loads):
  - `loadMovieImages()` - Fetches from TMDB
  - `loadMovieVideos()` - Fetches from TMDB
- **Latency**: ~500-2000ms each (TMDB calls)
- **Note**: These run in parallel, don't block initial render

**Total Detail View Latency**: 
- **Best Case (Cached)**: ~100-300ms
- **Worst Case (Auto-Ingest)**: **5-30 seconds** (blocks UI)

---

## 2. Latency Contributors

### 2.1 Network Latency

| Stage | Latency | Notes |
|-------|---------|-------|
| Browser → Supabase Edge | 50-200ms | Geographic distance dependent |
| Supabase Edge → Database | 5-20ms | Same region, low latency |
| Supabase Edge → TMDB API | 200-500ms | External API, variable |
| Supabase Edge → Browser | 50-200ms | Response payload size dependent |

**Total Network**: ~300-900ms per request

### 2.2 Cold Starts

| Component | Cold Start | Warm Latency | Frequency |
|-----------|------------|--------------|-----------|
| Edge Functions (Deno) | 500-2000ms | 10-50ms | First request after idle period |
| Supabase Database | ~0ms | ~0ms | Connection pooling |
| TMDB API | ~0ms | ~0ms | External service |

**Impact**: First search after idle period adds 500-2000ms

### 2.3 Database Query Cost

#### **Search Query Analysis**
```sql
SELECT works.*, works_meta.*, aggregates.*
FROM works
LEFT JOIN works_meta ON works.work_id = works_meta.work_id
LEFT JOIN aggregates ON works.work_id = aggregates.work_id
WHERE works.title ILIKE '%query%'
LIMIT 20
```

**Indexes**:
- ✅ `idx_works_tmdb_id` - Used for exact lookups
- ✅ `idx_works_title` - **May not support ILIKE efficiently** (text index, not trigram)
- ⚠️ `works_meta.work_id` - PRIMARY KEY (fast join)
- ⚠️ `aggregates.work_id` - Indexed (fast join)

**RLS Policy Cost**:
- If RLS enabled: Evaluated per row (adds ~5-10ms per row)
- Current status: Unknown (needs verification)

**Query Optimization Issues**:
1. **ILIKE '%query%'** - Cannot use index efficiently (leading wildcard)
2. **Multiple LEFT JOINs** - Adds overhead even if data exists
3. **No LIMIT optimization** - May scan more rows than needed

**Estimated Query Time**: 20-100ms (depends on index efficiency)

#### **Movie Card Cache Query**
```sql
SELECT payload FROM work_cards_cache WHERE work_id = ?
```

**Index**: PRIMARY KEY (instant lookup)  
**RLS**: Unknown  
**Estimated Time**: 5-20ms

### 2.4 External API Waits

#### **TMDB API Calls**
- **Search**: 200-500ms per call
- **Discover**: 200-500ms per call
- **Movie Details**: 200-500ms per call
- **Credits**: 200-500ms per call
- **Videos**: 200-500ms per call
- **Images**: 200-500ms per call

**Rate Limiting Delays**:
- Search: **100ms delay** between pages (`setTimeout(resolve, 100)`)
- Ingest: **250ms delay** between calls (`setTimeout(resolve, 250)`)

**Total TMDB Time**:
- Search (3 pages): ~900-1800ms (3 calls × 200-500ms + 2 delays × 100ms)
- Ingest (full): ~2000-5000ms (8 calls × 200-500ms + 7 delays × 250ms)

### 2.5 Artificial Delays

| Location | Delay | Purpose | Impact |
|----------|-------|---------|--------|
| `SearchViewModel.swift:164` | **400ms** | Debounce user input | Blocks search start |
| `search-movies/index.ts:302` | **100ms** | Rate limit protection | Adds latency per page |
| `ingest-movie/index.ts:326-417` | **250ms** | Rate limit protection | Adds 1.75s to ingestion |
| `refresh-worker/index.ts:155` | **1000ms** | Rate limit protection | Adds 1s per refresh |
| `ingest-movie/index.ts:189` | **500ms** | Polling interval | Adds up to 30s wait |

**Total Artificial Delays**: 
- Search: 400ms (debounce) + 100-200ms (rate limits) = **500-600ms**
- Detail View: 0ms (if cached) or **5-30s** (if auto-ingest)

### 2.6 Serialization / Transformation Overhead

| Stage | Operation | Latency |
|-------|-----------|---------|
| Database → JSON | PostgREST serialization | 5-10ms |
| Edge Function → Response | JSON.stringify | 5-10ms |
| Browser → Swift | JSON.decode | 5-10ms |
| Swift Model Conversion | `MovieSearchResult` → `Movie` | 5-20ms |

**Total Serialization**: ~20-50ms

---

## 3. Intentional Buffers & Safety Delays

### 3.1 Rate Limit Protection

#### **TMDB Rate Limits**
- **Limit**: 40 requests per 10 seconds (per API key)
- **Current Protection**:
  - Search: 100ms delay between pages
  - Ingest: 250ms delay between calls
  - Refresh Worker: 1000ms delay between items

**Analysis**:
- ✅ **Necessary**: Prevents 429 errors
- ⚠️ **Could be optimized**: Use exponential backoff only on 429, not preemptively
- 💡 **Recommendation**: Remove preemptive delays, add retry logic with backoff

#### **Debounce (Search)**
- **Location**: `SearchViewModel.swift:164`
- **Delay**: 400ms
- **Purpose**: Prevent excessive API calls while user types

**Analysis**:
- ✅ **Necessary**: Good UX practice
- ⚠️ **Could be reduced**: 200-300ms may be sufficient
- 💡 **Recommendation**: Reduce to 300ms, add immediate local search

### 3.2 Sequential API Calls

#### **Ingest-Movie Function**
- **Location**: `ingest-movie/index.ts:326-417`
- **Pattern**: Sequential TMDB calls with 250ms delays
- **Calls**: details → credits → videos → similar → release_dates → images → keywords → providers

**Analysis**:
- ❌ **Inefficient**: All calls are independent, could be parallelized
- 💡 **Recommendation**: Use `Promise.all()` to parallelize (saves ~1.75s)

#### **Search-Movies Function**
- **Location**: `search-movies/index.ts:275-299`
- **Pattern**: Sequential pagination with 100ms delays
- **Pages**: Fetch up to 3 pages sequentially

**Analysis**:
- ⚠️ **Partially Necessary**: TMDB pagination requires sequential calls
- 💡 **Recommendation**: Keep sequential, but reduce delay to 50ms or remove if no 429s

### 3.3 "Wait for Ingestion" Logic

#### **Duplicate Ingestion Prevention**
- **Location**: `ingest-movie/index.ts:180-249`
- **Logic**: If movie is "ingesting", wait up to 30 seconds for completion
- **Polling**: Check every 500ms

**Analysis**:
- ✅ **Necessary**: Prevents duplicate ingestion
- ❌ **Blocks Read Path**: User can't see movie while another ingestion completes
- 💡 **Recommendation**: Return cached card immediately, trigger background refresh

#### **Schema Version Upgrade**
- **Location**: `get-movie-card/index.ts:105-132`
- **Logic**: If schema outdated, trigger synchronous upgrade

**Analysis**:
- ❌ **Blocks Read Path**: User waits 5-30s for upgrade
- 💡 **Recommendation**: Return cached card, trigger async upgrade

#### **Certification Check**
- **Location**: `get-movie-card/index.ts:141-167`
- **Logic**: If certification missing, trigger synchronous refresh

**Analysis**:
- ❌ **Blocks Read Path**: User waits 5-30s for refresh
- 💡 **Recommendation**: Return cached card, trigger async refresh

---

## 4. Caching Analysis

### 4.1 Frontend Caching

#### **In-Memory Cache (NSCache)**
- **Location**: `MovieDetailService.swift:42-43`
- **Type**: `NSCache<NSNumber, MovieDetailWrapper>`
- **Lifetime**: Until app termination or memory pressure
- **Coverage**: Movie detail views only

**Analysis**:
- ✅ **Good**: Fast access (<1ms)
- ⚠️ **Limited**: Only for detail views, not search results
- 💡 **Recommendation**: Add search result cache (query → results mapping)

#### **MovieCardCache**
- **Location**: `WatchlistView.swift` (referenced)
- **Type**: Unknown implementation
- **Coverage**: Watchlist movies

**Analysis**:
- ✅ **Good**: Instant watchlist loading
- ⚠️ **Unknown**: Implementation details not found
- 💡 **Recommendation**: Document and extend to all movie views

### 4.2 API Response Caching

#### **HTTP Cache Headers**
- **Location**: `get-movie-card/index.ts:218`
- **Header**: `Cache-Control: max-age=3600` (1 hour)
- **ETag**: Included for conditional requests

**Analysis**:
- ✅ **Good**: Browser/CDN caching enabled
- ⚠️ **Limited**: Only for `get-movie-card`, not `search-movies`
- 💡 **Recommendation**: Add cache headers to search endpoint (shorter TTL, e.g., 60s)

#### **Database Cache (work_cards_cache)**
- **Location**: `work_cards_cache` table
- **Type**: Pre-computed JSON payloads
- **Lifetime**: Until refresh/upgrade
- **Coverage**: All movies in database

**Analysis**:
- ✅ **Excellent**: Fast database lookup (5-20ms)
- ✅ **Comprehensive**: Covers all movie data
- ⚠️ **Staleness**: May be outdated if schema changes
- 💡 **Recommendation**: Add TTL or version check

### 4.3 TMDB Response Reuse

**Current State**: 
- ❌ **No caching**: Each TMDB call hits API directly
- ❌ **No reuse**: Same movie fetched multiple times

**Analysis**:
- ❌ **Inefficient**: Wastes API quota and adds latency
- 💡 **Recommendation**: 
  - Cache TMDB responses in database (e.g., `tmdb_cache` table)
  - TTL: 24 hours for movie details, 1 hour for search results
  - Invalidate on refresh

### 4.4 Cache Recommendations

| Cache Type | Location | TTL | Priority |
|------------|----------|-----|----------|
| Search Results | Frontend (NSCache) | 5 minutes | High |
| Search Results | Edge Function (in-memory) | 1 minute | Medium |
| Movie Cards | Database (`work_cards_cache`) | Until refresh | High |
| Movie Cards | Frontend (NSCache) | Until app restart | High |
| TMDB Responses | Database (`tmdb_cache`) | 24 hours | High |
| TMDB Search | Database (`tmdb_cache`) | 1 hour | Medium |

---

## 5. Database Performance Review

### 5.1 Index Coverage

#### **works Table**
- ✅ `idx_works_tmdb_id` - Used for exact lookups
- ✅ `idx_works_title` - **May not support ILIKE efficiently**
- ✅ `idx_works_year` - Used for year filtering
- ⚠️ **Missing**: Trigram index for ILIKE queries (`pg_trgm` extension)

**Recommendation**: Add trigram index for title search:
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_works_title_trgm ON works USING gin(title gin_trgm_ops);
```

#### **works_meta Table**
- ✅ PRIMARY KEY on `work_id` - Fast joins
- ⚠️ **Missing**: Index on `genres` (JSONB) for genre filtering

**Recommendation**: Add GIN index for genres:
```sql
CREATE INDEX IF NOT EXISTS idx_works_meta_genres ON works_meta USING gin(genres);
```

#### **work_cards_cache Table**
- ✅ PRIMARY KEY on `work_id` - Instant lookups
- ✅ **Good**: No additional indexes needed

### 5.2 Sequential Scans

**Potential Issues**:
1. **Title ILIKE '%query%'** - May cause sequential scan without trigram index
2. **Genre filtering** - May scan all rows if no GIN index

**Recommendation**: Add indexes above, verify with `EXPLAIN ANALYZE`

### 5.3 RLS Policy Cost

**Current Status**: Unknown (needs verification)

**Recommendation**: 
- Check if RLS enabled: `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';`
- If enabled, verify policies are efficient (use indexes)
- Consider disabling RLS for read-only tables if not needed

### 5.4 Query Over-Fetching

#### **Search Query**
```sql
SELECT works.*, works_meta.*, aggregates.*
```

**Analysis**:
- ⚠️ **Over-fetches**: Gets all columns, but only needs subset
- 💡 **Recommendation**: Select only needed columns:
  ```sql
  SELECT works.tmdb_id, works.title, works.year,
         works_meta.poster_url_medium, works_meta.overview_short,
         aggregates.ai_score
  ```

#### **Movie Card Query**
```sql
SELECT payload FROM work_cards_cache WHERE work_id = ?
```

**Analysis**:
- ✅ **Efficient**: Only fetches needed column

### 5.5 Join Optimization

**Current Joins**:
- `works` LEFT JOIN `works_meta` - Fast (PRIMARY KEY)
- `works` LEFT JOIN `aggregates` - Fast (indexed)

**Analysis**:
- ✅ **Efficient**: Joins are well-indexed
- ⚠️ **Could be deferred**: If using `work_cards_cache`, joins unnecessary

**Recommendation**: Use `work_cards_cache` for search results (pre-computed, no joins)

---

## 6. UI / UX Blocking Analysis

### 6.1 Search View

#### **What Blocks Rendering**:
- ❌ **Everything**: Search results only render after API response
- ❌ **Loading State**: Shows spinner, no skeleton

#### **What Could Render Immediately**:
- ✅ **Search Input**: Already renders
- 💡 **Skeleton Results**: Show placeholder cards while loading
- 💡 **Local Results First**: Show cached results immediately, update with fresh data

#### **Progressive Loading**:
- 💡 **Posters**: Load asynchronously after results render
- 💡 **Scores**: Load asynchronously (show placeholder)

### 6.2 Movie Detail View

#### **What Blocks Rendering**:
- ❌ **Everything**: Shows loading spinner until movie loads
- ❌ **Auto-Ingest**: Blocks for 5-30s if movie not in DB

#### **What Could Render Immediately**:
- 💡 **Basic Info**: Title, year, poster (if cached)
- 💡 **Skeleton UI**: Show structure while loading
- 💡 **Cached Data**: Show stale data immediately, refresh in background

#### **Progressive Loading**:
- ✅ **Images**: Already loads asynchronously
- ✅ **Videos**: Already loads asynchronously
- 💡 **Cast/Crew**: Could load progressively
- 💡 **Similar Movies**: Already disabled (good)

---

## 7. Concrete Speed-Up Recommendations

### 7.1 Quick Wins (Low Risk, High Impact)

#### **1. Reduce Debounce Delay**
- **Change**: 400ms → 300ms
- **Impact**: Saves 100ms per search
- **Risk**: Low (still prevents excessive calls)
- **Effort**: 1 line change

#### **2. Add Search Result Cache (Frontend)**
- **Change**: Cache query → results mapping in NSCache
- **Impact**: Instant results for repeated queries
- **Risk**: Low (cache invalidation on new search)
- **Effort**: ~50 lines

#### **3. Return Cached Card During Ingestion**
- **Change**: `get-movie-card` returns cached card immediately, triggers async refresh
- **Impact**: Saves 5-30s on detail view load
- **Risk**: Low (shows stale data briefly)
- **Effort**: ~30 lines

#### **4. Parallelize TMDB Calls in Ingest**
- **Change**: Use `Promise.all()` for independent TMDB calls
- **Impact**: Saves ~1.75s on ingestion
- **Risk**: Low (same data, just faster)
- **Effort**: ~20 lines

#### **5. Add Cache Headers to Search Endpoint**
- **Change**: `Cache-Control: max-age=60` on search responses
- **Impact**: Browser/CDN caching for repeated queries
- **Risk**: Low (short TTL)
- **Effort**: 1 line

**Total Quick Win Impact**: **~2-30s saved** (depending on scenario)

### 7.2 Medium Effort Improvements

#### **6. Add Trigram Index for Title Search**
- **Change**: Create `pg_trgm` index on `works.title`
- **Impact**: 10-50x faster ILIKE queries
- **Risk**: Low (index creation, no data changes)
- **Effort**: 1 migration

#### **7. Use work_cards_cache for Search Results**
- **Change**: Query `work_cards_cache` instead of joining `works` + `works_meta` + `aggregates`
- **Impact**: Eliminates joins, faster queries
- **Risk**: Medium (ensures cache is populated)
- **Effort**: ~100 lines

#### **8. Add TMDB Response Caching**
- **Change**: Cache TMDB API responses in database
- **Impact**: Eliminates redundant TMDB calls
- **Risk**: Medium (cache invalidation logic)
- **Effort**: ~200 lines

#### **9. Remove Preemptive Rate Limit Delays**
- **Change**: Remove delays, add retry logic with exponential backoff
- **Impact**: Saves 100-250ms per call
- **Risk**: Medium (may hit rate limits)
- **Effort**: ~50 lines

#### **10. Add Skeleton UI**
- **Change**: Show placeholder cards while loading
- **Impact**: Better perceived performance
- **Risk**: Low (UI only)
- **Effort**: ~100 lines

**Total Medium Effort Impact**: **~500ms-2s saved** + better UX

### 7.3 Architectural Changes (Only If Needed)

#### **11. Edge Function Warm-Up**
- **Change**: Keep Edge Functions warm with periodic pings
- **Impact**: Eliminates cold starts
- **Risk**: Low (cost consideration)
- **Effort**: Cron job or external service

#### **12. CDN for Static Assets**
- **Change**: Serve posters/images via CDN
- **Impact**: Faster image loading
- **Risk**: Low (infrastructure change)
- **Effort**: Configuration

#### **13. Database Read Replicas**
- **Change**: Use read replicas for search queries
- **Impact**: Reduces load on primary DB
- **Risk**: Medium (consistency considerations)
- **Effort**: Infrastructure setup

**Total Architectural Impact**: **~500ms-2s saved** (cold starts + network)

---

## 8. Monitoring & Verification

### 8.1 Current Latency Measurement

#### **Existing Logs**:
- ✅ Edge Function logs: `console.log()` with timestamps
- ✅ TMDB API logs: `tmdb_api_logs` table
- ⚠️ **Missing**: End-to-end timing, frontend timing

#### **Recommendations**:

**1. Add Timing Headers to Edge Functions**
```typescript
const startTime = Date.now();
// ... processing ...
const duration = Date.now() - startTime;
return new Response(JSON.stringify(data), {
  headers: {
    'X-Response-Time': `${duration}ms`,
    'X-Database-Time': `${dbTime}ms`,
    'X-TMDB-Time': `${tmdbTime}ms`,
  }
});
```

**2. Add Frontend Timing**
```swift
let startTime = Date()
let results = try await searchMovies(query: query)
let duration = Date().timeIntervalSince(startTime)
print("Search took \(duration * 1000)ms")
```

**3. Add Dashboard Metrics**
- Create `search_performance_log` table:
  ```sql
  CREATE TABLE search_performance_log (
    id BIGSERIAL PRIMARY KEY,
    query TEXT,
    result_count INT,
    total_time_ms INT,
    db_time_ms INT,
    tmdb_time_ms INT,
    cache_hit BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT now()
  );
  ```

### 8.2 Dashboard Visibility

**Add to Existing Dashboard**:
- **New Tab**: "Performance Metrics"
- **Show**:
  - Average search latency (p50, p95, p99)
  - Average detail view latency
  - Cache hit rates
  - TMDB API call counts
  - Cold start frequency

**Implementation**:
- Query `search_performance_log` table
- Show charts (time series, histograms)
- Add filters (date range, query type)

### 8.3 Verification Plan

**Before Optimization**:
1. Measure baseline: Average search latency, detail view latency
2. Identify bottlenecks: Which stage takes longest?
3. Set targets: e.g., "Search < 500ms, Detail < 200ms"

**After Optimization**:
1. Re-measure: Compare to baseline
2. Verify improvements: Check each optimization's impact
3. Monitor regressions: Watch for new bottlenecks

**Tools**:
- Supabase Dashboard: Edge Function logs, database query times
- Browser DevTools: Network tab, Performance tab
- Custom Dashboard: Performance metrics table

---

## Summary: Priority Actions

### **Immediate (This Week)**
1. ✅ Reduce debounce: 400ms → 300ms
2. ✅ Return cached card during ingestion (don't block)
3. ✅ Parallelize TMDB calls in ingest
4. ✅ Add cache headers to search endpoint

### **Short Term (This Month)**
5. ✅ Add trigram index for title search
6. ✅ Add search result cache (frontend)
7. ✅ Add skeleton UI
8. ✅ Remove preemptive rate limit delays

### **Medium Term (Next Quarter)**
9. ✅ Use `work_cards_cache` for search results
10. ✅ Add TMDB response caching
11. ✅ Add performance monitoring dashboard

### **Expected Impact**
- **Search Latency**: 1.2-4.5s → **300-800ms** (60-80% improvement)
- **Detail View Latency**: 5-30s → **100-300ms** (95-99% improvement)
- **Perceived Performance**: Much better (skeleton UI, progressive loading)

---

**Next Steps**: Review recommendations, prioritize based on effort/impact, implement incrementally with monitoring.

