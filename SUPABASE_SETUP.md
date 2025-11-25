# Supabase Setup Guide for TastyMangoes

## Overview

This guide will help you set up Supabase for your TastyMangoes app. The setup includes:
- Database schema for users, profiles, watchlists, movies, and subscriptions
- Authentication system
- User profile management with username and subscriptions
- Watchlist management with Supabase backend

## Prerequisites

1. A Supabase account (sign up at https://supabase.com)
2. A Supabase project created
3. Xcode project with Swift Package Manager support

## Step 1: Install Supabase Swift SDK

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter the URL: `https://github.com/supabase/supabase-swift`
3. Select the latest version
4. Add to your target

## Step 2: Run Database Migration

1. Go to your Supabase project dashboard: https://app.supabase.com
2. Navigate to **SQL Editor**
3. Copy the contents of `supabase/migrations/001_initial_schema.sql`
4. Paste into the SQL Editor and click **Run**

This will create:
- `profiles` table (user profiles with username)
- `user_subscriptions` table (user's streaming platform subscriptions)
- `watchlists` table (user's watchlists)
- `watchlist_movies` table (movies in watchlists)
- `movies` table (cached movie data)
- Row Level Security (RLS) policies
- Triggers for automatic profile creation

## Step 3: Configure Supabase Credentials

1. In Supabase dashboard, go to **Settings → API**
2. Copy your **Project URL** and **anon/public key**
3. Open `SupabaseConfig.swift`
4. Replace the placeholder values:

```swift
static let supabaseURL = "https://your-project.supabase.co"
static let supabaseAnonKey = "your-anon-key-here"
```

## Step 4: Add Files to Xcode Project

Add these files to your Xcode project:
- `SupabaseConfig.swift`
- `SupabaseService.swift`
- `SupabaseModels.swift`
- `AuthManager.swift`
- `UserProfileManager.swift`

## Step 5: Update App Entry Point

Update `TastyMangoesApp.swift` to initialize authentication:

```swift
@main
struct TastyMangoesApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                TabBarView()
                    .environmentObject(WatchlistManager.shared)
                    .environmentObject(authManager)
                    .environmentObject(profileManager)
            } else {
                AuthView() // You'll need to create this
            }
        }
    }
}
```

## Step 6: Create Authentication UI (Optional)

Create a simple sign up/sign in view, or integrate authentication into your existing UI.

## Step 7: Update Search Filter State

Update `SearchFilterState.swift` to use user subscriptions:

```swift
// In SearchFilterState, add:
@Published var useMySubscriptions: Bool = false

// When useMySubscriptions is true, automatically filter by UserProfileManager.shared.subscriptions
```

## Step 8: Migrate WatchlistManager (Optional)

You can gradually migrate `WatchlistManager` to use Supabase:
1. Keep the current in-memory implementation as fallback
2. Add Supabase sync methods
3. Sync on app launch and after changes

## Database Schema Summary

### Tables Created:

1. **profiles** - User profiles (username, avatar)
2. **user_subscriptions** - User's streaming platform subscriptions
3. **watchlists** - User's watchlists
4. **watchlist_movies** - Movies in watchlists (with watched status, rating, review)
5. **movies** - Cached movie data

### Security:

- Row Level Security (RLS) enabled on all tables
- Users can only access their own data
- Public read access for profiles (for search/filtering)

## Next Steps

1. Test authentication flow
2. Test profile creation and username updates
3. Test subscription management
4. Test watchlist operations
5. Integrate with existing UI

## Troubleshooting

### "Supabase not configured" error
- Make sure you've set `SupabaseConfig.supabaseURL` and `SupabaseConfig.supabaseAnonKey`

### Authentication not working
- Check that RLS policies are set up correctly
- Verify your Supabase project is active
- Check network connectivity

### Profile not created on signup
- Verify the trigger `on_auth_user_created` was created
- Check Supabase logs for errors

## Support

For Supabase-specific issues, check:
- Supabase Docs: https://supabase.com/docs
- Supabase Swift SDK: https://github.com/supabase/supabase-swift

