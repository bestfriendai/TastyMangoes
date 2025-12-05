# Database Schema Revision Summary

## Changes Made

### 1. ✅ Movie Scores - Left As-Is
- `tasty_score` and `ai_score` fields remain in `movies` table
- No additional scoring fields added
- Will be implemented in future migration

### 2. ✅ Separated Watch History from Watchlists

**New Table: `watch_history`**
- `id` (UUID, primary key)
- `user_id` (UUID, references profiles)
- `movie_id` (TEXT, TMDB ID)
- `watched_at` (TIMESTAMPTZ)
- `platform` (TEXT, nullable - streaming service)
- `created_at` (TIMESTAMPTZ)
- UNIQUE constraint on (user_id, movie_id)
- RLS policies: users can only see/manage their own watch history
- Indexes on user_id and movie_id

**Updated Table: `watchlist_movies`**
- REMOVED: `watched`, `watched_at`, `rating`, `review_text` fields
- KEPT: `watchlist_id`, `movie_id`, `added_at`
- Now purely for "movies I want to watch"

### 3. ✅ Created User Ratings Table

**New Table: `user_ratings`**
- `id` (UUID, primary key)
- `user_id` (UUID, references profiles)
- `movie_id` (TEXT, TMDB ID)
- `rating` (INTEGER, 0-5 stars)
- `review_text` (TEXT, nullable)
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)
- UNIQUE constraint on (user_id, movie_id) - one rating per movie per user
- RLS policies: everyone can view, users manage their own
- Indexes on user_id and movie_id

### 4. ✅ Created ProfileView

**New File: `ProfileView.swift`**
- Displays username (editable with pencil icon)
- Displays email (read-only, placeholder for now)
- Streaming subscriptions section with checkboxes for 10 platforms:
  - Netflix, Prime Video, Disney+, Max, Hulu, Criterion, Paramount+, Apple TV+, Peacock, Tubi
- Save button for subscriptions
- Sign out button
- Matches app design patterns (similar to SearchView/WatchlistView styling)
- Uses UserProfileManager for data management

### 5. ✅ Updated Swift Service Layer

**Updated Files:**
- `SupabaseService.swift` - Added methods for:
  - Watch history operations (add, remove, get, check if watched)
  - User ratings operations (add/update, delete, get user rating, get movie ratings)
  - Simplified watchlist movie operations (removed watched/rating fields)

- `SupabaseModels.swift` - Updated models:
  - `WatchlistMovie` - Simplified (removed watched, rating, review fields)
  - `WatchHistory` - New model
  - `UserRating` - New model

- `UserProfileManager.swift` - No changes needed (already handles subscriptions)

## Files Created/Updated

### Created:
1. `supabase/migrations/001_initial_schema.sql` (revised)
2. `ProfileView.swift` (new)

### Updated:
1. `SupabaseService.swift` - Added watch history and ratings methods
2. `SupabaseModels.swift` - Updated models to match schema

## Next Steps

1. Run the SQL migration in Supabase dashboard
2. Test ProfileView integration
3. Update WatchlistManager to use watch_history table for "watched" status
4. Update RateBottomSheet to use user_ratings table
5. Integrate ProfileView into TabBarView (More tab)

## Database Schema Overview

```
profiles
├── id (UUID, PK)
├── username (TEXT, UNIQUE)
├── avatar_url (TEXT)
└── timestamps

user_subscriptions
├── id (UUID, PK)
├── user_id (UUID, FK → profiles)
├── platform (TEXT, CHECK constraint)
└── timestamps

watchlists
├── id (UUID, PK)
├── user_id (UUID, FK → profiles)
├── name (TEXT)
└── timestamps

watchlist_movies (simplified)
├── id (UUID, PK)
├── watchlist_id (UUID, FK → watchlists)
├── movie_id (TEXT)
└── added_at (TIMESTAMPTZ)

watch_history (NEW)
├── id (UUID, PK)
├── user_id (UUID, FK → profiles)
├── movie_id (TEXT)
├── watched_at (TIMESTAMPTZ)
├── platform (TEXT, nullable)
└── timestamps

user_ratings (NEW)
├── id (UUID, PK)
├── user_id (UUID, FK → profiles)
├── movie_id (TEXT)
├── rating (INTEGER, 0-5)
├── review_text (TEXT, nullable)
└── timestamps

movies
├── id (TEXT, PK)
├── tasty_score (DOUBLE PRECISION) -- Keep as-is
├── ai_score (DOUBLE PRECISION) -- Keep as-is
└── ... other fields
```

