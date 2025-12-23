//  supabase.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: Supabase client for dashboard

import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || ''
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

export interface VoiceEvent {
  id: string
  user_id: string
  created_at: string
  utterance: string
  handler_result: string | null
  llm_used: boolean
  confidence_score: number | null
  intent: string | null
  extracted_hints: any
  mango_command: any
  llm_intent: any
  llm_error: any
}

export interface TMDBAPILog {
  id: number
  created_at: string
  endpoint: string
  method: string
  http_status: number | null
  query_params: any
  request_body: any
  response_size_bytes: number | null
  response_time_ms: number
  results_count: number | null
  edge_function: string | null
  user_query: string | null
  tmdb_id: string | null
  voice_event_id: string | null
  error_message: string | null
  retry_count: number
  metadata: any
}

export interface Movie {
  work_id: number
  tmdb_id: string
  imdb_id: string | null
  title: string
  original_title: string | null
  year: number | null
  release_date: string | null
  ingestion_status: string
  created_at: string
  updated_at: string
  last_refreshed_at: string | null
}
