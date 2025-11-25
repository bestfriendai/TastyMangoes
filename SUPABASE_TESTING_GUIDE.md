# Supabase Testing Guide

## Overview
This guide will help you test that Supabase is properly connected and working with your TastyMangoes app.

## Prerequisites
✅ Supabase Swift SDK installed (Auth, PostgREST, Realtime, Storage)  
✅ Database schema migrated (all tables created)  
✅ SupabaseConfig.swift configured with your credentials  
✅ ProfileView wired into tab bar  

## Testing Steps

### 1. Test Database Connection

**What to test:** Verify the app can connect to Supabase

**Steps:**
1. Build and run the app
2. Check Xcode console for any connection errors
3. You should see the Sign In screen (not authenticated yet)

**Expected Result:**
- No connection errors in console
- Sign In screen appears

**If errors occur:**
- Check `SupabaseConfig.swift` has correct URL and key
- Verify Supabase project is active
- Check network connectivity

---

### 2. Test User Sign Up

**What to test:** Create a new user account

**Steps:**
1. On Sign In screen, tap "Sign Up"
2. Fill in the form:
   - Username: `testuser` (or any unique username)
   - Email: `test@example.com` (use a real email for testing)
   - Password: `password123` (at least 6 characters)
   - Confirm Password: `password123`
3. Tap "Sign Up" button
4. Wait for sign up to complete

**Expected Result:**
- Sign up succeeds
- App navigates to main TabBarView
- Profile tab shows your username
- No error messages

**Check Supabase Dashboard:**
- Go to Authentication → Users
- You should see the new user
- Go to Table Editor → profiles
- You should see a profile with your username

**If errors occur:**
- Check error message in app
- Verify email format is valid
- Check password meets requirements (6+ characters)
- Check Supabase logs in dashboard

---

### 3. Test User Sign In

**What to test:** Sign in with existing account

**Steps:**
1. Sign out (if signed in)
2. On Sign In screen, enter:
   - Email: `test@example.com`
   - Password: `password123`
3. Tap "Sign In" button

**Expected Result:**
- Sign in succeeds
- App navigates to main TabBarView
- Profile loads with your username

**If errors occur:**
- Verify email and password are correct
- Check Supabase Authentication logs
- Try resetting password if needed

---

### 4. Test Profile View

**What to test:** View and edit profile

**Steps:**
1. Navigate to "More" tab (should show ProfileView)
2. Verify username is displayed
3. Tap pencil icon next to username
4. Change username to something new
5. Tap "Save"
6. Verify username updates

**Expected Result:**
- Profile view loads correctly
- Username displays
- Username can be edited and saved
- Changes persist after app restart

**Check Supabase Dashboard:**
- Go to Table Editor → profiles
- Verify username was updated

---

### 5. Test Subscriptions Management

**What to test:** Add/remove streaming platform subscriptions

**Steps:**
1. In ProfileView, scroll to "Streaming Subscriptions" section
2. Tap checkboxes to select platforms (e.g., Netflix, Prime Video)
3. Tap "Save Subscriptions" button
4. Verify checkboxes remain checked
5. Uncheck some platforms
6. Tap "Save Subscriptions" again
7. Restart app and verify selections persist

**Expected Result:**
- Checkboxes work correctly
- Subscriptions save successfully
- Selections persist after app restart

**Check Supabase Dashboard:**
- Go to Table Editor → user_subscriptions
- Verify your selected platforms appear
- Verify only your selected platforms are present

---

### 6. Test Sign Out

**What to test:** Sign out functionality

**Steps:**
1. In ProfileView, scroll to bottom
2. Tap "Sign Out" button
3. Verify app returns to Sign In screen

**Expected Result:**
- Sign out succeeds
- App returns to Sign In screen
- No errors occur

---

### 7. Test Watchlist Operations (Future)

**Note:** WatchlistManager still uses in-memory storage. To test Supabase watchlists:

**Steps:**
1. Create a watchlist via SupabaseService
2. Add movies to watchlist
3. Verify in Supabase dashboard

**Check Supabase Dashboard:**
- Go to Table Editor → watchlists
- Go to Table Editor → watchlist_movies

---

### 8. Test Watch History (Future)

**Note:** Watch history integration pending

**Steps:**
1. Mark a movie as watched
2. Verify entry in watch_history table

**Check Supabase Dashboard:**
- Go to Table Editor → watch_history

---

### 9. Test User Ratings (Future)

**Note:** Ratings integration pending

**Steps:**
1. Rate a movie
2. Verify entry in user_ratings table

**Check Supabase Dashboard:**
- Go to Table Editor → user_ratings

---

## Common Issues & Solutions

### Issue: "Supabase not configured" error
**Solution:**
- Verify `SupabaseConfig.swift` has correct URL and key
- Check for typos in URL or key
- Ensure Supabase project is active

### Issue: Authentication fails
**Solution:**
- Check email format is valid
- Verify password meets requirements
- Check Supabase Authentication settings
- Verify RLS policies are set correctly

### Issue: Profile not created on signup
**Solution:**
- Check trigger `on_auth_user_created` exists
- Verify function `handle_new_user()` exists
- Check Supabase logs for errors

### Issue: Can't update profile
**Solution:**
- Verify RLS policy "Users can update own profile" exists
- Check user is authenticated
- Verify user_id matches profile id

### Issue: Subscriptions not saving
**Solution:**
- Check RLS policy "Users can manage own subscriptions"
- Verify platform names match CHECK constraint exactly
- Check for duplicate entries (UNIQUE constraint)

---

## Verification Checklist

- [ ] App connects to Supabase (no connection errors)
- [ ] User can sign up successfully
- [ ] Profile is created automatically on signup
- [ ] User can sign in successfully
- [ ] ProfileView displays correctly
- [ ] Username can be edited and saved
- [ ] Subscriptions can be selected and saved
- [ ] Subscriptions persist after app restart
- [ ] User can sign out successfully
- [ ] Data appears correctly in Supabase dashboard

---

## Next Steps

Once basic testing is complete:

1. **Integrate WatchlistManager with Supabase**
   - Update WatchlistManager to use SupabaseService
   - Sync watchlists on app launch
   - Sync changes to Supabase

2. **Integrate Watch History**
   - Update "Mark as Watched" to use watch_history table
   - Display watch history in UI

3. **Integrate User Ratings**
   - Update RateBottomSheet to use user_ratings table
   - Display ratings on movie pages

4. **Add Real-time Updates**
   - Use Supabase Realtime for live updates
   - Sync data across devices

---

## Support

For Supabase-specific issues:
- Supabase Docs: https://supabase.com/docs
- Supabase Dashboard: https://app.supabase.com
- Check Supabase logs in dashboard for detailed error messages

