# Step-by-Step: Configure Database Settings for Cron Jobs

## Overview
Before running the Phase 2 migrations, you need to configure two database settings:
1. `app.settings.supabase_url` - Your Supabase project URL
2. `app.settings.service_role_key` - Your service role key (for Edge Function authentication)

---

## Method 1: Via Supabase Dashboard (Recommended)

### Step 1: Open Supabase Dashboard
1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Sign in to your account
3. Select your **TastyMangoes** project

### Step 2: Find Your Project URL
1. In the left sidebar, click **Settings** (gear icon)
2. Click **API** (under Project Settings)
3. Find **Project URL** - it looks like: `https://xxxxxxxxxxxxx.supabase.co`
4. **Copy this URL** - you'll need it in Step 4

### Step 3: Find Your Service Role Key
1. Still in **Settings > API**
2. Scroll down to **Project API keys**
3. Find **`service_role`** key (⚠️ **Secret** - this is the one you need)
4. Click the **eye icon** to reveal it (or click "Reveal")
5. **Copy this key** - you'll need it in Step 4
   - ⚠️ **WARNING**: Never share this key publicly or commit it to git!

### Step 4: Set Database Custom Config
1. In the left sidebar, click **Settings**
2. Click **Database** (under Project Settings)
3. Scroll down to **Custom Config** section
4. You'll see a text area or form for custom database settings

**Option A: If there's a "Custom Config" text area:**
   - Add these two lines:
   ```
   app.settings.supabase_url = 'https://your-project-ref.supabase.co'
   app.settings.service_role_key = 'your-service-role-key-here'
   ```
   - Replace `your-project-ref` with your actual project reference
   - Replace `your-service-role-key-here` with your actual service role key
   - Click **Save**

**Option B: If there's no Custom Config UI:**
   - Use Method 2 (SQL Editor) below instead

---

## Method 2: Via SQL Editor (Alternative)

### Step 1: Open SQL Editor
1. In Supabase Dashboard, click **SQL Editor** in the left sidebar
2. Click **New query**

### Step 2: Get Your Project URL
1. Go to **Settings > API**
2. Copy your **Project URL** (e.g., `https://xxxxxxxxxxxxx.supabase.co`)

### Step 3: Get Your Service Role Key
1. Still in **Settings > API**
2. Find **`service_role`** key
3. Click to reveal and copy it

### Step 4: Run SQL Commands
1. Go back to **SQL Editor**
2. Paste these commands (replace the values):

```sql
-- Set Supabase URL (replace with your actual project URL)
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project-ref.supabase.co';

-- Set Service Role Key (replace with your actual service role key)
ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key-here';
```

3. **Replace the placeholders:**
   - `your-project-ref` → Your actual project reference (from Project URL)
   - `your-service-role-key-here` → Your actual service role key

4. Click **Run** (or press Cmd+Enter / Ctrl+Enter)

### Step 5: Verify Settings
Run this query to verify the settings were saved:

```sql
-- Check if settings are configured
SELECT 
    current_setting('app.settings.supabase_url', true) as supabase_url,
    CASE 
        WHEN current_setting('app.settings.service_role_key', true) IS NOT NULL 
        THEN '***CONFIGURED***' 
        ELSE 'NOT SET' 
    END as service_role_key_status;
```

**Expected output:**
- `supabase_url`: Should show your project URL
- `service_role_key_status`: Should show `***CONFIGURED***`

---

## Troubleshooting

### Issue: "Setting does not exist"
**Solution**: The setting might not be initialized. Try setting it again with the full command.

### Issue: "Permission denied"
**Solution**: Make sure you're using the SQL Editor with proper permissions. If needed, use the Dashboard method instead.

### Issue: "Cannot find Custom Config in Dashboard"
**Solution**: Use Method 2 (SQL Editor) instead. The Custom Config feature may not be available in all Supabase plans.

### Issue: Settings don't persist
**Solution**: Database-level settings (`ALTER DATABASE`) should persist. If they don't, check:
1. Are you connected to the correct database?
2. Try re-running the `ALTER DATABASE` commands
3. Verify with the check query above

---

## Security Reminders

⚠️ **IMPORTANT**:
- Never commit the service role key to git
- Never share the service role key publicly
- The service role key has admin access - treat it like a password
- If the key is exposed, rotate it immediately in Supabase Dashboard

---

## Next Steps

After configuring these settings:
1. ✅ Verify settings with the check query above
2. ✅ Run migrations in order: 016 → 017 → 018 → 019 → 020
3. ✅ Deploy Edge Functions: `daily-refresh` and `refresh-worker`
4. ✅ Verify cron jobs: `SELECT * FROM cron.job;`

---

## Quick Reference

**Your Project URL**: Found in Settings > API > Project URL  
**Your Service Role Key**: Found in Settings > API > Project API keys > `service_role` (Secret)

**SQL Commands**:
```sql
ALTER DATABASE postgres SET app.settings.supabase_url = 'YOUR_URL_HERE';
ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_KEY_HERE';
```

