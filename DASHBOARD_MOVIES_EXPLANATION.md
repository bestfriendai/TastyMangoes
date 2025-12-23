# Why Movies Don't Show Up on Dashboard

## Current Dashboard State

The dashboard (`src/app/page.tsx`) currently only shows:
1. **Voice Events** tab - displays `voice_utterance_events` table
2. **Pattern Suggestions** tab - displays `voice_pattern_suggestions` table

## What Happens When Movies Are Ingested

When movies are ingested (via voice search or scheduled ingest):
1. Movies are inserted/updated in the `works` table
2. Metadata is added to `works_meta` table
3. Cast/crew added to `works_cast` table
4. Ratings added to `works_ratings` table
5. **BUT**: None of this appears on the dashboard because there's no "Movies" tab

## Solution

We need to add:
1. **TMDB Analytics** tab - Shows TMDB API call logs, graphs, endpoint usage
2. **Movies** tab (optional) - Shows ingested movies from `works` table with stats

The TMDB Analytics tab will show:
- Total API calls made
- Calls by endpoint type (`/search/movie`, `/movie/{id}`, etc.)
- Response times, error rates
- Calls over time (graphs)
- Link calls to voice events/user queries

This will answer your question: "How many TMDB calls were made for 'Lord of the Rings'?" and show all the details.
