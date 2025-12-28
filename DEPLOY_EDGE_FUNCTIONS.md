# How to Deploy Supabase Edge Functions

## Method 1: Using Deployment Script (Easiest)

Use the automated deployment script:

```bash
cd /Users/timrobinson/Developer/TastyMangoes

# Deploy a specific function
./deploy-edge-functions.sh search-movies

# Deploy all functions
./deploy-edge-functions.sh all

# Show available functions
./deploy-edge-functions.sh
```

## Method 2: Using Supabase CLI (Manual)

### Prerequisites:
1. Install Supabase CLI (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Link your project:
   ```bash
   cd /Users/timrobinson/Developer/TastyMangoes
   supabase link --project-ref zyywpjddzvkqvjosifiy
   ```

### Deploy the scheduled-ingest function:
```bash
cd /Users/timrobinson/Developer/TastyMangoes
supabase functions deploy scheduled-ingest
```

### Deploy all functions (if needed):
```bash
supabase functions deploy ingest-movie
supabase functions deploy search-movies
supabase functions deploy get-movie-card
supabase functions deploy get-similar-movies
```

## Method 3: Using Supabase Dashboard

1. Go to: https://app.supabase.com/project/zyywpjddzvkqvjosifiy
2. Click **"Edge Functions"** in the left sidebar
3. Find **"scheduled-ingest"** in the list
4. Click on it
5. Click the **"Deploy"** button (or use the code editor to update and deploy)

## Method 4: Using Supabase Dashboard Code Editor

1. Go to: https://app.supabase.com/project/zyywpjddzvkqvjosifiy
2. Click **"Edge Functions"** → **"scheduled-ingest"**
3. Click the **"Code"** tab
4. Copy the updated code from `/Users/timrobinson/Developer/TastyMangoes/supabase/functions/scheduled-ingest/index.ts`
5. Paste it into the editor
6. Click **"Deploy"**

## Verify Deployment

After deploying, check the logs:
1. Go to **Edge Functions** → **scheduled-ingest** → **Logs** tab
2. Run a scheduled ingest
3. Look for `[TMDB]` log entries showing API calls being logged

## Troubleshooting

If you get "command not found" for `supabase`:
- Make sure Node.js is installed: `node --version`
- Install Supabase CLI: `npm install -g supabase`
- Verify installation: `supabase --version`
