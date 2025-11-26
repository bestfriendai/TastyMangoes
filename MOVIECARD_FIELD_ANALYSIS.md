# MovieCard Field Analysis

## MovieCard.swift Fields (All Fields)

```swift
struct MovieCard {
    workId: Int                    // ✅ Populated
    tmdbId: String                 // ✅ Populated
    imdbId: String?                // ✅ Populated
    title: String                   // ✅ Populated
    originalTitle: String?          // ✅ Populated
    year: Int?                     // ✅ Populated
    releaseDate: String?            // ✅ Populated
    runtimeMinutes: Int?            // ✅ Populated
    runtimeDisplay: String?         // ✅ Populated
    tagline: String?                // ✅ Populated
    overview: String?               // ✅ Populated
    overviewShort: String?          // ✅ Populated
    genres: [String]?               // ✅ Populated
    poster: PosterUrls?             // ✅ Populated (small, medium, large)
    backdrop: String?               // ✅ Populated
    trailerYoutubeId: String?       // ✅ Populated
    cast: [MovieCardCastMember]?    // ✅ Populated (top 8)
    director: String?               // ✅ Populated
    aiScore: Double?                // ✅ Populated
    aiScoreRange: [Double]?         // ✅ Populated
    sourceScores: SourceScores?     // ✅ Populated (tmdb only)
    similarMovieIds: [Int]?         // ✅ Populated
    lastUpdated: String?             // ✅ Populated
}

struct PosterUrls {
    small: String?                  // ✅ Populated
    medium: String?                 // ✅ Populated
    large: String?                  // ✅ Populated
}

struct MovieCardCastMember {
    personId: String                // ✅ Populated
    name: String                    // ✅ Populated
    character: String?               // ✅ Populated
    order: Int?                     // ✅ Populated
    photoUrlSmall: String?          // ✅ Populated
    photoUrlMedium: String?         // ✅ Populated
    photoUrlLarge: String?          // ✅ Populated
    gender: String?                 // ✅ Populated
}
```

---

## 1. Fields in MovieCard but NOT being populated from database

**NONE** - All MovieCard fields are being populated correctly in `ingest-movie/index.ts`.

**Note:** `trailer_thumbnail` is being set in the movieCard object (line 573) but **MovieCard.swift doesn't have this field**. This is a mismatch - the API returns it but Swift can't decode it (though it won't cause an error since Codable ignores unknown keys by default).

---

## 2. Fields in works_meta but NOT being sent to MovieCard

These fields exist in `works_meta` but are **NOT included** in the MovieCard payload:

### Text Content
- ❌ `keywords` (TEXT[]) - Keywords/tags for the movie
- ❌ `subgenres` (TEXT[]) - More specific genre classifications
- ❌ `moods` (TEXT[]) - Mood descriptors (Tense, Suspenseful, etc.)
- ❌ `themes` (TEXT[]) - Thematic elements

### Ratings & Certification
- ❌ `certification` (TEXT) - MPAA rating (R, PG-13, etc.)
- ❌ `certification_reason` (TEXT) - Why it got that rating
- ❌ `content_warnings` (TEXT[]) - Content warnings

### Visual Assets
- ❌ `poster_url_original` (TEXT) - Original resolution poster (stored but not in card)
- ❌ `backdrop_url_mobile` (TEXT) - Mobile-optimized backdrop
- ❌ `logo_url` (TEXT) - Movie logo
- ❌ `still_images` (JSONB) - Gallery of still images

### Cast & Crew
- ❌ `crew_members` (JSONB) - Full crew array (only director name is extracted)
  - Currently: Only director name is extracted
  - Missing: Writer, Producer, Cinematographer, Composer, etc.

### Trailer & Media
- ❌ `trailer_thumbnail` (TEXT) - Thumbnail for trailer (set but not in MovieCard struct)
- ❌ `trailer_duration` (INT) - Trailer length in seconds
- ❌ `trailers` (JSONB) - Array of all trailers/videos

### Technical Specs
- ❌ `aspect_ratio` (TEXT) - Screen aspect ratio
- ❌ `color` (TEXT) - Color or Black and White
- ❌ `sound_mix` (TEXT[]) - Audio formats
- ❌ `imax_available` (BOOLEAN)
- ❌ `dolby_cinema` (BOOLEAN)
- ❌ `dolby_atmos` (BOOLEAN)
- ❌ `dolby_vision` (BOOLEAN)
- ❌ `filming_locations` (TEXT[])

### Production Info
- ❌ `production_companies` (JSONB) - Studio/company info
- ❌ `production_countries` (TEXT[])
- ❌ `spoken_languages` (TEXT[])
- ❌ `original_language` (TEXT)

### Box Office
- ❌ `budget` (BIGINT)
- ❌ `budget_display` (TEXT)
- ❌ `revenue_worldwide` (BIGINT)
- ❌ `revenue_display` (TEXT)
- ❌ `opening_weekend_us` (BIGINT)

### Awards
- ❌ `awards` (JSONB) - Awards and nominations

### Streaming
- ❌ `streaming` (JSONB) - Where to watch (Netflix, etc.)

### Connections
- ❌ `collection` (JSONB) - Movie collection/franchise info
- ❌ `similar_movies` (JSONB) - OLD field (replaced by `similar_movie_ids`)

### Metadata
- ❌ `fetched_at` (TIMESTAMPTZ)
- ❌ `updated_at` (TIMESTAMPTZ)

---

## 3. Fields needed for app UI but missing from both

Based on `MovieDetail.swift` and `MoviePageView.swift` usage:

### Currently Missing (but used in UI)
- ❌ `trailerThumbnail: String?` - Used for trailer preview
- ❌ `trailerDuration: Int?` - Trailer length in seconds
- ❌ `certification: String?` - MPAA rating (R, PG-13) - shown in UI
- ❌ `budget: Int?` - Used in MovieDetail
- ❌ `revenue: Int?` - Used in MovieDetail
- ❌ `crew: [CrewMember]?` - Full crew list (currently only director)
- ❌ `stillImages: [Image]?` - Photo gallery (currently fetched separately from TMDB)
- ❌ `trailers: [Trailer]?` - All trailers/videos (currently fetched separately)

### Fields that exist in works_meta but need to be added to MovieCard
- `certification` → `certification: String?`
- `trailer_thumbnail` → `trailerThumbnail: String?`
- `trailer_duration` → `trailerDuration: Int?`
- `budget` → `budget: Int?`
- `revenue_worldwide` → `revenue: Int?`
- `crew_members` → `crew: [CrewMember]?` (full array, not just director name)
- `still_images` → `stillImages: [StillImage]?`
- `trailers` → `trailers: [Trailer]?`

---

## 4. get-movie-card Endpoint Return vs MovieCard Expectation

### What get-movie-card Returns:
```json
{
  "work_id": 123,
  "tmdb_id": "550",
  "imdb_id": "tt0137523",
  "title": "Fight Club",
  "original_title": "Fight Club",
  "year": 1999,
  "release_date": "1999-10-15",
  "runtime_minutes": 139,
  "runtime_display": "2h 19m",
  "tagline": "Mischief. Mayhem. Soap.",
  "overview": "A ticking-time-bomb...",
  "overview_short": "A ticking-time-bomb...",
  "genres": ["Drama", "Thriller"],
  "poster": {
    "small": "https://...",
    "medium": "https://...",
    "large": "https://..."
  },
  "backdrop": "https://...",
  "trailer_youtube_id": "abc123",
  "trailer_thumbnail": "https://...",  // ⚠️ EXTRA FIELD - not in MovieCard.swift
  "cast": [...],
  "director": "David Fincher",
  "ai_score": 82.5,
  "ai_score_range": [77.5, 87.5],
  "source_scores": {
    "tmdb": { "score": 82.5, "votes": 25000 }
  },
  "similar_movie_ids": [414, 123, 456],
  "last_updated": "2025-01-15T22:00:00Z"
}
```

### What MovieCard Expects:
All fields match **EXCEPT**:
- ⚠️ `trailer_thumbnail` is returned but **not defined in MovieCard.swift** (will be silently ignored by Codable)

---

## Summary

### ✅ All Good
- All MovieCard fields are being populated correctly
- get-movie-card returns exactly what MovieCard expects (plus one extra field that's ignored)

### ⚠️ Issues Found

1. **trailer_thumbnail mismatch**
   - Being set in `ingest-movie` (line 573)
   - Being returned by `get-movie-card`
   - **NOT defined in MovieCard.swift**
   - **Fix:** Add `trailerThumbnail: String?` to MovieCard

2. **Missing fields used in UI**
   - `certification` (MPAA rating) - shown in MoviePageView
   - `trailerDuration` - used in MovieDetail
   - `budget` / `revenue` - used in MovieDetail
   - Full `crew` array - currently only director name
   - `stillImages` - currently fetched separately from TMDB
   - `trailers` array - currently fetched separately from TMDB

3. **Data available but not exposed**
   - Many fields in `works_meta` are stored but not included in MovieCard
   - These could be added to MovieCard if needed for UI

### 📊 Field Coverage

- **MovieCard fields:** 22 fields
- **Populated from database:** 22/22 (100%)
- **works_meta fields:** ~50+ fields
- **Included in MovieCard:** ~15 fields (~30%)
- **Used in UI but missing:** ~8 fields

