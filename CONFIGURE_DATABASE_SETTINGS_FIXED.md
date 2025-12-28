# Step-by-Step: Configure Database Settings for Cron Jobs (FIXED)

## ⚠️ Important Change
Due to Supabase permission restrictions, we now use a **settings table** instead of `ALTER DATABASE`. This is more secure and works with Supabase's permission model.

---

## Step-by-Step Instructions

### Step 1: Get Your Supabase Project URL
1. Open Supabase Dashboard: https://supabase.com/dashboard
2. Select your **TastyMangoes** project
3. Go to **Settings → API** (left sidebar)
4. Copy the **Project URL** (e.g., `https://abcdefghijklmnop.supabase.co`)

### Step 2: Get Your Service Role Key
1. Still in **Settings → API**
2. Scroll down to **Project API keys**
3. Find **`service_role`** key (⚠️ **Secret**)
4. Click the **eye icon** to reveal it
5. **Copy this key** (keep it secret!)

### Step 3: Insert Settings into Database
1. Go to **SQL Editor** (left sidebar)
2. Click **New query**
3. Paste and update these commands:

```sql
-- Insert Supabase URL (replace with your actual project URL)
INSERT INTO public.cron_settings (setting_key, setting_value)
VALUES ('supabase_url', 'https://your-project-ref.supabase.co')
ON CONFLICT (setting_key) 
DO UPDATE SET setting_value = EXCLUDED.setting_value, updated_at = now();

-- Insert Service Role Key (replace with your actual service role key)
INSERT INTO public.cron_settings (setting_key, setting_value)
VALUES ('service_role_key', 'your-service-role-key-here')
ON CONFLICT (setting_key) 
DO UPDATE SET setting_value = EXCLUDED.setting_value, updated_at = now();
```

4. **Replace the placeholders:**
   - `your-project-ref` → Your actual project reference (from Step 1)
   - `your-service-role-key-here` → Your actual service role key (from Step 2)

5. Click **Run** (or press Cmd+Enter / Ctrl+Enter)

### Step 4: Verify Settings
Run this query to verify:

```sql
-- Check if settings are configured (you should see both rows)
SELECT setting_key, 
       CASE 
         WHEN setting_key = 'service_role_key' THEN '***HIDDEN***'
         ELSE setting_value 
       END as setting_value_display,
       updated_at
FROM public.cron_settings
ORDER BY setting_key;
```

**Expected output:**
- `supabase_url`: Your project URL
- `service_role_key`: `***HIDDEN***` (for security)
- Both should have recent `updated_at` timestamps

---

## Alternative: Update Existing Settings

If you need to update settings later, use:

```sql
-- Update Supabase URL
UPDATE public.cron_settings 
SET setting_value = 'https://your-new-url.supabase.co', updated_at = now()
WHERE setting_key = 'supabase_url';

-- Update Service Role Key
UPDATE public.cron_settings 
SET setting_value = 'your-new-service-role-key', updated_at = now()
WHERE setting_key = 'service_role_key';
```

---

## Security Notes

✅ **Secure**: Settings are stored in a table with RLS that only `service_role` can access  
✅ **No Public Access**: Regular users cannot read these settings  
✅ **Service Role Only**: Only Edge Functions running with service_role can access these values  

⚠️ **Important**: 
- Never commit the service role key to git
- Never share it publicly
- The key has admin access - treat it like a password

---

## Troubleshooting

### Issue: "Permission denied" when reading settings
**Solution**: This is expected! Only service_role can read these settings. Regular users will get permission denied, which is correct for security.

### Issue: "Setting not found" error from cron jobs
**Solution**: Make sure you ran the `INSERT` statements above and they succeeded. Verify with the check query.

### Issue: Can't see the settings table
**Solution**: The table exists but regular users can't see it due to RLS. This is correct behavior. Service role (Edge Functions) can access it.

---

## Next Steps

After configuring these settings:
1. ✅ Verify settings with the check query above
2. ✅ Run migrations in order: 016 → 017 → 018 → 019 → 020
3. ✅ Deploy Edge Functions: `daily-refresh` and `refresh-worker`
4. ✅ Verify cron jobs: `SELECT * FROM cron.job;`

---

## Quick Reference

**SQL Commands to Set Settings:**
```sql
INSERT INTO public.cron_settings (setting_key, setting_value)
VALUES ('supabase_url', 'YOUR_URL_HERE')
ON CONFLICT (setting_key) DO UPDATE SET setting_value = EXCLUDED.setting_value;

INSERT INTO public.cron_settings (setting_key, setting_value)
VALUES ('service_role_key', 'YOUR_KEY_HERE')
ON CONFLICT (setting_key) DO UPDATE SET setting_value = EXCLUDED.setting_value;
```

**Verify Settings:**
```sql
SELECT setting_key, 
       CASE WHEN setting_key = 'service_role_key' THEN '***HIDDEN***' ELSE setting_value END as value,
       updated_at
FROM public.cron_settings;
```

