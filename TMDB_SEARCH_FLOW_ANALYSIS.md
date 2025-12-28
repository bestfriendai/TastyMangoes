# TMDB Search Flow Analysis: "Lord of the Rings"

## What Happens During a Voice Search

### 1. Voice Input → Intent Recognition
- User says: "Lord of the Rings"
- `VoiceIntentRouter` processes transcript
- Intent classified as: **direct** (movie search)
- Confidence: ~85-90%

### 2. HintSearchCoordinator Flow

#### Phase 1: Local Search (via `search-movies` Edge Function)
- **Edge Function**: `search-movies`
- **Local Database Query**: Searches `works` table with `ILIKE '%Lord of the Rings%'`
- **TMDB API Call**: `/search/movie?query=Lord%20of%20the%20Rings&page=1`
  - **Endpoint**: `/search/movie`
  - **Method**: GET
  - **Results**: ~20 movies (Fellowship, Two Towers, Return of the King, animated version, etc.)
  - **Response Time**: ~200-500ms
  - **Response Size**: ~10-20 KB

**Total TMDB Calls in Phase 1: 1**

#### Phase 2: AI Discovery (if needed)
- If local search returns < 5 results OR user query is ambiguous
- **Service**: `AIDiscoveryService` (OpenAI GPT-4o-mini)
- **AI Response**: Suggests 4-25 movies with TMDB IDs
- **Note**: AI does NOT call TMDB directly - it uses its training data

**Total TMDB Calls in Phase 2: 0** (AI doesn't call TMDB)

#### Phase 3: Verification & Ingestion
- For each AI-suggested movie NOT in local database:
  - **Verification Call**: `/search/movie?query={title}&year={year}`
    - Verifies AI's TMDB ID is correct
    - Often finds different ID (AI IDs are frequently wrong)
  - **Ingestion**: If verified, calls `ingest-movie` edge function
    - This makes **8-10 TMDB API calls per movie**:
      1. `/movie/{id}` - Movie details
      2. `/movie/{id}/credits` - Cast & crew
      3. `/movie/{id}/videos` - Trailers
      4. `/movie/{id}/similar` - Similar movies
      5. `/movie/{id}/release_dates` - Release dates
      6. `/movie/{id}/images` - Images
      7. `/movie/{id}/keywords` - Keywords
      8. `/movie/{id}/watch/providers` - Streaming providers

**Total TMDB Calls in Phase 3**: 
- Verification: ~1 call per AI-suggested movie (if not in local DB)
- Ingestion: ~8-10 calls per new movie ingested

### Example: "Lord of the Rings" Search

**Scenario**: User searches "Lord of the Rings", local DB has 3 movies, AI suggests 4 more

1. **Local Search**: 1 TMDB call (`/search/movie`)
2. **AI Discovery**: 0 TMDB calls (AI uses training data)
3. **Verification**: 4 TMDB calls (one per AI suggestion)
4. **Ingestion**: 3 new movies × 8 calls = 24 TMDB calls

**Total: ~29 TMDB API calls**

## Data Returned

### From `/search/movie`:
```json
{
  "page": 1,
  "results": [
    {
      "id": 120,
      "title": "The Lord of the Rings: The Fellowship of the Ring",
      "release_date": "2001-12-19",
      "poster_path": "/6oom5QYQ2yQTMJIbnvbkBL9cHo6.jpg",
      "overview": "...",
      "vote_average": 8.4,
      "vote_count": 25000,
      "genre_ids": [12, 14, 28]
    }
  ],
  "total_pages": 5,
  "total_results": 100
}
```

### From `/movie/{id}` (during ingestion):
- Full movie details (title, overview, runtime, budget, revenue, etc.)
- Genres, production companies, countries
- Release dates, certifications

### From `/movie/{id}/credits`:
- Cast list (actors, characters)
- Crew list (directors, writers, etc.)

### From `/movie/{id}/watch/providers`:
- Streaming providers (Netflix, Amazon Prime, etc.)
- Rental/purchase options
- Free/ad-supported options

## Data Saved

### To `works` table:
- Basic movie info (tmdb_id, title, year, release_date)
- Overview, runtime, genres
- Budget, revenue
- TMDB ratings

### To `works_meta` table:
- Poster URLs (small, medium, large, original)
- Backdrop URLs
- Overview (short and full)
- Genres array

### To `works_cast` table:
- Cast members (actors, characters)
- Crew members (directors, writers, etc.)

### To `works_ratings` table:
- TMDB score and vote count
- Source: "TMDB"

### To `works_similar` table:
- Similar movies (TMDB recommendations)

### To `works_watch_providers` table:
- Streaming providers
- Rental/purchase options

### To `tmdb_api_logs` table (NEW):
- Every TMDB API call
- Endpoint, method, status code
- Query parameters
- Response time, size
- Edge function that made the call
- User query that triggered it
- Voice event ID (if from voice search)

## TMDB API Endpoints Used

1. **`/search/movie`** - Text search (most common)
2. **`/discover/movie`** - Filter-based discovery (year, genres)
3. **`/movie/{id}`** - Movie details
4. **`/movie/{id}/credits`** - Cast & crew
5. **`/movie/{id}/videos`** - Trailers/clips
6. **`/movie/{id}/similar`** - Similar movies
7. **`/movie/{id}/release_dates`** - Release dates & certifications
8. **`/movie/{id}/images`** - Posters & backdrops
9. **`/movie/{id}/keywords`** - Keywords/tags
10. **`/movie/{id}/watch/providers`** - Streaming providers

## Rate Limits

TMDB API rate limits:
- **40 requests per 10 seconds** (per API key)
- Our edge functions add 250ms delays between calls during ingestion
- Search calls are typically fast (< 500ms)
- Ingestion calls can take 2-5 seconds per movie (8-10 calls with delays)
