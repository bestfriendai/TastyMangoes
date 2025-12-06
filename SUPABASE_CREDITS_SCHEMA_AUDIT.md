# Supabase Movie Credits Schema Audit

**Date:** 2025-12-06  
**Mission:** SUPA-CREDITS-01  
**Status:** Complete - Read-only inspection

---

## Summary

Movie credits (cast and crew) are stored in the `works_meta` table as JSONB arrays. There are no separate normalized tables for cast, crew, or people. All credit information is embedded within the movie metadata record.

---

## Relevant Tables

### `works` table

**Purpose:** Master index of all movies (minimal fields, canonical source of truth)

**Columns:**
- `work_id` (BIGSERIAL PRIMARY KEY) - Internal movie ID
- `tmdb_id` (TEXT UNIQUE NOT NULL) - The Movie Database ID
- `imdb_id` (TEXT UNIQUE) - Internet Movie Database ID
- `title` (TEXT NOT NULL) - Movie title
- `original_title` (TEXT) - Original language title
- `year` (INT) - Release year
- `release_date` (DATE) - Release date
- `last_refreshed_at` (TIMESTAMPTZ) - Staleness tracking
- `request_count` (INT) - Request counter
- `created_at` (TIMESTAMPTZ) - Record creation timestamp
- `updated_at` (TIMESTAMPTZ) - Record update timestamp

**Credits Relevance:** This table links to `works_meta` via `work_id`. No direct credits data stored here.

---

### `works_meta` table

**Purpose:** Rich metadata, cast, crew, and assets for each movie (one-to-one with `works`)

**Columns:**
- `work_id` (BIGINT PRIMARY KEY) - References `works(work_id)`
- `runtime_minutes` (INT) - Runtime in minutes
- `runtime_display` (TEXT) - Pre-formatted runtime (e.g., "2h 12m")
- `tagline` (TEXT) - Movie tagline
- `overview` (TEXT) - Full description
- `overview_short` (TEXT) - 1-2 sentence version
- `keywords` (TEXT[]) - Array of keywords
- `genres` (TEXT[]) - Array of genres (e.g., ['Drama', 'Thriller'])
- `subgenres` (TEXT[]) - Array of subgenres
- `moods` (TEXT[]) - Array of moods
- `themes` (TEXT[]) - Array of themes
- `certification` (TEXT) - MPAA rating (e.g., 'R', 'PG-13')
- `certification_reason` (TEXT) - Reason for certification
- `content_warnings` (TEXT[]) - Array of content warnings
- `poster_url_small` (TEXT) - Poster image URL (~154px)
- `poster_url_medium` (TEXT) - Poster image URL (~342px)
- `poster_url_large` (TEXT) - Poster image URL (~500px)
- `poster_url_original` (TEXT) - Original poster URL
- `backdrop_url` (TEXT) - Backdrop image URL
- `backdrop_url_mobile` (TEXT) - Mobile backdrop URL
- `logo_url` (TEXT) - Movie logo URL
- `still_images` (JSONB) - Array of still image objects
- **`cast_members` (JSONB)** - **Array of cast member objects** ⭐
- **`crew_members` (JSONB)** - **Array of crew member objects** ⭐
- `trailer_youtube_id` (TEXT) - Primary trailer YouTube ID
- `trailer_thumbnail` (TEXT) - Trailer thumbnail URL
- `trailer_duration` (INT) - Trailer duration in seconds
- `trailers` (JSONB) - Array of all trailer objects
- `aspect_ratio` (TEXT) - Aspect ratio (e.g., '2.35:1')
- `color` (TEXT) - 'Color' or 'Black and White'
- `sound_mix` (TEXT[]) - Array of sound formats
- `imax_available` (BOOLEAN) - IMAX availability
- `dolby_cinema` (BOOLEAN) - Dolby Cinema availability
- `dolby_atmos` (BOOLEAN) - Dolby Atmos availability
- `dolby_vision` (BOOLEAN) - Dolby Vision availability
- `filming_locations` (TEXT[]) - Array of filming locations
- `production_companies` (JSONB) - Array of production company objects
- `production_countries` (TEXT[]) - Array of country codes
- `spoken_languages` (TEXT[]) - Array of language codes
- `original_language` (TEXT) - Original language code
- `budget` (BIGINT) - Production budget
- `budget_display` (TEXT) - Formatted budget string
- `revenue_worldwide` (BIGINT) - Worldwide box office revenue
- `revenue_display` (TEXT) - Formatted revenue string
- `opening_weekend_us` (BIGINT) - US opening weekend revenue
- `awards` (JSONB) - Array of award objects
- `streaming` (JSONB) - Streaming availability by country
- `collection` (JSONB) - Movie collection/franchise info
- `similar_movies` (JSONB) - Array of similar movie IDs
- `fetched_at` (TIMESTAMPTZ) - When metadata was fetched
- `updated_at` (TIMESTAMPTZ) - When metadata was last updated

---

## Credits Data Structure

### `cast_members` (JSONB Array)

**Storage:** Stored as JSONB array in `works_meta.cast_members`

**Array Limit:** Top 15 cast members (from ingestion code)

**Object Structure:**
```json
{
  "person_id": "string",        // TMDB person ID as string
  "name": "string",              // Actor's name
  "character": "string",         // Character name played
  "order": number,               // Billing order (0 = top billing)
  "photo_url_small": "string",    // Profile photo URL (~92px)
  "photo_url_medium": "string",  // Profile photo URL (~185px)
  "photo_url_large": "string",   // Profile photo URL (~632px)
  "gender": "string"             // 'female', 'male', or 'unknown'
}
```

**Fields Mapping:**
- **Director:** Not in cast_members (see crew_members)
- **Writers:** Not in cast_members (see crew_members)
- **Cast List:** ✅ `cast_members` array
- **Character Name:** ✅ `character` field
- **Billing Order:** ✅ `order` field (lower number = higher billing)

**Example:**
```json
[
  {
    "person_id": "12345",
    "name": "Tom Hanks",
    "character": "Forrest Gump",
    "order": 0,
    "photo_url_small": "https://...",
    "photo_url_medium": "https://...",
    "photo_url_large": "https://...",
    "gender": "male"
  }
]
```

---

### `crew_members` (JSONB Array)

**Storage:** Stored as JSONB array in `works_meta.crew_members`

**Array Limit:** Top 10 crew members (filtered to key roles only)

**Filtered Roles:** Only these roles are stored:
- `'Director'`
- `'Writer'`
- `'Screenplay'`
- `'Producer'`
- `'Director of Photography'`
- `'Original Music Composer'`

**Object Structure:**
```json
{
  "person_id": "string",        // TMDB person ID as string
  "name": "string",              // Crew member's name
  "job": "string",               // Job title (e.g., "Director", "Writer")
  "department": "string",        // Department (e.g., "Directing", "Writing")
  "photo_url_small": "string",  // Profile photo URL (~92px)
  "photo_url_medium": "string"  // Profile photo URL (~185px)
}
```

**Fields Mapping:**
- **Director:** ✅ Filter by `job === 'Director'`
- **Writers:** ✅ Filter by `job === 'Writer'` or `job === 'Screenplay'`
- **Cast List:** ❌ Not in crew_members
- **Character Name:** ❌ Not applicable for crew
- **Job/Role:** ✅ `job` field
- **Department:** ✅ `department` field
- **Billing Order:** ❌ Not stored for crew (no `order` field)

**Example:**
```json
[
  {
    "person_id": "67890",
    "name": "Christopher Nolan",
    "job": "Director",
    "department": "Directing",
    "photo_url_small": "https://...",
    "photo_url_medium": "https://..."
  },
  {
    "person_id": "11111",
    "name": "Jonathan Nolan",
    "job": "Writer",
    "department": "Writing",
    "photo_url_small": "https://...",
    "photo_url_medium": "https://..."
  }
]
```

---

## Notes

1. **No Normalized Tables:** There are no separate `movie_cast`, `movie_crew`, or `people` tables. All credit data is denormalized in JSONB arrays.

2. **No Person Profiles:** Person data (photos, known_for, etc.) is embedded in each movie record. There's no central `people` or `persons` table.

3. **Limited Crew Roles:** Only 6 key crew roles are stored. Other crew positions (e.g., "Editor", "Costume Designer") are not captured.

4. **Billing Order:** Only cast members have an `order` field for billing. Crew members have no ordering information.

5. **Photo URLs:** Cast members have 3 photo sizes (small, medium, large). Crew members have 2 photo sizes (small, medium).

6. **Gender Field:** Only cast members have a `gender` field. Crew members do not.

7. **Data Source:** Credits are fetched from TMDB API during the ingestion process and stored as JSONB.

---

## Query Examples

### Get cast for a movie:
```sql
SELECT cast_members 
FROM works_meta 
WHERE work_id = 1;
```

### Get crew (directors/writers) for a movie:
```sql
SELECT crew_members 
FROM works_meta 
WHERE work_id = 1;
```

### Extract director name:
```sql
SELECT 
  crew_members->>0->>'name' as director_name
FROM works_meta
WHERE work_id = 1
  AND (crew_members->0->>'job') = 'Director';
```

### Get top 5 cast members (by billing order):
```sql
SELECT 
  jsonb_array_elements(cast_members) as cast_member
FROM works_meta
WHERE work_id = 1
ORDER BY (jsonb_array_elements(cast_members)->>'order')::int
LIMIT 5;
```

---

## Recommendations for Movie Page Display

Based on this schema:

1. **Cast Section:** Query `cast_members` JSONB array, sort by `order` field, display top N (e.g., 10-15).

2. **Director:** Filter `crew_members` array for `job === 'Director'`, display name and photo.

3. **Writers:** Filter `crew_members` array for `job === 'Writer'` or `job === 'Screenplay'`, group and display.

4. **Other Crew:** Currently limited to 6 roles. Consider expanding if needed.

5. **Performance:** JSONB queries are fast, but consider caching parsed arrays in the app if displaying frequently.

---

**End of Audit**

