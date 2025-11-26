# Supabase Storage Setup for Movie Images

## Overview

The ingestion pipeline now downloads images from TMDB and stores them in Supabase Storage instead of using TMDB URLs directly. This provides better control, caching, and reduces dependency on external services.

## Storage Bucket Setup

### Step 1: Create the Storage Bucket

1. **Go to Supabase Dashboard** → Storage
2. **Click "New bucket"**
3. **Configure:**
   - **Name:** `movie-images`
   - **Public bucket:** ✅ Checked (images need to be publicly accessible)
   - **File size limit:** 10 MB (or higher if needed)
   - **Allowed MIME types:** `image/jpeg`, `image/png`, `image/webp`

### Step 2: Set Up Storage Policies

The bucket needs to be publicly readable. Supabase should automatically create policies for public buckets, but verify:

1. **Go to Storage** → `movie-images` → Policies
2. **Ensure these policies exist:**

```sql
-- Allow public read access
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'movie-images');

-- Allow service role to upload (for Edge Functions)
CREATE POLICY "Service Role Upload"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'movie-images');
```

### Step 3: Verify Bucket Structure

The ingestion pipeline creates these folders automatically:

```
movie-images/
├── posters/
│   ├── {work_id}_medium.jpg
│   └── {work_id}_large.jpg
├── backdrops/
│   └── {work_id}.jpg
├── trailers/
│   └── {work_id}_thumb.jpg
└── cast/
    └── {person_id}.jpg
```

## Image Storage Details

### Posters
- **Medium (342px):** `posters/{work_id}_medium.jpg`
- **Large (500px):** `posters/{work_id}_large.jpg`
- Small poster (154px) still uses TMDB URL (not stored locally)

### Backdrops
- **Mobile (780px):** `backdrops/{work_id}.jpg`
- Used for both desktop and mobile (780px is sufficient)

### Trailers
- **Thumbnail:** `trailers/{work_id}_thumb.jpg`
- Downloaded from YouTube (`maxresdefault.jpg` or `hqdefault.jpg` fallback)

### Cast Photos
- **Profile (185px):** `cast/{person_id}.jpg`
- Only top 10 cast members
- Skips if already exists (reusable across movies)

## URL Format

Images are accessible via:
```
https://zyywpjddzvkqvjosifiy.supabase.co/storage/v1/object/public/movie-images/{path}
```

Example:
```
https://zyywpjddzvkqvjosifiy.supabase.co/storage/v1/object/public/movie-images/posters/123_medium.jpg
```

## Re-running Ingestion

After setting up storage, re-run ingestion for existing movies:

1. **Call batch-ingest function** (processes 10 at a time)
2. **Or call ingest-movie individually** for each movie with `force_refresh: true`

The pipeline will:
- Download images from TMDB/YouTube
- Upload to Supabase Storage
- Update database with storage URLs
- Update cached movie cards

## Troubleshooting

### "Bucket not found" Error
- Ensure bucket `movie-images` exists
- Check bucket name matches exactly (case-sensitive)
- Verify bucket is public

### Upload Failures
- Check file size limits
- Verify MIME type restrictions
- Check storage policies allow uploads

### Missing Images
- Some movies don't have posters/backdrops in TMDB
- Pipeline handles missing images gracefully
- Falls back to TMDB URLs if download fails

### Cast Photos Not Uploading
- Check if person_id is valid
- Verify TMDB profile_path exists
- Check storage permissions

## Storage Costs

- **Free tier:** 1 GB storage, 2 GB bandwidth/month
- **Pro tier:** 100 GB storage, 200 GB bandwidth/month
- Average image sizes:
  - Poster (342px): ~50-100 KB
  - Poster (500px): ~80-150 KB
  - Backdrop (780px): ~150-300 KB
  - Cast photo (185px): ~20-50 KB
  - Trailer thumbnail: ~100-200 KB

**Estimated storage per movie:** ~500 KB - 1 MB
**25 seed movies:** ~12-25 MB

## Next Steps

1. Create the `movie-images` bucket
2. Set up storage policies
3. Re-run ingestion for existing movies
4. Verify images are accessible via URLs
5. Monitor storage usage

