// capture-google-streaming/index.ts
// Created automatically by Cursor Assistant
// Created on: 2025-12-21 (America/Los_Angeles - Pacific Time)
// Notes: Edge Function to receive and process Google streaming availability data captured from iOS app

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

interface GoogleStreamingProvider {
  provider_name: string;
  availability_type: 'free' | 'subscription' | 'subscription_addon' | 'primetime_subscription';
  availability_text: string;
  provider_logo_url?: string;
  raw_data?: any;
}

interface CaptureRequest {
  tmdb_id: number;
  movie_title: string;
  movie_year?: number;
  work_id?: number;
  providers: GoogleStreamingProvider[];
  user_id?: string;
}

// Provider name mapping to TMDB provider IDs
// Common streaming services and their TMDB IDs
const PROVIDER_NAME_TO_ID: Record<string, number> = {
  'netflix': 8,
  'amazon prime video': 9,
  'disney plus': 337,
  'disney+': 337,
  'hbo max': 31,
  'hbo': 31,
  'max': 31,
  'hulu': 15,
  'paramount plus': 531,
  'paramount+': 531,
  'paramount': 531,
  'apple tv': 350,
  'apple tv+': 350,
  'peacock': 386,
  'peacock premium': 386,
  'youtube': 192,
  'youtube tv': 192,
  'youtube primetime': 192,
  'showtime': 37,
  'starz': 318,
  'starzplay': 318,
  'amc+': 528,
  'amc plus': 528,
  'mgm+': 283,
  'mgm plus': 283,
  'fubo tv': 257,
  'fubotv': 257,
  'sling tv': 227,
  'philo': 270,
  'pluto tv': 300,
  'tubi': 283,
  'crackle': 12,
  'vudu': 7,
  'google play movies & tv': 3,
  'google play': 3,
  'fandango at home': 105,
  'fandango': 105,
  'vudu': 7,
  'microsoft store': 68,
  'redbox': 283,
  'cinemax': 359,
  'epix': 283,
  'fx': 283,
  'tnt': 283,
  'tbs': 283,
};

function normalizeProviderName(name: string): string {
  return name.toLowerCase().trim();
}

function matchProviderToTMDB(providerName: string): number | null {
  const normalized = normalizeProviderName(providerName);
  
  // Direct match
  if (PROVIDER_NAME_TO_ID[normalized]) {
    return PROVIDER_NAME_TO_ID[normalized];
  }
  
  // Partial matches
  for (const [key, id] of Object.entries(PROVIDER_NAME_TO_ID)) {
    if (normalized.includes(key) || key.includes(normalized)) {
      return id;
    }
  }
  
  return null;
}

function parseAvailabilityType(availabilityText: string): 'free' | 'subscription' | 'subscription_addon' | 'primetime_subscription' {
  const text = availabilityText.toLowerCase();
  
  if (text.includes('free')) {
    return 'free';
  }
  
  if (text.includes('primetime')) {
    return 'primetime_subscription';
  }
  
  if (text.includes('add-on') || text.includes('addon') || text.includes('requires add-on')) {
    return 'subscription_addon';
  }
  
  if (text.includes('subscription')) {
    return 'subscription';
  }
  
  // Default to subscription if unclear
  return 'subscription';
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    
    const body: CaptureRequest = await req.json();
    const { tmdb_id, movie_title, movie_year, work_id, providers, user_id } = body;

    if (!tmdb_id || !movie_title || !providers || providers.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: tmdb_id, movie_title, providers' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Find work_id if not provided
    let finalWorkId = work_id;
    if (!finalWorkId) {
      const { data: work } = await supabaseAdmin
        .from('works')
        .select('id')
        .eq('tmdb_id', tmdb_id.toString())
        .limit(1)
        .single();
      
      if (work) {
        finalWorkId = work.id;
      }
    }

    const captures = [];
    const now = new Date().toISOString();

    for (const provider of providers) {
      // Match provider to TMDB ID
      const providerId = matchProviderToTMDB(provider.provider_name);
      
      // Determine availability type
      const availabilityType = parseAvailabilityType(provider.availability_text);

      const capture = {
        work_id: finalWorkId || null,
        tmdb_id: tmdb_id,
        movie_title: movie_title,
        movie_year: movie_year || null,
        provider_name: provider.provider_name,
        provider_id: providerId,
        provider_logo_url: provider.provider_logo_url || null,
        availability_type: availabilityType,
        availability_text: provider.availability_text,
        captured_at: now,
        captured_by: user_id || null,
        source: 'google',
        last_verified_at: now,
        is_stale: false,
        stale_since: null,
        raw_data: provider.raw_data || null,
      };

      captures.push(capture);
    }

    // Insert captures (using upsert to handle duplicates gracefully)
    const { data, error } = await supabaseAdmin
      .from('google_streaming_captures')
      .insert(captures)
      .select();

    if (error) {
      console.error('Error inserting captures:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to save captures', details: error.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const matchedCount = captures.filter(c => c.provider_id !== null).length;
    const unmatchedCount = captures.length - matchedCount;

    return new Response(
      JSON.stringify({
        success: true,
        captures_saved: data?.length || 0,
        matched_providers: matchedCount,
        unmatched_providers: unmatchedCount,
        work_id: finalWorkId,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    console.error('Error processing capture:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

