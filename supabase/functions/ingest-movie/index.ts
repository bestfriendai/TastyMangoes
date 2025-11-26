//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-01-15 at 20:30 (America/Los_Angeles - Pacific Time)
//  Notes: Main ingestion pipeline for fetching movie data from TMDB and storing in database with image storage

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { 
  fetchMovieDetails, 
  fetchMovieCredits, 
  fetchMovieVideos,
  buildImageUrl,
  formatRuntime,
  downloadImage,
  downloadYouTubeThumbnail
} from '../_shared/tmdb.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;
const STORAGE_BUCKET = 'movie-images';
const STORAGE_BASE_URL = `${supabaseUrl}/storage/v1/object/public/${STORAGE_BUCKET}`;

serve(async (req) => {
  try {
    const { tmdb_id, force_refresh = false } = await req.json();
    
    if (!tmdb_id) {
      return new Response(
        JSON.stringify({ error: 'tmdb_id required' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[INGEST] Starting ingestion for TMDB ID: ${tmdb_id}, force_refresh: ${force_refresh}`);
    
    // Create admin client with service_role key for storage operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    
    // Check if movie exists and if it needs refresh
    const { data: existingWork, error: lookupError } = await supabaseAdmin
      .from('works')
      .select('work_id, last_refreshed_at, release_date')
      .eq('tmdb_id', tmdb_id.toString())
      .maybeSingle();
    
    if (lookupError && lookupError.code !== 'PGRST116') {
      throw lookupError;
    }
    
    // SKIP cache check entirely if force_refresh is true
    if (existingWork && !force_refresh) {
      console.log(`[INGEST] Checking cache for existing work_id: ${existingWork.work_id} (force_refresh=false)`);
      
      // Check staleness using the database function
      const { data: isStale, error: staleError } = await supabaseAdmin
        .rpc('is_stale', { work_id_input: existingWork.work_id });
      
      if (staleError) {
        console.warn('[INGEST] Error checking staleness:', staleError);
        // Continue with refresh if staleness check fails
      } else if (!isStale) {
        // Return cached card
        const { data: cachedCard } = await supabaseAdmin
          .from('work_cards_cache')
          .select('payload')
          .eq('work_id', existingWork.work_id)
          .single();
        
        if (cachedCard) {
          console.log(`[INGEST] Returning cached card for work_id: ${existingWork.work_id}`);
          return new Response(
            JSON.stringify({ 
              status: 'cached', 
              work_id: existingWork.work_id,
              card: cachedCard.payload 
            }),
            { headers: { 'Content-Type': 'application/json' } }
          );
        }
      }
    } else if (force_refresh) {
      console.log(`[INGEST] force_refresh=true, skipping cache check and proceeding with full ingestion`);
    } else if (!existingWork) {
      console.log(`[INGEST] Work does not exist, proceeding with full ingestion`);
    }
    
    console.log('[INGEST] Fetching fresh data from TMDB...');
    
    // Fetch fresh data from TMDB
    const [details, credits, videos] = await Promise.all([
      fetchMovieDetails(tmdb_id.toString()),
      fetchMovieCredits(tmdb_id.toString()),
      fetchMovieVideos(tmdb_id.toString())
    ]);
    
    console.log(`[INGEST] Fetched TMDB data for: ${details.title}`);
    
    // Find the official trailer
    const trailer = videos.results.find(v => 
      v.type === 'Trailer' && v.site === 'YouTube' && v.official
    ) || videos.results.find(v => 
      v.type === 'Trailer' && v.site === 'YouTube'
    ) || videos.results[0];
    
    // Extract year from release_date
    const year = details.release_date ? parseInt(details.release_date.substring(0, 4)) : null;
    
    // Upsert into works table
    const workData = {
      tmdb_id: tmdb_id.toString(),
      imdb_id: details.imdb_id || null,
      title: details.title,
      original_title: details.original_title,
      year: year,
      release_date: details.release_date || null,
      last_refreshed_at: new Date().toISOString(),
    };
    
    const { data: work, error: workError } = await supabaseAdmin
      .from('works')
      .upsert(workData, { onConflict: 'tmdb_id' })
      .select('work_id')
      .single();
    
    if (workError) throw workError;
    
    console.log(`[INGEST] Created/updated work with work_id: ${work.work_id}`);
    console.log(`[INGEST] Starting image upload for work_id: ${work.work_id}`);
    
    // ============================================
    // DOWNLOAD AND UPLOAD IMAGES TO SUPABASE STORAGE
    // ============================================
    
    const storageUrls: {
      posterMedium?: string;
      posterLarge?: string;
      backdrop?: string;
      trailerThumb?: string;
      castPhotos: Map<string, string>;
    } = {
      castPhotos: new Map(),
    };
    
    // Helper function to upload image to storage
    const uploadImageToStorage = async (
      imageBuffer: ArrayBuffer,
      storagePath: string,
      contentType: string = 'image/jpeg'
    ): Promise<string | null> => {
      try {
        console.log(`[STORAGE] Uploading to storage path: ${storagePath}`);
        console.log(`[STORAGE] Image size: ${imageBuffer.byteLength} bytes`);
        
        // Convert ArrayBuffer to Uint8Array for Supabase Storage
        const uint8Array = new Uint8Array(imageBuffer);
        
        const { data: uploadData, error: uploadError } = await supabaseAdmin
          .storage
          .from('movie-images')
          .upload(storagePath, uint8Array, {
            contentType: 'image/jpeg',
            upsert: true
          });
        
        if (uploadError) {
          console.error(`[STORAGE] Upload failed for ${storagePath}:`, uploadError);
          return null;
        } else {
          console.log(`[STORAGE] Upload succeeded: ${storagePath}`);
          return `${STORAGE_BASE_URL}/${storagePath}`;
        }
      } catch (error) {
        console.error(`[STORAGE] Exception uploading ${storagePath}:`, error);
        return null;
      }
    };
    
    // Helper function to check if file exists
    const fileExists = async (path: string): Promise<boolean> => {
      try {
        const folderPath = path.split('/').slice(0, -1).join('/') || '';
        const fileName = path.split('/').pop() || '';
        
        const { data, error } = await supabaseAdmin.storage
          .from(STORAGE_BUCKET)
          .list(folderPath, {
            search: fileName,
            limit: 1,
          });
        
        if (error) {
          console.log(`[STORAGE] Error checking existence of ${path}:`, error);
          return false;
        }
        
        const exists = data ? data.some(file => file.name === fileName) : false;
        console.log(`[STORAGE] File ${path} exists: ${exists}`);
        return exists;
      } catch (error) {
        console.log(`[STORAGE] Exception checking existence of ${path}:`, error);
        return false;
      }
    };
    
    // 1. Download and upload poster medium (342px)
    if (details.poster_path) {
      const posterMediumUrl = buildImageUrl(details.poster_path, 'w342');
      console.log(`[DOWNLOAD] Downloading poster medium from: ${posterMediumUrl}`);
      
      const posterMediumData = await downloadImage(posterMediumUrl);
      if (posterMediumData) {
        console.log(`[DOWNLOAD] Downloaded poster medium, size: ${posterMediumData.byteLength} bytes`);
        
        const storagePath = `posters/${work.work_id}_medium.jpg`;
        const storageUrl = await uploadImageToStorage(posterMediumData, storagePath);
        if (storageUrl) {
          storageUrls.posterMedium = storageUrl;
          console.log(`[STORAGE] Poster medium URL: ${storageUrl}`);
        }
      } else {
        console.warn(`[DOWNLOAD] Failed to download poster medium from: ${posterMediumUrl}`);
      }
    } else {
      console.log(`[DOWNLOAD] No poster_path available for TMDB ID: ${tmdb_id}`);
    }
    
    // 2. Download and upload poster large (500px)
    if (details.poster_path) {
      const posterLargeUrl = buildImageUrl(details.poster_path, 'w500');
      console.log(`[DOWNLOAD] Downloading poster large from: ${posterLargeUrl}`);
      
      const posterLargeData = await downloadImage(posterLargeUrl);
      if (posterLargeData) {
        console.log(`[DOWNLOAD] Downloaded poster large, size: ${posterLargeData.byteLength} bytes`);
        
        const storagePath = `posters/${work.work_id}_large.jpg`;
        const storageUrl = await uploadImageToStorage(posterLargeData, storagePath);
        if (storageUrl) {
          storageUrls.posterLarge = storageUrl;
          console.log(`[STORAGE] Poster large URL: ${storageUrl}`);
        }
      } else {
        console.warn(`[DOWNLOAD] Failed to download poster large from: ${posterLargeUrl}`);
      }
    }
    
    // 3. Download and upload backdrop (780px)
    if (details.backdrop_path) {
      const backdropUrl = buildImageUrl(details.backdrop_path, 'w780');
      console.log(`[DOWNLOAD] Downloading backdrop from: ${backdropUrl}`);
      
      const backdropData = await downloadImage(backdropUrl);
      if (backdropData) {
        console.log(`[DOWNLOAD] Downloaded backdrop, size: ${backdropData.byteLength} bytes`);
        
        const storagePath = `backdrops/${work.work_id}.jpg`;
        const storageUrl = await uploadImageToStorage(backdropData, storagePath);
        if (storageUrl) {
          storageUrls.backdrop = storageUrl;
          console.log(`[STORAGE] Backdrop URL: ${storageUrl}`);
        }
      } else {
        console.warn(`[DOWNLOAD] Failed to download backdrop from: ${backdropUrl}`);
      }
    } else {
      console.log(`[DOWNLOAD] No backdrop_path available for TMDB ID: ${tmdb_id}`);
    }
    
    // 4. Download and upload trailer thumbnail from YouTube
    if (trailer?.key) {
      console.log(`[DOWNLOAD] Downloading YouTube thumbnail for video ID: ${trailer.key}`);
      
      const thumbnailData = await downloadYouTubeThumbnail(trailer.key);
      if (thumbnailData) {
        console.log(`[DOWNLOAD] Downloaded trailer thumbnail, size: ${thumbnailData.byteLength} bytes`);
        
        const storagePath = `trailers/${work.work_id}_thumb.jpg`;
        const storageUrl = await uploadImageToStorage(thumbnailData, storagePath);
        if (storageUrl) {
          storageUrls.trailerThumb = storageUrl;
          console.log(`[STORAGE] Trailer thumbnail URL: ${storageUrl}`);
        }
      } else {
        console.warn(`[DOWNLOAD] Failed to download YouTube thumbnail for video ID: ${trailer.key}`);
      }
    } else {
      console.log(`[DOWNLOAD] No trailer available for TMDB ID: ${tmdb_id}`);
    }
    
    // 5. Download and upload cast photos (top 10, 185px)
    // Skip if already exists
    const top10Cast = credits.cast.slice(0, 10);
    console.log(`[DOWNLOAD] Processing ${top10Cast.length} cast photos...`);
    
    for (const castMember of top10Cast) {
      if (!castMember.profile_path) {
        console.log(`[DOWNLOAD] Skipping cast member ${castMember.name} - no profile_path`);
        continue;
      }
      
      const personId = castMember.id.toString();
      const castPhotoPath = `cast/${personId}.jpg`;
      
      // Check if already exists
      const exists = await fileExists(castPhotoPath);
      if (exists) {
        // Use existing URL
        const existingUrl = `${STORAGE_BASE_URL}/${castPhotoPath}`;
        storageUrls.castPhotos.set(personId, existingUrl);
        console.log(`[STORAGE] Using existing cast photo: ${castPhotoPath}`);
        continue;
      }
      
      // Download and upload
      const castPhotoUrl = buildImageUrl(castMember.profile_path, 'w185');
      console.log(`[DOWNLOAD] Downloading cast photo for ${castMember.name} from: ${castPhotoUrl}`);
      
      const castPhotoData = await downloadImage(castPhotoUrl);
      if (castPhotoData) {
        console.log(`[DOWNLOAD] Downloaded cast photo for ${castMember.name}, size: ${castPhotoData.byteLength} bytes`);
        
        const storageUrl = await uploadImageToStorage(castPhotoData, castPhotoPath);
        if (storageUrl) {
          storageUrls.castPhotos.set(personId, storageUrl);
          console.log(`[STORAGE] Cast photo URL for ${castMember.name}: ${storageUrl}`);
        }
      } else {
        console.warn(`[DOWNLOAD] Failed to download cast photo for ${castMember.name}`);
      }
    }
    
    console.log(`[STORAGE] Image upload complete. Uploaded ${storageUrls.castPhotos.size} cast photos.`);
    
    // Build cast array (top 15) with storage URLs
    const castMembers = credits.cast.slice(0, 15).map(c => {
      const storageUrl = storageUrls.castPhotos.get(c.id.toString());
      return {
        person_id: c.id.toString(),
        name: c.name,
        character: c.character,
        order: c.order,
        photo_url_small: storageUrl || buildImageUrl(c.profile_path, 'w92'),
        photo_url_medium: storageUrl || buildImageUrl(c.profile_path, 'w185'),
        photo_url_large: storageUrl || buildImageUrl(c.profile_path, 'h632'),
        gender: c.gender === 1 ? 'female' : c.gender === 2 ? 'male' : 'unknown',
      };
    });
    
    // Build crew array (key roles only) with storage URLs
    const keyRoles = ['Director', 'Writer', 'Screenplay', 'Producer', 'Director of Photography', 'Original Music Composer'];
    const crewMembers = credits.crew
      .filter(c => keyRoles.includes(c.job))
      .slice(0, 10)
      .map(c => {
        const storageUrl = storageUrls.castPhotos.get(c.id.toString());
        return {
          person_id: c.id.toString(),
          name: c.name,
          job: c.job,
          department: c.department,
          photo_url_small: storageUrl || buildImageUrl(c.profile_path, 'w92'),
          photo_url_medium: storageUrl || buildImageUrl(c.profile_path, 'w185'),
        };
      });
    
    console.log(`[DATABASE] Updating works_meta with storage URLs...`);
    
    // Upsert into works_meta table with storage URLs
    const metaData = {
      work_id: work.work_id,
      runtime_minutes: details.runtime || null,
      runtime_display: formatRuntime(details.runtime),
      tagline: details.tagline || null,
      overview: details.overview || null,
      overview_short: details.overview ? (details.overview.substring(0, 150) + (details.overview.length > 150 ? '...' : '')) : null,
      genres: details.genres.map(g => g.name),
      // Use storage URLs if available, fallback to TMDB URLs
      poster_url_small: buildImageUrl(details.poster_path, 'w154'), // Keep small as TMDB for now
      poster_url_medium: storageUrls.posterMedium || buildImageUrl(details.poster_path, 'w342'),
      poster_url_large: storageUrls.posterLarge || buildImageUrl(details.poster_path, 'w500'),
      poster_url_original: buildImageUrl(details.poster_path, 'original'), // Keep original as TMDB
      backdrop_url: storageUrls.backdrop || buildImageUrl(details.backdrop_path, 'w1280'),
      backdrop_url_mobile: storageUrls.backdrop || buildImageUrl(details.backdrop_path, 'w780'),
      trailer_youtube_id: trailer?.key || null,
      trailer_thumbnail: storageUrls.trailerThumb || null,
      cast_members: castMembers,
      crew_members: crewMembers,
      fetched_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    
    const { error: metaError } = await supabaseAdmin
      .from('works_meta')
      .upsert(metaData, { onConflict: 'work_id' });
    
    if (metaError) {
      console.error(`[DATABASE] Error updating works_meta:`, metaError);
      throw metaError;
    }
    
    console.log(`[DATABASE] Updated works_meta successfully`);
    
    // Insert TMDB rating
    const { error: ratingError } = await supabaseAdmin
      .from('rating_sources')
      .upsert({
        work_id: work.work_id,
        source_name: 'TMDB',
        scale_type: '0_10',
        value_raw: details.vote_average,
        value_0_100: details.vote_average * 10,
        votes_count: details.vote_count,
        last_seen_at: new Date().toISOString(),
      }, { onConflict: 'work_id,source_name' });
    
    if (ratingError) throw ratingError;
    
    // Compute AI Score (for now, just use TMDB; expand later)
    const aiScore = details.vote_average * 10;
    
    const { error: aggregateError } = await supabaseAdmin
      .from('aggregates')
      .upsert({
        work_id: work.work_id,
        method_version: 'v1_2025_11',
        n_audience: 1,
        audience_score: aiScore,
        ai_score: aiScore,
        ai_score_low: Math.max(0, aiScore - 5),
        ai_score_high: Math.min(100, aiScore + 5),
        source_scores: {
          tmdb: { score: aiScore, votes: details.vote_count }
        },
        computed_at: new Date().toISOString(),
      }, { onConflict: 'work_id,method_version' });
    
    if (aggregateError) throw aggregateError;
    
    console.log(`[CACHE] Building movie card...`);
    
    // Build and cache movie card with storage URLs
    const movieCard = {
      work_id: work.work_id,
      tmdb_id: tmdb_id.toString(),
      imdb_id: details.imdb_id || null,
      title: details.title,
      original_title: details.original_title,
      year: year,
      release_date: details.release_date || null,
      runtime_minutes: details.runtime || null,
      runtime_display: formatRuntime(details.runtime),
      tagline: details.tagline || null,
      overview: details.overview || null,
      overview_short: metaData.overview_short,
      genres: metaData.genres,
      poster: {
        small: metaData.poster_url_small,
        medium: metaData.poster_url_medium,
        large: metaData.poster_url_large,
      },
      backdrop: metaData.backdrop_url,
      trailer_youtube_id: metaData.trailer_youtube_id,
      trailer_thumbnail: metaData.trailer_thumbnail,
      cast: castMembers.slice(0, 8), // Top 8 for card, with storage URLs
      director: crewMembers.find(c => c.job === 'Director')?.name || null,
      ai_score: aiScore,
      ai_score_range: [Math.max(0, aiScore - 5), Math.min(100, aiScore + 5)],
      source_scores: {
        tmdb: { score: aiScore, votes: details.vote_count }
      },
      last_updated: new Date().toISOString(),
    };
    
    const { error: cacheError } = await supabaseAdmin
      .from('work_cards_cache')
      .upsert({
        work_id: work.work_id,
        payload: movieCard,
        payload_short: {
          work_id: work.work_id,
          title: details.title,
          year: year,
          poster: metaData.poster_url_medium,
          ai_score: aiScore,
        },
        etag: btoa(JSON.stringify({ work_id: work.work_id, updated: Date.now() })),
        computed_at: new Date().toISOString(),
      }, { onConflict: 'work_id' });
    
    if (cacheError) {
      console.error(`[CACHE] Error caching movie card:`, cacheError);
      throw cacheError;
    }
    
    console.log(`[INGEST] Ingestion complete for work_id: ${work.work_id}`);
    
    return new Response(
      JSON.stringify({
        status: 'ingested',
        work_id: work.work_id,
        card: movieCard,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('[INGEST] Ingestion error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
