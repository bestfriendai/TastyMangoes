create extension if not exists "pg_cron" with schema "pg_catalog";

drop extension if exists "pg_net";

create sequence "public"."buzz_signals_buzz_id_seq";

create sequence "public"."cron_canary_id_seq";

create sequence "public"."google_streaming_captures_id_seq";

create sequence "public"."prime_catalog_captures_id_seq";

create sequence "public"."rating_sources_rating_id_seq";

create sequence "public"."review_excerpts_excerpt_id_seq";

create sequence "public"."streaming_announcements_raw_id_seq";

create sequence "public"."streaming_changes_id_seq";

create sequence "public"."streaming_scrape_log_id_seq";

create sequence "public"."streaming_sources_id_seq";

create sequence "public"."user_captures_capture_id_seq";

create sequence "public"."user_imports_import_id_seq";

drop policy "Service role can manage cron_settings" on "public"."cron_settings";

drop policy "Service role can manage refresh_queue" on "public"."refresh_queue";

drop policy "Users can read refresh_queue" on "public"."refresh_queue";

drop policy "Service role can manage sync_state" on "public"."sync_state";

drop policy "Users can read sync_state" on "public"."sync_state";

drop policy "Users can delete their own ratings" on "public"."user_ratings";

drop policy "Users can insert their own ratings" on "public"."user_ratings";

drop policy "Users can update their own ratings" on "public"."user_ratings";

drop policy "Users can view own voice events" on "public"."voice_utterance_events";

drop policy "Service role can manage works" on "public"."works";

drop policy "Users can read works" on "public"."works";

revoke delete on table "public"."cron_settings" from "anon";

revoke insert on table "public"."cron_settings" from "anon";

revoke references on table "public"."cron_settings" from "anon";

revoke select on table "public"."cron_settings" from "anon";

revoke trigger on table "public"."cron_settings" from "anon";

revoke truncate on table "public"."cron_settings" from "anon";

revoke update on table "public"."cron_settings" from "anon";

revoke delete on table "public"."cron_settings" from "authenticated";

revoke insert on table "public"."cron_settings" from "authenticated";

revoke references on table "public"."cron_settings" from "authenticated";

revoke select on table "public"."cron_settings" from "authenticated";

revoke trigger on table "public"."cron_settings" from "authenticated";

revoke truncate on table "public"."cron_settings" from "authenticated";

revoke update on table "public"."cron_settings" from "authenticated";

revoke delete on table "public"."cron_settings" from "service_role";

revoke insert on table "public"."cron_settings" from "service_role";

revoke references on table "public"."cron_settings" from "service_role";

revoke select on table "public"."cron_settings" from "service_role";

revoke trigger on table "public"."cron_settings" from "service_role";

revoke truncate on table "public"."cron_settings" from "service_role";

revoke update on table "public"."cron_settings" from "service_role";

revoke delete on table "public"."refresh_queue" from "anon";

revoke insert on table "public"."refresh_queue" from "anon";

revoke references on table "public"."refresh_queue" from "anon";

revoke select on table "public"."refresh_queue" from "anon";

revoke trigger on table "public"."refresh_queue" from "anon";

revoke truncate on table "public"."refresh_queue" from "anon";

revoke update on table "public"."refresh_queue" from "anon";

revoke delete on table "public"."refresh_queue" from "authenticated";

revoke insert on table "public"."refresh_queue" from "authenticated";

revoke references on table "public"."refresh_queue" from "authenticated";

revoke select on table "public"."refresh_queue" from "authenticated";

revoke trigger on table "public"."refresh_queue" from "authenticated";

revoke truncate on table "public"."refresh_queue" from "authenticated";

revoke update on table "public"."refresh_queue" from "authenticated";

revoke delete on table "public"."refresh_queue" from "service_role";

revoke insert on table "public"."refresh_queue" from "service_role";

revoke references on table "public"."refresh_queue" from "service_role";

revoke select on table "public"."refresh_queue" from "service_role";

revoke trigger on table "public"."refresh_queue" from "service_role";

revoke truncate on table "public"."refresh_queue" from "service_role";

revoke update on table "public"."refresh_queue" from "service_role";

revoke delete on table "public"."sync_state" from "anon";

revoke insert on table "public"."sync_state" from "anon";

revoke references on table "public"."sync_state" from "anon";

revoke select on table "public"."sync_state" from "anon";

revoke trigger on table "public"."sync_state" from "anon";

revoke truncate on table "public"."sync_state" from "anon";

revoke update on table "public"."sync_state" from "anon";

revoke delete on table "public"."sync_state" from "authenticated";

revoke insert on table "public"."sync_state" from "authenticated";

revoke references on table "public"."sync_state" from "authenticated";

revoke select on table "public"."sync_state" from "authenticated";

revoke trigger on table "public"."sync_state" from "authenticated";

revoke truncate on table "public"."sync_state" from "authenticated";

revoke update on table "public"."sync_state" from "authenticated";

revoke delete on table "public"."sync_state" from "service_role";

revoke insert on table "public"."sync_state" from "service_role";

revoke references on table "public"."sync_state" from "service_role";

revoke select on table "public"."sync_state" from "service_role";

revoke trigger on table "public"."sync_state" from "service_role";

revoke truncate on table "public"."sync_state" from "service_role";

revoke update on table "public"."sync_state" from "service_role";

alter table "public"."refresh_queue" drop constraint "refresh_queue_status_check";

alter table "public"."refresh_queue" drop constraint "refresh_queue_work_id_fkey";

alter table "public"."refresh_queue" drop constraint "refresh_queue_work_id_key";

alter table "public"."scheduled_ingestion_log" drop constraint "scheduled_ingestion_log_trigger_type_check";

alter table "public"."user_ratings" drop constraint "user_ratings_feedback_source_check";

drop function if exists "public"."call_daily_refresh"();

drop function if exists "public"."call_refresh_worker"();

drop function if exists "public"."call_scheduled_ingest"(source_param text, max_movies_param integer, trigger_type_param text);

drop function if exists "public"."get_cron_setting"(setting_key_param text);

drop function if exists "public"."get_stale_movies"(limit_count integer);

drop function if exists "public"."get_supabase_url"();

drop view if exists "public"."voice_events_view";

alter table "public"."cron_settings" drop constraint "cron_settings_pkey";

alter table "public"."refresh_queue" drop constraint "refresh_queue_pkey";

alter table "public"."sync_state" drop constraint "sync_state_pkey";

drop index if exists "public"."cron_settings_pkey";

drop index if exists "public"."idx_refresh_queue_queued_at";

drop index if exists "public"."idx_refresh_queue_status_priority_queued";

drop index if exists "public"."idx_refresh_queue_work_id";

drop index if exists "public"."idx_user_ratings_feedback_source";

drop index if exists "public"."idx_voice_utterance_events_created_at";

drop index if exists "public"."idx_voice_utterance_events_handler_result";

drop index if exists "public"."idx_voice_utterance_events_llm_used";

drop index if exists "public"."idx_voice_utterance_events_user_id";

drop index if exists "public"."refresh_queue_pkey";

drop index if exists "public"."refresh_queue_work_id_key";

drop index if exists "public"."sync_state_pkey";

drop table "public"."cron_settings";

drop table "public"."refresh_queue";

drop table "public"."sync_state";


  create table "public"."aggregates" (
    "work_id" bigint not null,
    "method_version" text not null,
    "n_critics" integer default 0,
    "n_audience" integer default 0,
    "n_excerpts" integer default 0,
    "n_buzz_sources" integer default 0,
    "critics_score" real,
    "audience_score" real,
    "sentiment_score" real,
    "buzz_score" real,
    "ai_score" real,
    "ai_score_low" real,
    "ai_score_high" real,
    "source_scores" jsonb,
    "inputs_fingerprint" text,
    "computed_at" timestamp with time zone default now()
      );


alter table "public"."aggregates" enable row level security;


  create table "public"."ai_discovery_requests" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid,
    "query" text not null,
    "hints" jsonb,
    "movies_found" integer default 0,
    "movies_ingested" integer default 0,
    "prompt_tokens" integer default 0,
    "completion_tokens" integer default 0,
    "total_tokens" integer generated always as ((prompt_tokens + completion_tokens)) stored,
    "cost_cents" numeric(10,4) default 0,
    "response_time_ms" integer,
    "status" text default 'success'::text,
    "error_message" text,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."ai_discovery_requests" enable row level security;


  create table "public"."buzz_signals" (
    "buzz_id" bigint not null default nextval('public.buzz_signals_buzz_id_seq'::regclass),
    "work_id" bigint,
    "source_name" text not null,
    "metric_name" text not null,
    "value_0_100" real not null,
    "sample_size" integer,
    "collected_at" timestamp with time zone default now()
      );


alter table "public"."buzz_signals" enable row level security;


  create table "public"."comprehensive_searches" (
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone default now(),
    "search_type" text not null,
    "search_value" text not null,
    "normalized_value" text not null,
    "movies_found" integer default 0,
    "tmdb_ids" text[],
    "last_searched" timestamp with time zone default now()
      );


alter table "public"."comprehensive_searches" enable row level security;


  create table "public"."cron_canary" (
    "id" bigint not null default nextval('public.cron_canary_id_seq'::regclass),
    "ran_at" timestamp with time zone default now()
      );



  create table "public"."events" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid,
    "session_id" uuid,
    "event_type" text not null,
    "properties" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."events" enable row level security;


  create table "public"."google_streaming_captures" (
    "id" bigint not null default nextval('public.google_streaming_captures_id_seq'::regclass),
    "work_id" bigint,
    "tmdb_id" integer not null,
    "movie_title" text not null,
    "movie_year" integer,
    "provider_name" text not null,
    "provider_id" integer,
    "provider_logo_url" text,
    "availability_type" text not null,
    "availability_text" text,
    "captured_at" timestamp with time zone not null default now(),
    "captured_by" uuid,
    "source" text default 'google'::text,
    "last_verified_at" timestamp with time zone,
    "is_stale" boolean default false,
    "stale_since" timestamp with time zone,
    "raw_data" jsonb
      );



  create table "public"."prime_catalog_captures" (
    "id" bigint not null default nextval('public.prime_catalog_captures_id_seq'::regclass),
    "title" text not null,
    "year" integer,
    "runtime" text,
    "leaving_text" text,
    "leaving_date" date,
    "asin" text,
    "amazon_rating" text,
    "imdb_rating" text,
    "content_rating" text,
    "genres" text[],
    "included_with_prime" boolean default true,
    "poster_url" text,
    "description" text,
    "cast_members" text[],
    "source_url" text,
    "tmdb_id" text,
    "work_id" bigint,
    "match_confidence" integer,
    "match_method" text,
    "collector_id" text,
    "captured_at" timestamp with time zone not null,
    "imported_at" timestamp with time zone default now(),
    "collector_version" text,
    "browser_info" jsonb,
    "raw_title" text
      );



  create table "public"."rating_sources" (
    "rating_id" bigint not null default nextval('public.rating_sources_rating_id_seq'::regclass),
    "work_id" bigint,
    "source_name" text not null,
    "scale_type" text not null,
    "value_raw" real not null,
    "value_0_100" real not null,
    "votes_count" integer,
    "last_seen_at" timestamp with time zone default now()
      );


alter table "public"."rating_sources" enable row level security;


  create table "public"."review_excerpts" (
    "excerpt_id" bigint not null default nextval('public.review_excerpts_excerpt_id_seq'::regclass),
    "work_id" bigint,
    "source_name" text,
    "url" text,
    "excerpt_text" text not null,
    "language" text default 'en'::text,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."review_excerpts" enable row level security;


  create table "public"."review_sentiment" (
    "excerpt_id" bigint not null,
    "sentiment_0_100" real not null,
    "strength_0_1" real,
    "aspects" jsonb,
    "model_version" text not null,
    "inferred_at" timestamp with time zone default now()
      );


alter table "public"."review_sentiment" enable row level security;


  create table "public"."similar_movies" (
    "id" uuid not null default gen_random_uuid(),
    "work_id" bigint,
    "similar_work_id" bigint,
    "similar_tmdb_id" text not null,
    "source" text not null,
    "source_url" text,
    "rank_order" integer,
    "confidence" real,
    "notes" text,
    "created_at" timestamp with time zone default now()
      );



  create table "public"."streaming_announcements_raw" (
    "id" bigint not null default nextval('public.streaming_announcements_raw_id_seq'::regclass),
    "source_id" integer,
    "provider_name" text not null,
    "movie_title_raw" text not null,
    "movie_year_raw" integer,
    "change_type" text not null,
    "effective_date" date,
    "date_precision" text default 'exact'::text,
    "country_code" text default 'US'::text,
    "tmdb_id" text,
    "work_id" bigint,
    "match_method" text,
    "match_confidence" integer,
    "match_notes" text,
    "source_url" text,
    "article_title" text,
    "article_date" date,
    "scraped_at" timestamp with time zone default now(),
    "raw_text" text,
    "processed" boolean default false,
    "processed_at" timestamp with time zone,
    "processing_error" text,
    "announcement_hash" text,
    "duplicate_of" bigint
      );



  create table "public"."streaming_changes" (
    "id" bigint not null default nextval('public.streaming_changes_id_seq'::regclass),
    "work_id" bigint,
    "tmdb_id" text not null,
    "provider_id" integer,
    "provider_name" text not null,
    "change_type" text not null,
    "effective_date" date,
    "country_code" text default 'US'::text,
    "confidence_score" integer not null,
    "confidence_breakdown" jsonb,
    "source_count" integer not null default 1,
    "source_ids" integer[],
    "primary_source_id" integer,
    "first_reported_at" timestamp with time zone default now(),
    "verified_at" timestamp with time zone,
    "verified_method" text,
    "status" text default 'pending'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );



  create table "public"."streaming_scrape_log" (
    "id" bigint not null default nextval('public.streaming_scrape_log_id_seq'::regclass),
    "source_id" integer,
    "started_at" timestamp with time zone default now(),
    "completed_at" timestamp with time zone,
    "status" text not null,
    "items_found" integer default 0,
    "items_new" integer default 0,
    "items_duplicate" integer default 0,
    "items_matched" integer default 0,
    "items_unmatched" integer default 0,
    "error_message" text,
    "error_details" jsonb,
    "request_duration_ms" integer,
    "response_size_bytes" integer
      );



  create table "public"."streaming_sources" (
    "id" integer not null default nextval('public.streaming_sources_id_seq'::regclass),
    "name" text not null,
    "domain" text not null,
    "source_type" text not null,
    "tier" integer not null,
    "providers_covered" text[] not null default '{}'::text[],
    "scrape_method" text,
    "scrape_url" text,
    "scrape_selector" text,
    "scrape_frequency" text default 'daily'::text,
    "last_scraped_at" timestamp with time zone,
    "last_scrape_status" text,
    "last_scrape_error" text,
    "reliability_score" integer default 50,
    "total_reports" integer default 0,
    "confirmed_reports" integer default 0,
    "false_positives" integer default 0,
    "active" boolean default true,
    "notes" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );



  create table "public"."user_captures" (
    "capture_id" bigint not null default nextval('public.user_captures_capture_id_seq'::regclass),
    "user_id" uuid,
    "raw_input" text not null,
    "source" text,
    "recommender_name" text,
    "matched_work_id" bigint,
    "match_confidence" real,
    "status" text default 'pending'::text,
    "created_at" timestamp with time zone default now(),
    "resolved_at" timestamp with time zone
      );


alter table "public"."user_captures" enable row level security;


  create table "public"."user_imports" (
    "import_id" bigint not null default nextval('public.user_imports_import_id_seq'::regclass),
    "user_id" uuid,
    "raw_text" text not null,
    "source" text,
    "parsed_items" jsonb,
    "matched_count" integer default 0,
    "unmatched_count" integer default 0,
    "cleaned_text" text,
    "created_at" timestamp with time zone default now(),
    "processed_at" timestamp with time zone
      );


alter table "public"."user_imports" enable row level security;


  create table "public"."voice_pattern_suggestions" (
    "id" uuid not null default gen_random_uuid(),
    "utterance" text not null,
    "original_command_type" text,
    "suggested_intent" text,
    "suggested_pattern" text,
    "confidence" double precision,
    "source" text default 'llm'::text,
    "status" text default 'pending'::text,
    "reviewed_at" timestamp with time zone,
    "reviewed_by" text,
    "implementation_notes" text,
    "voice_event_id" uuid,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."voice_pattern_suggestions" enable row level security;


  create table "public"."work_cards_cache" (
    "work_id" bigint not null,
    "payload" jsonb not null,
    "payload_short" jsonb,
    "etag" text,
    "computed_at" timestamp with time zone default now()
      );


alter table "public"."work_cards_cache" enable row level security;


  create table "public"."works_meta" (
    "work_id" bigint not null,
    "runtime_minutes" integer,
    "runtime_display" text,
    "tagline" text,
    "overview" text,
    "overview_short" text,
    "keywords" text[],
    "genres" text[],
    "subgenres" text[],
    "moods" text[],
    "themes" text[],
    "certification" text,
    "certification_reason" text,
    "content_warnings" text[],
    "poster_url_small" text,
    "poster_url_medium" text,
    "poster_url_large" text,
    "poster_url_original" text,
    "backdrop_url" text,
    "backdrop_url_mobile" text,
    "logo_url" text,
    "still_images" jsonb,
    "cast_members" jsonb,
    "crew_members" jsonb,
    "trailer_youtube_id" text,
    "trailer_thumbnail" text,
    "trailer_duration" integer,
    "trailers" jsonb,
    "aspect_ratio" text,
    "color" text,
    "sound_mix" text[],
    "imax_available" boolean default false,
    "dolby_cinema" boolean default false,
    "dolby_atmos" boolean default false,
    "dolby_vision" boolean default false,
    "filming_locations" text[],
    "production_companies" jsonb,
    "production_countries" text[],
    "spoken_languages" text[],
    "original_language" text,
    "budget" bigint,
    "budget_display" text,
    "revenue_worldwide" bigint,
    "revenue_display" text,
    "opening_weekend_us" bigint,
    "awards" jsonb,
    "streaming" jsonb,
    "collection" jsonb,
    "similar_movies" jsonb,
    "fetched_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "similar_movie_ids" integer[],
    "schema_version" integer default 1
      );


alter table "public"."works_meta" enable row level security;

alter table "public"."profiles" add column "display_name" text;

alter table "public"."profiles" add column "email" text;

alter table "public"."scheduled_ingestion_log" add column "error_message" text;

alter table "public"."scheduled_ingestion_log" add column "run_at" timestamp with time zone default now();

alter table "public"."scheduled_ingestion_log" alter column "duration_ms" drop not null;

alter table "public"."scheduled_ingestion_log" alter column "failed_titles" set data type jsonb using "failed_titles"::jsonb;

alter table "public"."scheduled_ingestion_log" alter column "id" set default gen_random_uuid();

alter table "public"."scheduled_ingestion_log" alter column "id" set data type uuid using "id"::uuid;

alter table "public"."scheduled_ingestion_log" alter column "ingested_titles" set data type jsonb using "ingested_titles"::jsonb;

alter table "public"."scheduled_ingestion_log" alter column "movies_checked" set default 0;

alter table "public"."scheduled_ingestion_log" alter column "movies_checked" drop not null;

alter table "public"."scheduled_ingestion_log" alter column "movies_failed" set default 0;

alter table "public"."scheduled_ingestion_log" alter column "movies_failed" drop not null;

alter table "public"."scheduled_ingestion_log" alter column "movies_ingested" set default 0;

alter table "public"."scheduled_ingestion_log" alter column "movies_ingested" drop not null;

alter table "public"."scheduled_ingestion_log" alter column "movies_skipped" set default 0;

alter table "public"."scheduled_ingestion_log" alter column "movies_skipped" drop not null;

alter table "public"."scheduled_ingestion_log" alter column "trigger_type" set default 'scheduled'::text;

alter table "public"."scheduled_ingestion_log" alter column "trigger_type" drop not null;

alter table "public"."tmdb_api_logs" add column "status_code" integer;

alter table "public"."tmdb_api_logs" alter column "created_at" drop not null;

alter table "public"."tmdb_api_logs" alter column "id" set default gen_random_uuid();

alter table "public"."tmdb_api_logs" alter column "id" set data type uuid using "id"::uuid;

alter table "public"."tmdb_api_logs" alter column "response_time_ms" drop default;

alter table "public"."tmdb_api_logs" alter column "response_time_ms" drop not null;

alter table "public"."user_ratings" alter column "feedback_source" drop default;

alter table "public"."voice_utterance_events" add column "candidates_shown" integer;

alter table "public"."voice_utterance_events" add column "clarifying_answer" text;

alter table "public"."voice_utterance_events" add column "clarifying_question_asked" text;

alter table "public"."voice_utterance_events" add column "confidence_score" numeric(3,2);

alter table "public"."voice_utterance_events" add column "extracted_hints" jsonb;

alter table "public"."voice_utterance_events" add column "handoff_initiated" boolean default false;

alter table "public"."voice_utterance_events" add column "handoff_returned" boolean default false;

alter table "public"."voice_utterance_events" add column "search_intent" text;

alter table "public"."voice_utterance_events" add column "selected_movie_id" integer;

alter table "public"."voice_utterance_events" alter column "id" set default gen_random_uuid();

alter table "public"."works" add column "trigger_query" text;

alter table "public"."works" add column "trigger_source" text;

alter table "public"."works" add column "triggered_by_user_id" uuid;

alter sequence "public"."buzz_signals_buzz_id_seq" owned by "public"."buzz_signals"."buzz_id";

alter sequence "public"."cron_canary_id_seq" owned by "public"."cron_canary"."id";

alter sequence "public"."google_streaming_captures_id_seq" owned by "public"."google_streaming_captures"."id";

alter sequence "public"."prime_catalog_captures_id_seq" owned by "public"."prime_catalog_captures"."id";

alter sequence "public"."rating_sources_rating_id_seq" owned by "public"."rating_sources"."rating_id";

alter sequence "public"."review_excerpts_excerpt_id_seq" owned by "public"."review_excerpts"."excerpt_id";

alter sequence "public"."streaming_announcements_raw_id_seq" owned by "public"."streaming_announcements_raw"."id";

alter sequence "public"."streaming_changes_id_seq" owned by "public"."streaming_changes"."id";

alter sequence "public"."streaming_scrape_log_id_seq" owned by "public"."streaming_scrape_log"."id";

alter sequence "public"."streaming_sources_id_seq" owned by "public"."streaming_sources"."id";

alter sequence "public"."user_captures_capture_id_seq" owned by "public"."user_captures"."capture_id";

alter sequence "public"."user_imports_import_id_seq" owned by "public"."user_imports"."import_id";

drop sequence if exists "public"."refresh_queue_id_seq";

drop sequence if exists "public"."scheduled_ingestion_log_id_seq";

drop sequence if exists "public"."tmdb_api_logs_id_seq";

CREATE UNIQUE INDEX aggregates_pkey ON public.aggregates USING btree (work_id, method_version);

CREATE UNIQUE INDEX ai_discovery_requests_pkey ON public.ai_discovery_requests USING btree (id);

CREATE UNIQUE INDEX buzz_signals_pkey ON public.buzz_signals USING btree (buzz_id);

CREATE UNIQUE INDEX comprehensive_searches_pkey ON public.comprehensive_searches USING btree (id);

CREATE UNIQUE INDEX comprehensive_searches_search_type_normalized_value_key ON public.comprehensive_searches USING btree (search_type, normalized_value);

CREATE UNIQUE INDEX cron_canary_pkey ON public.cron_canary USING btree (id);

CREATE UNIQUE INDEX events_pkey ON public.events USING btree (id);

CREATE UNIQUE INDEX google_streaming_captures_pkey ON public.google_streaming_captures USING btree (id);

CREATE INDEX idx_aggregates_ai_score ON public.aggregates USING btree (ai_score);

CREATE INDEX idx_aggregates_work ON public.aggregates USING btree (work_id);

CREATE INDEX idx_ai_discovery_requests_created_at ON public.ai_discovery_requests USING btree (created_at);

CREATE INDEX idx_ai_discovery_requests_user_id ON public.ai_discovery_requests USING btree (user_id);

CREATE INDEX idx_announcements_raw_hash ON public.streaming_announcements_raw USING btree (announcement_hash);

CREATE INDEX idx_announcements_raw_source ON public.streaming_announcements_raw USING btree (source_id, scraped_at);

CREATE INDEX idx_announcements_raw_unprocessed ON public.streaming_announcements_raw USING btree (processed, scraped_at) WHERE (NOT processed);

CREATE INDEX idx_buzz_signals_work ON public.buzz_signals USING btree (work_id);

CREATE INDEX idx_comprehensive_searches_lookup ON public.comprehensive_searches USING btree (search_type, normalized_value);

CREATE INDEX idx_events_created ON public.events USING btree (created_at DESC);

CREATE INDEX idx_events_session ON public.events USING btree (session_id);

CREATE INDEX idx_events_type ON public.events USING btree (event_type);

CREATE INDEX idx_events_user_created ON public.events USING btree (user_id, created_at DESC);

CREATE INDEX idx_events_user_id ON public.events USING btree (user_id);

CREATE INDEX idx_google_streaming_captured ON public.google_streaming_captures USING btree (captured_at DESC);

CREATE INDEX idx_google_streaming_provider ON public.google_streaming_captures USING btree (provider_name);

CREATE INDEX idx_google_streaming_stale ON public.google_streaming_captures USING btree (is_stale, last_verified_at);

CREATE INDEX idx_google_streaming_tmdb ON public.google_streaming_captures USING btree (tmdb_id);

CREATE INDEX idx_google_streaming_work ON public.google_streaming_captures USING btree (work_id) WHERE (work_id IS NOT NULL);

CREATE INDEX idx_prime_catalog_leaving ON public.prime_catalog_captures USING btree (leaving_date) WHERE (leaving_date IS NOT NULL);

CREATE INDEX idx_prime_catalog_tmdb ON public.prime_catalog_captures USING btree (tmdb_id) WHERE (tmdb_id IS NOT NULL);

CREATE INDEX idx_rating_sources_source ON public.rating_sources USING btree (source_name);

CREATE INDEX idx_rating_sources_work ON public.rating_sources USING btree (work_id);

CREATE INDEX idx_review_excerpts_work ON public.review_excerpts USING btree (work_id);

CREATE INDEX idx_scheduled_ingestion_log_run_at ON public.scheduled_ingestion_log USING btree (run_at DESC);

CREATE INDEX idx_scrape_log_source ON public.streaming_scrape_log USING btree (source_id, started_at DESC);

CREATE INDEX idx_similar_movies_similar_work ON public.similar_movies USING btree (similar_work_id);

CREATE INDEX idx_similar_movies_source ON public.similar_movies USING btree (source);

CREATE INDEX idx_similar_movies_tmdb ON public.similar_movies USING btree (similar_tmdb_id);

CREATE INDEX idx_similar_movies_work ON public.similar_movies USING btree (work_id);

CREATE INDEX idx_streaming_changes_confidence ON public.streaming_changes USING btree (confidence_score DESC) WHERE (status = 'pending'::text);

CREATE INDEX idx_streaming_changes_provider ON public.streaming_changes USING btree (provider_name, change_type, effective_date);

CREATE INDEX idx_streaming_changes_status ON public.streaming_changes USING btree (status, effective_date);

CREATE INDEX idx_streaming_changes_work ON public.streaming_changes USING btree (work_id);

CREATE INDEX idx_streaming_sources_active ON public.streaming_sources USING btree (active, tier);

CREATE INDEX idx_tmdb_logs_created ON public.tmdb_api_logs USING btree (created_at DESC);

CREATE INDEX idx_tmdb_logs_endpoint ON public.tmdb_api_logs USING btree (endpoint);

CREATE INDEX idx_user_captures_status ON public.user_captures USING btree (status);

CREATE INDEX idx_user_captures_user ON public.user_captures USING btree (user_id);

CREATE INDEX idx_user_imports_user ON public.user_imports USING btree (user_id);

CREATE INDEX idx_voice_events_created_at ON public.voice_utterance_events USING btree (created_at DESC);

CREATE INDEX idx_voice_events_final_type ON public.voice_utterance_events USING btree (final_command_type);

CREATE INDEX idx_voice_events_handler_result ON public.voice_utterance_events USING btree (handler_result);

CREATE INDEX idx_voice_events_user_id ON public.voice_utterance_events USING btree (user_id);

CREATE INDEX idx_voice_pattern_suggestions_created ON public.voice_pattern_suggestions USING btree (created_at DESC);

CREATE INDEX idx_voice_pattern_suggestions_status ON public.voice_pattern_suggestions USING btree (status);

CREATE INDEX idx_works_meta_schema_version ON public.works_meta USING btree (schema_version);

CREATE INDEX idx_works_meta_similar_movie_ids ON public.works_meta USING gin (similar_movie_ids);

CREATE UNIQUE INDEX prime_catalog_captures_asin_key ON public.prime_catalog_captures USING btree (asin);

CREATE UNIQUE INDEX prime_catalog_captures_pkey ON public.prime_catalog_captures USING btree (id);

CREATE UNIQUE INDEX prime_catalog_captures_title_year_key ON public.prime_catalog_captures USING btree (title, year);

CREATE UNIQUE INDEX rating_sources_pkey ON public.rating_sources USING btree (rating_id);

CREATE UNIQUE INDEX rating_sources_work_id_source_name_key ON public.rating_sources USING btree (work_id, source_name);

CREATE UNIQUE INDEX review_excerpts_pkey ON public.review_excerpts USING btree (excerpt_id);

CREATE UNIQUE INDEX review_sentiment_pkey ON public.review_sentiment USING btree (excerpt_id);

CREATE UNIQUE INDEX similar_movies_pkey ON public.similar_movies USING btree (id);

CREATE UNIQUE INDEX similar_movies_work_id_similar_tmdb_id_source_key ON public.similar_movies USING btree (work_id, similar_tmdb_id, source);

CREATE UNIQUE INDEX streaming_announcements_raw_announcement_hash_key ON public.streaming_announcements_raw USING btree (announcement_hash);

CREATE UNIQUE INDEX streaming_announcements_raw_pkey ON public.streaming_announcements_raw USING btree (id);

CREATE UNIQUE INDEX streaming_changes_pkey ON public.streaming_changes USING btree (id);

CREATE UNIQUE INDEX streaming_changes_tmdb_id_provider_name_change_type_effecti_key ON public.streaming_changes USING btree (tmdb_id, provider_name, change_type, effective_date, country_code);

CREATE UNIQUE INDEX streaming_scrape_log_pkey ON public.streaming_scrape_log USING btree (id);

CREATE UNIQUE INDEX streaming_sources_domain_url_unique ON public.streaming_sources USING btree (domain, scrape_url);

CREATE UNIQUE INDEX streaming_sources_pkey ON public.streaming_sources USING btree (id);

CREATE UNIQUE INDEX unique_capture ON public.google_streaming_captures USING btree (tmdb_id, provider_name, captured_at);

CREATE UNIQUE INDEX user_captures_pkey ON public.user_captures USING btree (capture_id);

CREATE UNIQUE INDEX user_imports_pkey ON public.user_imports USING btree (import_id);

CREATE UNIQUE INDEX voice_pattern_suggestions_pkey ON public.voice_pattern_suggestions USING btree (id);

CREATE UNIQUE INDEX work_cards_cache_pkey ON public.work_cards_cache USING btree (work_id);

CREATE UNIQUE INDEX works_meta_pkey ON public.works_meta USING btree (work_id);

alter table "public"."aggregates" add constraint "aggregates_pkey" PRIMARY KEY using index "aggregates_pkey";

alter table "public"."ai_discovery_requests" add constraint "ai_discovery_requests_pkey" PRIMARY KEY using index "ai_discovery_requests_pkey";

alter table "public"."buzz_signals" add constraint "buzz_signals_pkey" PRIMARY KEY using index "buzz_signals_pkey";

alter table "public"."comprehensive_searches" add constraint "comprehensive_searches_pkey" PRIMARY KEY using index "comprehensive_searches_pkey";

alter table "public"."cron_canary" add constraint "cron_canary_pkey" PRIMARY KEY using index "cron_canary_pkey";

alter table "public"."events" add constraint "events_pkey" PRIMARY KEY using index "events_pkey";

alter table "public"."google_streaming_captures" add constraint "google_streaming_captures_pkey" PRIMARY KEY using index "google_streaming_captures_pkey";

alter table "public"."prime_catalog_captures" add constraint "prime_catalog_captures_pkey" PRIMARY KEY using index "prime_catalog_captures_pkey";

alter table "public"."rating_sources" add constraint "rating_sources_pkey" PRIMARY KEY using index "rating_sources_pkey";

alter table "public"."review_excerpts" add constraint "review_excerpts_pkey" PRIMARY KEY using index "review_excerpts_pkey";

alter table "public"."review_sentiment" add constraint "review_sentiment_pkey" PRIMARY KEY using index "review_sentiment_pkey";

alter table "public"."similar_movies" add constraint "similar_movies_pkey" PRIMARY KEY using index "similar_movies_pkey";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_pkey" PRIMARY KEY using index "streaming_announcements_raw_pkey";

alter table "public"."streaming_changes" add constraint "streaming_changes_pkey" PRIMARY KEY using index "streaming_changes_pkey";

alter table "public"."streaming_scrape_log" add constraint "streaming_scrape_log_pkey" PRIMARY KEY using index "streaming_scrape_log_pkey";

alter table "public"."streaming_sources" add constraint "streaming_sources_pkey" PRIMARY KEY using index "streaming_sources_pkey";

alter table "public"."user_captures" add constraint "user_captures_pkey" PRIMARY KEY using index "user_captures_pkey";

alter table "public"."user_imports" add constraint "user_imports_pkey" PRIMARY KEY using index "user_imports_pkey";

alter table "public"."voice_pattern_suggestions" add constraint "voice_pattern_suggestions_pkey" PRIMARY KEY using index "voice_pattern_suggestions_pkey";

alter table "public"."work_cards_cache" add constraint "work_cards_cache_pkey" PRIMARY KEY using index "work_cards_cache_pkey";

alter table "public"."works_meta" add constraint "works_meta_pkey" PRIMARY KEY using index "works_meta_pkey";

alter table "public"."aggregates" add constraint "aggregates_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."aggregates" validate constraint "aggregates_work_id_fkey";

alter table "public"."ai_discovery_requests" add constraint "ai_discovery_requests_status_check" CHECK ((status = ANY (ARRAY['success'::text, 'error'::text, 'rate_limited'::text, 'over_budget'::text]))) not valid;

alter table "public"."ai_discovery_requests" validate constraint "ai_discovery_requests_status_check";

alter table "public"."ai_discovery_requests" add constraint "ai_discovery_requests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."ai_discovery_requests" validate constraint "ai_discovery_requests_user_id_fkey";

alter table "public"."ai_discovery_requests" add constraint "positive_cost" CHECK ((cost_cents >= (0)::numeric)) not valid;

alter table "public"."ai_discovery_requests" validate constraint "positive_cost";

alter table "public"."ai_discovery_requests" add constraint "positive_tokens" CHECK (((prompt_tokens >= 0) AND (completion_tokens >= 0))) not valid;

alter table "public"."ai_discovery_requests" validate constraint "positive_tokens";

alter table "public"."buzz_signals" add constraint "buzz_signals_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."buzz_signals" validate constraint "buzz_signals_work_id_fkey";

alter table "public"."comprehensive_searches" add constraint "comprehensive_searches_search_type_normalized_value_key" UNIQUE using index "comprehensive_searches_search_type_normalized_value_key";

alter table "public"."events" add constraint "events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) not valid;

alter table "public"."events" validate constraint "events_user_id_fkey";

alter table "public"."google_streaming_captures" add constraint "google_streaming_captures_captured_by_fkey" FOREIGN KEY (captured_by) REFERENCES auth.users(id) not valid;

alter table "public"."google_streaming_captures" validate constraint "google_streaming_captures_captured_by_fkey";

alter table "public"."google_streaming_captures" add constraint "google_streaming_captures_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) not valid;

alter table "public"."google_streaming_captures" validate constraint "google_streaming_captures_work_id_fkey";

alter table "public"."google_streaming_captures" add constraint "unique_capture" UNIQUE using index "unique_capture";

alter table "public"."prime_catalog_captures" add constraint "prime_catalog_captures_asin_key" UNIQUE using index "prime_catalog_captures_asin_key";

alter table "public"."prime_catalog_captures" add constraint "prime_catalog_captures_match_confidence_check" CHECK (((match_confidence >= 0) AND (match_confidence <= 100))) not valid;

alter table "public"."prime_catalog_captures" validate constraint "prime_catalog_captures_match_confidence_check";

alter table "public"."prime_catalog_captures" add constraint "prime_catalog_captures_title_year_key" UNIQUE using index "prime_catalog_captures_title_year_key";

alter table "public"."prime_catalog_captures" add constraint "prime_catalog_captures_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) not valid;

alter table "public"."prime_catalog_captures" validate constraint "prime_catalog_captures_work_id_fkey";

alter table "public"."rating_sources" add constraint "rating_sources_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."rating_sources" validate constraint "rating_sources_work_id_fkey";

alter table "public"."rating_sources" add constraint "rating_sources_work_id_source_name_key" UNIQUE using index "rating_sources_work_id_source_name_key";

alter table "public"."review_excerpts" add constraint "review_excerpts_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."review_excerpts" validate constraint "review_excerpts_work_id_fkey";

alter table "public"."review_sentiment" add constraint "review_sentiment_excerpt_id_fkey" FOREIGN KEY (excerpt_id) REFERENCES public.review_excerpts(excerpt_id) ON DELETE CASCADE not valid;

alter table "public"."review_sentiment" validate constraint "review_sentiment_excerpt_id_fkey";

alter table "public"."similar_movies" add constraint "similar_movies_similar_work_id_fkey" FOREIGN KEY (similar_work_id) REFERENCES public.works(work_id) not valid;

alter table "public"."similar_movies" validate constraint "similar_movies_similar_work_id_fkey";

alter table "public"."similar_movies" add constraint "similar_movies_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) not valid;

alter table "public"."similar_movies" validate constraint "similar_movies_work_id_fkey";

alter table "public"."similar_movies" add constraint "similar_movies_work_id_similar_tmdb_id_source_key" UNIQUE using index "similar_movies_work_id_similar_tmdb_id_source_key";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_announcement_hash_key" UNIQUE using index "streaming_announcements_raw_announcement_hash_key";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_change_type_check" CHECK ((change_type = ANY (ARRAY['arriving'::text, 'leaving'::text]))) not valid;

alter table "public"."streaming_announcements_raw" validate constraint "streaming_announcements_raw_change_type_check";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_date_precision_check" CHECK ((date_precision = ANY (ARRAY['exact'::text, 'week'::text, 'month'::text, 'unknown'::text]))) not valid;

alter table "public"."streaming_announcements_raw" validate constraint "streaming_announcements_raw_date_precision_check";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_duplicate_of_fkey" FOREIGN KEY (duplicate_of) REFERENCES public.streaming_announcements_raw(id) not valid;

alter table "public"."streaming_announcements_raw" validate constraint "streaming_announcements_raw_duplicate_of_fkey";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_match_confidence_check" CHECK (((match_confidence >= 0) AND (match_confidence <= 100))) not valid;

alter table "public"."streaming_announcements_raw" validate constraint "streaming_announcements_raw_match_confidence_check";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_source_id_fkey" FOREIGN KEY (source_id) REFERENCES public.streaming_sources(id) ON DELETE SET NULL not valid;

alter table "public"."streaming_announcements_raw" validate constraint "streaming_announcements_raw_source_id_fkey";

alter table "public"."streaming_announcements_raw" add constraint "streaming_announcements_raw_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE SET NULL not valid;

alter table "public"."streaming_announcements_raw" validate constraint "streaming_announcements_raw_work_id_fkey";

alter table "public"."streaming_changes" add constraint "streaming_changes_change_type_check" CHECK ((change_type = ANY (ARRAY['arriving'::text, 'leaving'::text]))) not valid;

alter table "public"."streaming_changes" validate constraint "streaming_changes_change_type_check";

alter table "public"."streaming_changes" add constraint "streaming_changes_confidence_score_check" CHECK (((confidence_score >= 0) AND (confidence_score <= 100))) not valid;

alter table "public"."streaming_changes" validate constraint "streaming_changes_confidence_score_check";

alter table "public"."streaming_changes" add constraint "streaming_changes_primary_source_id_fkey" FOREIGN KEY (primary_source_id) REFERENCES public.streaming_sources(id) not valid;

alter table "public"."streaming_changes" validate constraint "streaming_changes_primary_source_id_fkey";

alter table "public"."streaming_changes" add constraint "streaming_changes_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'expired'::text, 'false_positive'::text]))) not valid;

alter table "public"."streaming_changes" validate constraint "streaming_changes_status_check";

alter table "public"."streaming_changes" add constraint "streaming_changes_tmdb_id_provider_name_change_type_effecti_key" UNIQUE using index "streaming_changes_tmdb_id_provider_name_change_type_effecti_key";

alter table "public"."streaming_changes" add constraint "streaming_changes_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."streaming_changes" validate constraint "streaming_changes_work_id_fkey";

alter table "public"."streaming_scrape_log" add constraint "streaming_scrape_log_source_id_fkey" FOREIGN KEY (source_id) REFERENCES public.streaming_sources(id) ON DELETE CASCADE not valid;

alter table "public"."streaming_scrape_log" validate constraint "streaming_scrape_log_source_id_fkey";

alter table "public"."streaming_scrape_log" add constraint "streaming_scrape_log_status_check" CHECK ((status = ANY (ARRAY['running'::text, 'success'::text, 'failed'::text, 'partial'::text]))) not valid;

alter table "public"."streaming_scrape_log" validate constraint "streaming_scrape_log_status_check";

alter table "public"."streaming_sources" add constraint "streaming_sources_domain_url_unique" UNIQUE using index "streaming_sources_domain_url_unique";

alter table "public"."streaming_sources" add constraint "streaming_sources_reliability_score_check" CHECK (((reliability_score >= 0) AND (reliability_score <= 100))) not valid;

alter table "public"."streaming_sources" validate constraint "streaming_sources_reliability_score_check";

alter table "public"."streaming_sources" add constraint "streaming_sources_scrape_frequency_check" CHECK ((scrape_frequency = ANY (ARRAY['hourly'::text, 'daily'::text, 'weekly'::text]))) not valid;

alter table "public"."streaming_sources" validate constraint "streaming_sources_scrape_frequency_check";

alter table "public"."streaming_sources" add constraint "streaming_sources_scrape_method_check" CHECK ((scrape_method = ANY (ARRAY['rss'::text, 'api'::text, 'html'::text, 'manual'::text]))) not valid;

alter table "public"."streaming_sources" validate constraint "streaming_sources_scrape_method_check";

alter table "public"."streaming_sources" add constraint "streaming_sources_source_type_check" CHECK ((source_type = ANY (ARRAY['official'::text, 'aggregator'::text, 'dedicated'::text, 'news'::text, 'blog'::text]))) not valid;

alter table "public"."streaming_sources" validate constraint "streaming_sources_source_type_check";

alter table "public"."streaming_sources" add constraint "streaming_sources_tier_check" CHECK (((tier >= 1) AND (tier <= 5))) not valid;

alter table "public"."streaming_sources" validate constraint "streaming_sources_tier_check";

alter table "public"."user_captures" add constraint "user_captures_matched_work_id_fkey" FOREIGN KEY (matched_work_id) REFERENCES public.works(work_id) ON DELETE SET NULL not valid;

alter table "public"."user_captures" validate constraint "user_captures_matched_work_id_fkey";

alter table "public"."user_captures" add constraint "user_captures_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_captures" validate constraint "user_captures_user_id_fkey";

alter table "public"."user_imports" add constraint "user_imports_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_imports" validate constraint "user_imports_user_id_fkey";

alter table "public"."voice_pattern_suggestions" add constraint "voice_pattern_suggestions_source_check" CHECK ((source = ANY (ARRAY['llm'::text, 'manual'::text]))) not valid;

alter table "public"."voice_pattern_suggestions" validate constraint "voice_pattern_suggestions_source_check";

alter table "public"."voice_pattern_suggestions" add constraint "voice_pattern_suggestions_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'implemented'::text]))) not valid;

alter table "public"."voice_pattern_suggestions" validate constraint "voice_pattern_suggestions_status_check";

alter table "public"."voice_pattern_suggestions" add constraint "voice_pattern_suggestions_voice_event_id_fkey" FOREIGN KEY (voice_event_id) REFERENCES public.voice_utterance_events(id) not valid;

alter table "public"."voice_pattern_suggestions" validate constraint "voice_pattern_suggestions_voice_event_id_fkey";

alter table "public"."voice_utterance_events" add constraint "fk_voice_events_user" FOREIGN KEY (user_id) REFERENCES public.profiles(id) not valid;

alter table "public"."voice_utterance_events" validate constraint "fk_voice_events_user";

alter table "public"."work_cards_cache" add constraint "work_cards_cache_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."work_cards_cache" validate constraint "work_cards_cache_work_id_fkey";

alter table "public"."works" add constraint "works_triggered_by_user_id_fkey" FOREIGN KEY (triggered_by_user_id) REFERENCES auth.users(id) not valid;

alter table "public"."works" validate constraint "works_triggered_by_user_id_fkey";

alter table "public"."works_meta" add constraint "works_meta_work_id_fkey" FOREIGN KEY (work_id) REFERENCES public.works(work_id) ON DELETE CASCADE not valid;

alter table "public"."works_meta" validate constraint "works_meta_work_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.calculate_staleness_days(release_date date)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    days_since_release INT;
BEGIN
    days_since_release := CURRENT_DATE - release_date;
    
    -- Movies in theaters (last 30 days): refresh every 2 days
    IF days_since_release <= 30 THEN
        RETURN 2;
    -- Recent releases (1-6 months): refresh weekly
    ELSIF days_since_release <= 180 THEN
        RETURN 7;
    -- Older movies (6-12 months): refresh every 2 weeks
    ELSIF days_since_release <= 365 THEN
        RETURN 14;
    -- Catalog movies (1+ years): refresh monthly
    ELSE
        RETURN 30;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.can_make_ai_request()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    daily_budget_cents NUMERIC := 1000;  -- $10.00 daily budget
    max_requests_per_minute INTEGER := 10;
    today_start TIMESTAMPTZ := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC');
    one_minute_ago TIMESTAMPTZ := NOW() - INTERVAL '1 minute';
    spent_today NUMERIC;
    requests_last_minute INTEGER;
    allowed BOOLEAN := TRUE;
    reason TEXT := 'OK';
BEGIN
    -- Check daily budget
    SELECT COALESCE(SUM(cost_cents), 0)
    INTO spent_today
    FROM ai_discovery_requests
    WHERE created_at >= today_start
    AND status = 'success';
    
    IF spent_today >= daily_budget_cents THEN
        allowed := FALSE;
        reason := 'Daily budget exceeded ($10.00)';
    END IF;
    
    -- Check rate limit (requests per minute)
    IF allowed THEN
        SELECT COUNT(*)
        INTO requests_last_minute
        FROM ai_discovery_requests
        WHERE created_at >= one_minute_ago;
        
        IF requests_last_minute >= max_requests_per_minute THEN
            allowed := FALSE;
            reason := 'Rate limit exceeded (10 requests/minute)';
        END IF;
    END IF;
    
    RETURN json_build_object(
        'allowed', allowed,
        'reason', reason,
        'spent_cents', spent_today,
        'remaining_cents', GREATEST(daily_budget_cents - spent_today, 0),
        'requests_last_minute', requests_last_minute
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_ai_budget_status()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    daily_budget_cents NUMERIC := 1000;  -- $10.00 daily budget
    today_start TIMESTAMPTZ := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC');
    spent_today NUMERIC;
    requests_today INTEGER;
    tokens_today INTEGER;
    first_request_today TIMESTAMPTZ;
    hours_elapsed NUMERIC;
    spend_rate NUMERIC;
BEGIN
    -- Get today's totals
    SELECT 
        COALESCE(SUM(cost_cents), 0),
        COALESCE(COUNT(*), 0),
        COALESCE(SUM(total_tokens), 0),
        MIN(created_at)
    INTO spent_today, requests_today, tokens_today, first_request_today
    FROM ai_discovery_requests
    WHERE created_at >= today_start
    AND status = 'success';
    
    -- Calculate spend rate (cents per hour)
    IF first_request_today IS NOT NULL THEN
        hours_elapsed := GREATEST(EXTRACT(EPOCH FROM (NOW() - first_request_today)) / 3600.0, 0.1);
        spend_rate := spent_today / hours_elapsed;
    ELSE
        spend_rate := 0;
    END IF;
    
    RETURN json_build_object(
        'spent_today_cents', spent_today,
        'budget_cents', daily_budget_cents,
        'remaining_cents', GREATEST(daily_budget_cents - spent_today, 0),
        'requests_today', requests_today,
        'tokens_today', tokens_today,
        'is_over_budget', spent_today >= daily_budget_cents,
        'spend_rate_cents_per_hour', ROUND(spend_rate, 2),
        'percent_used', ROUND((spent_today / daily_budget_cents) * 100, 1)
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_movie_database_stats()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_movies', (SELECT COUNT(*) FROM works),
        'added_today', (SELECT COUNT(*) FROM works WHERE created_at >= CURRENT_DATE),
        'added_this_week', (SELECT COUNT(*) FROM works WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'),
        'movies_with_posters', (
            SELECT COUNT(*) 
            FROM work_cards_cache 
            WHERE payload::jsonb->'poster'->>'medium' IS NOT NULL
        ),
        'movies_with_trailers', (
            SELECT COUNT(*) 
            FROM work_cards_cache 
            WHERE payload::jsonb->>'trailer_youtube_id' IS NOT NULL
        ),
        'unique_directors', (
            SELECT COUNT(DISTINCT payload::jsonb->>'director') 
            FROM work_cards_cache 
            WHERE payload::jsonb->>'director' IS NOT NULL
        ),
        'unique_actors', (
            SELECT COUNT(DISTINCT actor->>'name')
            FROM work_cards_cache, jsonb_array_elements(payload::jsonb->'cast') AS actor
            WHERE actor->>'name' IS NOT NULL
        ),
        'data_quality', json_build_object(
            'has_director', (SELECT COUNT(*) FROM work_cards_cache WHERE payload::jsonb->>'director' IS NOT NULL AND payload::jsonb->>'director' != ''),
            'has_writer', (SELECT COUNT(*) FROM work_cards_cache WHERE payload::jsonb->>'writer' IS NOT NULL AND payload::jsonb->>'writer' != ''),
            'has_screenplay', (SELECT COUNT(*) FROM work_cards_cache WHERE payload::jsonb->>'screenplay' IS NOT NULL AND payload::jsonb->>'screenplay' != ''),
            'has_composer', (SELECT COUNT(*) FROM work_cards_cache WHERE payload::jsonb->>'composer' IS NOT NULL AND payload::jsonb->>'composer' != ''),
            'has_cinematographer', (SELECT COUNT(*) FROM work_cards_cache WHERE payload::jsonb->>'cinematographer' IS NOT NULL AND payload::jsonb->>'cinematographer' != ''),
            'has_certification', (SELECT COUNT(*) FROM work_cards_cache WHERE payload::jsonb->>'certification' IS NOT NULL AND payload::jsonb->>'certification' != '')
        ),
        'movies_by_day', (
            SELECT json_agg(row_to_json(t) ORDER BY t.date)
            FROM (
                SELECT DATE(created_at) as date, COUNT(*) as movies
                FROM works
                WHERE created_at >= CURRENT_DATE - INTERVAL '365 days'
                GROUP BY DATE(created_at)
                ORDER BY date
            ) t
        )
    ) INTO result;
    RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_tmdb_stats()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    today_start TIMESTAMPTZ := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC');
    week_start TIMESTAMPTZ := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') - INTERVAL '7 days';
    total_movies INTEGER;
    ingested_today INTEGER;
    ingested_this_week INTEGER;
    pending_count INTEGER;
    failed_count INTEGER;
    avg_per_day NUMERIC;
BEGIN
    -- Total movies in database
    SELECT COUNT(*) INTO total_movies FROM works;
    
    -- Ingested today (based on last_refreshed_at)
    SELECT COUNT(*) INTO ingested_today 
    FROM works 
    WHERE last_refreshed_at >= today_start;
    
    -- Ingested this week
    SELECT COUNT(*) INTO ingested_this_week 
    FROM works 
    WHERE last_refreshed_at >= week_start;
    
    -- Pending ingestions
    SELECT COUNT(*) INTO pending_count 
    FROM works 
    WHERE ingestion_status = 'pending';
    
    -- Failed ingestions
    SELECT COUNT(*) INTO failed_count 
    FROM works 
    WHERE ingestion_status = 'failed';
    
    -- Average per day (last 7 days)
    avg_per_day := ingested_this_week / 7.0;
    
    RETURN json_build_object(
        'total_movies', total_movies,
        'ingested_today', ingested_today,
        'ingested_this_week', ingested_this_week,
        'pending_count', pending_count,
        'failed_count', failed_count,
        'avg_per_day', ROUND(avg_per_day, 1),
        'status_breakdown', (
            SELECT json_build_object(
                'complete', COUNT(*) FILTER (WHERE ingestion_status = 'complete'),
                'pending', COUNT(*) FILTER (WHERE ingestion_status = 'pending'),
                'ingesting', COUNT(*) FILTER (WHERE ingestion_status = 'ingesting'),
                'failed', COUNT(*) FILTER (WHERE ingestion_status = 'failed')
            )
            FROM works
        )
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_stale(work_id_input bigint)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    work_record RECORD;
    staleness_days INT;
BEGIN
    SELECT release_date, last_refreshed_at INTO work_record
    FROM works WHERE work_id = work_id_input;
    
    IF work_record IS NULL THEN
        RETURN true;
    END IF;
    
    staleness_days := calculate_staleness_days(work_record.release_date);
    
    RETURN work_record.last_refreshed_at < (now() - (staleness_days || ' days')::INTERVAL);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.normalize_rating(value real, scale_type text)
 RETURNS real
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    CASE scale_type
        WHEN '0_10' THEN RETURN value * 10;
        WHEN '0_5' THEN RETURN value * 20;
        WHEN '0_100' THEN RETURN value;
        WHEN '0_4' THEN RETURN value * 25;  -- Letterboxd uses 0-5 but often shown as stars
        ELSE RETURN value;  -- Assume already 0-100
    END CASE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$function$
;

create or replace view "public"."voice_events_view" as  SELECT to_char((v.created_at AT TIME ZONE 'America/Los_Angeles'::text), 'MM/DD HH:MI:SS.MS AM'::text) AS "When",
    COALESCE(p.username, 'Unknown'::text) AS "Who",
    v.utterance AS "Said",
    v.mango_command_type AS "Type",
    v.handler_result AS "Result",
    v.llm_used AS "AI?",
    v.mango_command_raw,
    v.mango_command_movie_title,
    v.final_command_type,
    v.final_command_movie_title,
    v.final_command_recommender,
    v.llm_intent,
    v.llm_error,
    v.result_count,
    v.error_message,
    v.user_id,
    v.id
   FROM (public.voice_utterance_events v
     LEFT JOIN public.profiles p ON ((v.user_id = p.id)))
  ORDER BY v.created_at DESC;


grant delete on table "public"."aggregates" to "anon";

grant insert on table "public"."aggregates" to "anon";

grant references on table "public"."aggregates" to "anon";

grant select on table "public"."aggregates" to "anon";

grant trigger on table "public"."aggregates" to "anon";

grant truncate on table "public"."aggregates" to "anon";

grant update on table "public"."aggregates" to "anon";

grant delete on table "public"."aggregates" to "authenticated";

grant insert on table "public"."aggregates" to "authenticated";

grant references on table "public"."aggregates" to "authenticated";

grant select on table "public"."aggregates" to "authenticated";

grant trigger on table "public"."aggregates" to "authenticated";

grant truncate on table "public"."aggregates" to "authenticated";

grant update on table "public"."aggregates" to "authenticated";

grant delete on table "public"."aggregates" to "service_role";

grant insert on table "public"."aggregates" to "service_role";

grant references on table "public"."aggregates" to "service_role";

grant select on table "public"."aggregates" to "service_role";

grant trigger on table "public"."aggregates" to "service_role";

grant truncate on table "public"."aggregates" to "service_role";

grant update on table "public"."aggregates" to "service_role";

grant delete on table "public"."ai_discovery_requests" to "anon";

grant insert on table "public"."ai_discovery_requests" to "anon";

grant references on table "public"."ai_discovery_requests" to "anon";

grant select on table "public"."ai_discovery_requests" to "anon";

grant trigger on table "public"."ai_discovery_requests" to "anon";

grant truncate on table "public"."ai_discovery_requests" to "anon";

grant update on table "public"."ai_discovery_requests" to "anon";

grant delete on table "public"."ai_discovery_requests" to "authenticated";

grant insert on table "public"."ai_discovery_requests" to "authenticated";

grant references on table "public"."ai_discovery_requests" to "authenticated";

grant select on table "public"."ai_discovery_requests" to "authenticated";

grant trigger on table "public"."ai_discovery_requests" to "authenticated";

grant truncate on table "public"."ai_discovery_requests" to "authenticated";

grant update on table "public"."ai_discovery_requests" to "authenticated";

grant delete on table "public"."ai_discovery_requests" to "service_role";

grant insert on table "public"."ai_discovery_requests" to "service_role";

grant references on table "public"."ai_discovery_requests" to "service_role";

grant select on table "public"."ai_discovery_requests" to "service_role";

grant trigger on table "public"."ai_discovery_requests" to "service_role";

grant truncate on table "public"."ai_discovery_requests" to "service_role";

grant update on table "public"."ai_discovery_requests" to "service_role";

grant delete on table "public"."buzz_signals" to "anon";

grant insert on table "public"."buzz_signals" to "anon";

grant references on table "public"."buzz_signals" to "anon";

grant select on table "public"."buzz_signals" to "anon";

grant trigger on table "public"."buzz_signals" to "anon";

grant truncate on table "public"."buzz_signals" to "anon";

grant update on table "public"."buzz_signals" to "anon";

grant delete on table "public"."buzz_signals" to "authenticated";

grant insert on table "public"."buzz_signals" to "authenticated";

grant references on table "public"."buzz_signals" to "authenticated";

grant select on table "public"."buzz_signals" to "authenticated";

grant trigger on table "public"."buzz_signals" to "authenticated";

grant truncate on table "public"."buzz_signals" to "authenticated";

grant update on table "public"."buzz_signals" to "authenticated";

grant delete on table "public"."buzz_signals" to "service_role";

grant insert on table "public"."buzz_signals" to "service_role";

grant references on table "public"."buzz_signals" to "service_role";

grant select on table "public"."buzz_signals" to "service_role";

grant trigger on table "public"."buzz_signals" to "service_role";

grant truncate on table "public"."buzz_signals" to "service_role";

grant update on table "public"."buzz_signals" to "service_role";

grant delete on table "public"."comprehensive_searches" to "anon";

grant insert on table "public"."comprehensive_searches" to "anon";

grant references on table "public"."comprehensive_searches" to "anon";

grant select on table "public"."comprehensive_searches" to "anon";

grant trigger on table "public"."comprehensive_searches" to "anon";

grant truncate on table "public"."comprehensive_searches" to "anon";

grant update on table "public"."comprehensive_searches" to "anon";

grant delete on table "public"."comprehensive_searches" to "authenticated";

grant insert on table "public"."comprehensive_searches" to "authenticated";

grant references on table "public"."comprehensive_searches" to "authenticated";

grant select on table "public"."comprehensive_searches" to "authenticated";

grant trigger on table "public"."comprehensive_searches" to "authenticated";

grant truncate on table "public"."comprehensive_searches" to "authenticated";

grant update on table "public"."comprehensive_searches" to "authenticated";

grant delete on table "public"."comprehensive_searches" to "service_role";

grant insert on table "public"."comprehensive_searches" to "service_role";

grant references on table "public"."comprehensive_searches" to "service_role";

grant select on table "public"."comprehensive_searches" to "service_role";

grant trigger on table "public"."comprehensive_searches" to "service_role";

grant truncate on table "public"."comprehensive_searches" to "service_role";

grant update on table "public"."comprehensive_searches" to "service_role";

grant delete on table "public"."cron_canary" to "anon";

grant insert on table "public"."cron_canary" to "anon";

grant references on table "public"."cron_canary" to "anon";

grant select on table "public"."cron_canary" to "anon";

grant trigger on table "public"."cron_canary" to "anon";

grant truncate on table "public"."cron_canary" to "anon";

grant update on table "public"."cron_canary" to "anon";

grant delete on table "public"."cron_canary" to "authenticated";

grant insert on table "public"."cron_canary" to "authenticated";

grant references on table "public"."cron_canary" to "authenticated";

grant select on table "public"."cron_canary" to "authenticated";

grant trigger on table "public"."cron_canary" to "authenticated";

grant truncate on table "public"."cron_canary" to "authenticated";

grant update on table "public"."cron_canary" to "authenticated";

grant delete on table "public"."cron_canary" to "service_role";

grant insert on table "public"."cron_canary" to "service_role";

grant references on table "public"."cron_canary" to "service_role";

grant select on table "public"."cron_canary" to "service_role";

grant trigger on table "public"."cron_canary" to "service_role";

grant truncate on table "public"."cron_canary" to "service_role";

grant update on table "public"."cron_canary" to "service_role";

grant delete on table "public"."events" to "anon";

grant insert on table "public"."events" to "anon";

grant references on table "public"."events" to "anon";

grant select on table "public"."events" to "anon";

grant trigger on table "public"."events" to "anon";

grant truncate on table "public"."events" to "anon";

grant update on table "public"."events" to "anon";

grant delete on table "public"."events" to "authenticated";

grant insert on table "public"."events" to "authenticated";

grant references on table "public"."events" to "authenticated";

grant select on table "public"."events" to "authenticated";

grant trigger on table "public"."events" to "authenticated";

grant truncate on table "public"."events" to "authenticated";

grant update on table "public"."events" to "authenticated";

grant delete on table "public"."events" to "service_role";

grant insert on table "public"."events" to "service_role";

grant references on table "public"."events" to "service_role";

grant select on table "public"."events" to "service_role";

grant trigger on table "public"."events" to "service_role";

grant truncate on table "public"."events" to "service_role";

grant update on table "public"."events" to "service_role";

grant delete on table "public"."google_streaming_captures" to "anon";

grant insert on table "public"."google_streaming_captures" to "anon";

grant references on table "public"."google_streaming_captures" to "anon";

grant select on table "public"."google_streaming_captures" to "anon";

grant trigger on table "public"."google_streaming_captures" to "anon";

grant truncate on table "public"."google_streaming_captures" to "anon";

grant update on table "public"."google_streaming_captures" to "anon";

grant delete on table "public"."google_streaming_captures" to "authenticated";

grant insert on table "public"."google_streaming_captures" to "authenticated";

grant references on table "public"."google_streaming_captures" to "authenticated";

grant select on table "public"."google_streaming_captures" to "authenticated";

grant trigger on table "public"."google_streaming_captures" to "authenticated";

grant truncate on table "public"."google_streaming_captures" to "authenticated";

grant update on table "public"."google_streaming_captures" to "authenticated";

grant delete on table "public"."google_streaming_captures" to "service_role";

grant insert on table "public"."google_streaming_captures" to "service_role";

grant references on table "public"."google_streaming_captures" to "service_role";

grant select on table "public"."google_streaming_captures" to "service_role";

grant trigger on table "public"."google_streaming_captures" to "service_role";

grant truncate on table "public"."google_streaming_captures" to "service_role";

grant update on table "public"."google_streaming_captures" to "service_role";

grant delete on table "public"."prime_catalog_captures" to "anon";

grant insert on table "public"."prime_catalog_captures" to "anon";

grant references on table "public"."prime_catalog_captures" to "anon";

grant select on table "public"."prime_catalog_captures" to "anon";

grant trigger on table "public"."prime_catalog_captures" to "anon";

grant truncate on table "public"."prime_catalog_captures" to "anon";

grant update on table "public"."prime_catalog_captures" to "anon";

grant delete on table "public"."prime_catalog_captures" to "authenticated";

grant insert on table "public"."prime_catalog_captures" to "authenticated";

grant references on table "public"."prime_catalog_captures" to "authenticated";

grant select on table "public"."prime_catalog_captures" to "authenticated";

grant trigger on table "public"."prime_catalog_captures" to "authenticated";

grant truncate on table "public"."prime_catalog_captures" to "authenticated";

grant update on table "public"."prime_catalog_captures" to "authenticated";

grant delete on table "public"."prime_catalog_captures" to "service_role";

grant insert on table "public"."prime_catalog_captures" to "service_role";

grant references on table "public"."prime_catalog_captures" to "service_role";

grant select on table "public"."prime_catalog_captures" to "service_role";

grant trigger on table "public"."prime_catalog_captures" to "service_role";

grant truncate on table "public"."prime_catalog_captures" to "service_role";

grant update on table "public"."prime_catalog_captures" to "service_role";

grant delete on table "public"."rating_sources" to "anon";

grant insert on table "public"."rating_sources" to "anon";

grant references on table "public"."rating_sources" to "anon";

grant select on table "public"."rating_sources" to "anon";

grant trigger on table "public"."rating_sources" to "anon";

grant truncate on table "public"."rating_sources" to "anon";

grant update on table "public"."rating_sources" to "anon";

grant delete on table "public"."rating_sources" to "authenticated";

grant insert on table "public"."rating_sources" to "authenticated";

grant references on table "public"."rating_sources" to "authenticated";

grant select on table "public"."rating_sources" to "authenticated";

grant trigger on table "public"."rating_sources" to "authenticated";

grant truncate on table "public"."rating_sources" to "authenticated";

grant update on table "public"."rating_sources" to "authenticated";

grant delete on table "public"."rating_sources" to "service_role";

grant insert on table "public"."rating_sources" to "service_role";

grant references on table "public"."rating_sources" to "service_role";

grant select on table "public"."rating_sources" to "service_role";

grant trigger on table "public"."rating_sources" to "service_role";

grant truncate on table "public"."rating_sources" to "service_role";

grant update on table "public"."rating_sources" to "service_role";

grant delete on table "public"."review_excerpts" to "anon";

grant insert on table "public"."review_excerpts" to "anon";

grant references on table "public"."review_excerpts" to "anon";

grant select on table "public"."review_excerpts" to "anon";

grant trigger on table "public"."review_excerpts" to "anon";

grant truncate on table "public"."review_excerpts" to "anon";

grant update on table "public"."review_excerpts" to "anon";

grant delete on table "public"."review_excerpts" to "authenticated";

grant insert on table "public"."review_excerpts" to "authenticated";

grant references on table "public"."review_excerpts" to "authenticated";

grant select on table "public"."review_excerpts" to "authenticated";

grant trigger on table "public"."review_excerpts" to "authenticated";

grant truncate on table "public"."review_excerpts" to "authenticated";

grant update on table "public"."review_excerpts" to "authenticated";

grant delete on table "public"."review_excerpts" to "service_role";

grant insert on table "public"."review_excerpts" to "service_role";

grant references on table "public"."review_excerpts" to "service_role";

grant select on table "public"."review_excerpts" to "service_role";

grant trigger on table "public"."review_excerpts" to "service_role";

grant truncate on table "public"."review_excerpts" to "service_role";

grant update on table "public"."review_excerpts" to "service_role";

grant delete on table "public"."review_sentiment" to "anon";

grant insert on table "public"."review_sentiment" to "anon";

grant references on table "public"."review_sentiment" to "anon";

grant select on table "public"."review_sentiment" to "anon";

grant trigger on table "public"."review_sentiment" to "anon";

grant truncate on table "public"."review_sentiment" to "anon";

grant update on table "public"."review_sentiment" to "anon";

grant delete on table "public"."review_sentiment" to "authenticated";

grant insert on table "public"."review_sentiment" to "authenticated";

grant references on table "public"."review_sentiment" to "authenticated";

grant select on table "public"."review_sentiment" to "authenticated";

grant trigger on table "public"."review_sentiment" to "authenticated";

grant truncate on table "public"."review_sentiment" to "authenticated";

grant update on table "public"."review_sentiment" to "authenticated";

grant delete on table "public"."review_sentiment" to "service_role";

grant insert on table "public"."review_sentiment" to "service_role";

grant references on table "public"."review_sentiment" to "service_role";

grant select on table "public"."review_sentiment" to "service_role";

grant trigger on table "public"."review_sentiment" to "service_role";

grant truncate on table "public"."review_sentiment" to "service_role";

grant update on table "public"."review_sentiment" to "service_role";

grant delete on table "public"."similar_movies" to "anon";

grant insert on table "public"."similar_movies" to "anon";

grant references on table "public"."similar_movies" to "anon";

grant select on table "public"."similar_movies" to "anon";

grant trigger on table "public"."similar_movies" to "anon";

grant truncate on table "public"."similar_movies" to "anon";

grant update on table "public"."similar_movies" to "anon";

grant delete on table "public"."similar_movies" to "authenticated";

grant insert on table "public"."similar_movies" to "authenticated";

grant references on table "public"."similar_movies" to "authenticated";

grant select on table "public"."similar_movies" to "authenticated";

grant trigger on table "public"."similar_movies" to "authenticated";

grant truncate on table "public"."similar_movies" to "authenticated";

grant update on table "public"."similar_movies" to "authenticated";

grant delete on table "public"."similar_movies" to "service_role";

grant insert on table "public"."similar_movies" to "service_role";

grant references on table "public"."similar_movies" to "service_role";

grant select on table "public"."similar_movies" to "service_role";

grant trigger on table "public"."similar_movies" to "service_role";

grant truncate on table "public"."similar_movies" to "service_role";

grant update on table "public"."similar_movies" to "service_role";

grant delete on table "public"."streaming_announcements_raw" to "anon";

grant insert on table "public"."streaming_announcements_raw" to "anon";

grant references on table "public"."streaming_announcements_raw" to "anon";

grant select on table "public"."streaming_announcements_raw" to "anon";

grant trigger on table "public"."streaming_announcements_raw" to "anon";

grant truncate on table "public"."streaming_announcements_raw" to "anon";

grant update on table "public"."streaming_announcements_raw" to "anon";

grant delete on table "public"."streaming_announcements_raw" to "authenticated";

grant insert on table "public"."streaming_announcements_raw" to "authenticated";

grant references on table "public"."streaming_announcements_raw" to "authenticated";

grant select on table "public"."streaming_announcements_raw" to "authenticated";

grant trigger on table "public"."streaming_announcements_raw" to "authenticated";

grant truncate on table "public"."streaming_announcements_raw" to "authenticated";

grant update on table "public"."streaming_announcements_raw" to "authenticated";

grant delete on table "public"."streaming_announcements_raw" to "service_role";

grant insert on table "public"."streaming_announcements_raw" to "service_role";

grant references on table "public"."streaming_announcements_raw" to "service_role";

grant select on table "public"."streaming_announcements_raw" to "service_role";

grant trigger on table "public"."streaming_announcements_raw" to "service_role";

grant truncate on table "public"."streaming_announcements_raw" to "service_role";

grant update on table "public"."streaming_announcements_raw" to "service_role";

grant delete on table "public"."streaming_changes" to "anon";

grant insert on table "public"."streaming_changes" to "anon";

grant references on table "public"."streaming_changes" to "anon";

grant select on table "public"."streaming_changes" to "anon";

grant trigger on table "public"."streaming_changes" to "anon";

grant truncate on table "public"."streaming_changes" to "anon";

grant update on table "public"."streaming_changes" to "anon";

grant delete on table "public"."streaming_changes" to "authenticated";

grant insert on table "public"."streaming_changes" to "authenticated";

grant references on table "public"."streaming_changes" to "authenticated";

grant select on table "public"."streaming_changes" to "authenticated";

grant trigger on table "public"."streaming_changes" to "authenticated";

grant truncate on table "public"."streaming_changes" to "authenticated";

grant update on table "public"."streaming_changes" to "authenticated";

grant delete on table "public"."streaming_changes" to "service_role";

grant insert on table "public"."streaming_changes" to "service_role";

grant references on table "public"."streaming_changes" to "service_role";

grant select on table "public"."streaming_changes" to "service_role";

grant trigger on table "public"."streaming_changes" to "service_role";

grant truncate on table "public"."streaming_changes" to "service_role";

grant update on table "public"."streaming_changes" to "service_role";

grant delete on table "public"."streaming_scrape_log" to "anon";

grant insert on table "public"."streaming_scrape_log" to "anon";

grant references on table "public"."streaming_scrape_log" to "anon";

grant select on table "public"."streaming_scrape_log" to "anon";

grant trigger on table "public"."streaming_scrape_log" to "anon";

grant truncate on table "public"."streaming_scrape_log" to "anon";

grant update on table "public"."streaming_scrape_log" to "anon";

grant delete on table "public"."streaming_scrape_log" to "authenticated";

grant insert on table "public"."streaming_scrape_log" to "authenticated";

grant references on table "public"."streaming_scrape_log" to "authenticated";

grant select on table "public"."streaming_scrape_log" to "authenticated";

grant trigger on table "public"."streaming_scrape_log" to "authenticated";

grant truncate on table "public"."streaming_scrape_log" to "authenticated";

grant update on table "public"."streaming_scrape_log" to "authenticated";

grant delete on table "public"."streaming_scrape_log" to "service_role";

grant insert on table "public"."streaming_scrape_log" to "service_role";

grant references on table "public"."streaming_scrape_log" to "service_role";

grant select on table "public"."streaming_scrape_log" to "service_role";

grant trigger on table "public"."streaming_scrape_log" to "service_role";

grant truncate on table "public"."streaming_scrape_log" to "service_role";

grant update on table "public"."streaming_scrape_log" to "service_role";

grant delete on table "public"."streaming_sources" to "anon";

grant insert on table "public"."streaming_sources" to "anon";

grant references on table "public"."streaming_sources" to "anon";

grant select on table "public"."streaming_sources" to "anon";

grant trigger on table "public"."streaming_sources" to "anon";

grant truncate on table "public"."streaming_sources" to "anon";

grant update on table "public"."streaming_sources" to "anon";

grant delete on table "public"."streaming_sources" to "authenticated";

grant insert on table "public"."streaming_sources" to "authenticated";

grant references on table "public"."streaming_sources" to "authenticated";

grant select on table "public"."streaming_sources" to "authenticated";

grant trigger on table "public"."streaming_sources" to "authenticated";

grant truncate on table "public"."streaming_sources" to "authenticated";

grant update on table "public"."streaming_sources" to "authenticated";

grant delete on table "public"."streaming_sources" to "service_role";

grant insert on table "public"."streaming_sources" to "service_role";

grant references on table "public"."streaming_sources" to "service_role";

grant select on table "public"."streaming_sources" to "service_role";

grant trigger on table "public"."streaming_sources" to "service_role";

grant truncate on table "public"."streaming_sources" to "service_role";

grant update on table "public"."streaming_sources" to "service_role";

grant delete on table "public"."user_captures" to "anon";

grant insert on table "public"."user_captures" to "anon";

grant references on table "public"."user_captures" to "anon";

grant select on table "public"."user_captures" to "anon";

grant trigger on table "public"."user_captures" to "anon";

grant truncate on table "public"."user_captures" to "anon";

grant update on table "public"."user_captures" to "anon";

grant delete on table "public"."user_captures" to "authenticated";

grant insert on table "public"."user_captures" to "authenticated";

grant references on table "public"."user_captures" to "authenticated";

grant select on table "public"."user_captures" to "authenticated";

grant trigger on table "public"."user_captures" to "authenticated";

grant truncate on table "public"."user_captures" to "authenticated";

grant update on table "public"."user_captures" to "authenticated";

grant delete on table "public"."user_captures" to "service_role";

grant insert on table "public"."user_captures" to "service_role";

grant references on table "public"."user_captures" to "service_role";

grant select on table "public"."user_captures" to "service_role";

grant trigger on table "public"."user_captures" to "service_role";

grant truncate on table "public"."user_captures" to "service_role";

grant update on table "public"."user_captures" to "service_role";

grant delete on table "public"."user_imports" to "anon";

grant insert on table "public"."user_imports" to "anon";

grant references on table "public"."user_imports" to "anon";

grant select on table "public"."user_imports" to "anon";

grant trigger on table "public"."user_imports" to "anon";

grant truncate on table "public"."user_imports" to "anon";

grant update on table "public"."user_imports" to "anon";

grant delete on table "public"."user_imports" to "authenticated";

grant insert on table "public"."user_imports" to "authenticated";

grant references on table "public"."user_imports" to "authenticated";

grant select on table "public"."user_imports" to "authenticated";

grant trigger on table "public"."user_imports" to "authenticated";

grant truncate on table "public"."user_imports" to "authenticated";

grant update on table "public"."user_imports" to "authenticated";

grant delete on table "public"."user_imports" to "service_role";

grant insert on table "public"."user_imports" to "service_role";

grant references on table "public"."user_imports" to "service_role";

grant select on table "public"."user_imports" to "service_role";

grant trigger on table "public"."user_imports" to "service_role";

grant truncate on table "public"."user_imports" to "service_role";

grant update on table "public"."user_imports" to "service_role";

grant delete on table "public"."voice_pattern_suggestions" to "anon";

grant insert on table "public"."voice_pattern_suggestions" to "anon";

grant references on table "public"."voice_pattern_suggestions" to "anon";

grant select on table "public"."voice_pattern_suggestions" to "anon";

grant trigger on table "public"."voice_pattern_suggestions" to "anon";

grant truncate on table "public"."voice_pattern_suggestions" to "anon";

grant update on table "public"."voice_pattern_suggestions" to "anon";

grant delete on table "public"."voice_pattern_suggestions" to "authenticated";

grant insert on table "public"."voice_pattern_suggestions" to "authenticated";

grant references on table "public"."voice_pattern_suggestions" to "authenticated";

grant select on table "public"."voice_pattern_suggestions" to "authenticated";

grant trigger on table "public"."voice_pattern_suggestions" to "authenticated";

grant truncate on table "public"."voice_pattern_suggestions" to "authenticated";

grant update on table "public"."voice_pattern_suggestions" to "authenticated";

grant delete on table "public"."voice_pattern_suggestions" to "service_role";

grant insert on table "public"."voice_pattern_suggestions" to "service_role";

grant references on table "public"."voice_pattern_suggestions" to "service_role";

grant select on table "public"."voice_pattern_suggestions" to "service_role";

grant trigger on table "public"."voice_pattern_suggestions" to "service_role";

grant truncate on table "public"."voice_pattern_suggestions" to "service_role";

grant update on table "public"."voice_pattern_suggestions" to "service_role";

grant delete on table "public"."work_cards_cache" to "anon";

grant insert on table "public"."work_cards_cache" to "anon";

grant references on table "public"."work_cards_cache" to "anon";

grant select on table "public"."work_cards_cache" to "anon";

grant trigger on table "public"."work_cards_cache" to "anon";

grant truncate on table "public"."work_cards_cache" to "anon";

grant update on table "public"."work_cards_cache" to "anon";

grant delete on table "public"."work_cards_cache" to "authenticated";

grant insert on table "public"."work_cards_cache" to "authenticated";

grant references on table "public"."work_cards_cache" to "authenticated";

grant select on table "public"."work_cards_cache" to "authenticated";

grant trigger on table "public"."work_cards_cache" to "authenticated";

grant truncate on table "public"."work_cards_cache" to "authenticated";

grant update on table "public"."work_cards_cache" to "authenticated";

grant delete on table "public"."work_cards_cache" to "service_role";

grant insert on table "public"."work_cards_cache" to "service_role";

grant references on table "public"."work_cards_cache" to "service_role";

grant select on table "public"."work_cards_cache" to "service_role";

grant trigger on table "public"."work_cards_cache" to "service_role";

grant truncate on table "public"."work_cards_cache" to "service_role";

grant update on table "public"."work_cards_cache" to "service_role";

grant delete on table "public"."works_meta" to "anon";

grant insert on table "public"."works_meta" to "anon";

grant references on table "public"."works_meta" to "anon";

grant select on table "public"."works_meta" to "anon";

grant trigger on table "public"."works_meta" to "anon";

grant truncate on table "public"."works_meta" to "anon";

grant update on table "public"."works_meta" to "anon";

grant delete on table "public"."works_meta" to "authenticated";

grant insert on table "public"."works_meta" to "authenticated";

grant references on table "public"."works_meta" to "authenticated";

grant select on table "public"."works_meta" to "authenticated";

grant trigger on table "public"."works_meta" to "authenticated";

grant truncate on table "public"."works_meta" to "authenticated";

grant update on table "public"."works_meta" to "authenticated";

grant delete on table "public"."works_meta" to "service_role";

grant insert on table "public"."works_meta" to "service_role";

grant references on table "public"."works_meta" to "service_role";

grant select on table "public"."works_meta" to "service_role";

grant trigger on table "public"."works_meta" to "service_role";

grant truncate on table "public"."works_meta" to "service_role";

grant update on table "public"."works_meta" to "service_role";


  create policy "Aggregates managed by service role"
  on "public"."aggregates"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Aggregates viewable by everyone"
  on "public"."aggregates"
  as permissive
  for select
  to public
using (true);



  create policy "Public can view ai_discovery_requests"
  on "public"."ai_discovery_requests"
  as permissive
  for select
  to public
using (true);



  create policy "Users can insert own ai_discovery_requests"
  on "public"."ai_discovery_requests"
  as permissive
  for insert
  to public
with check (((auth.uid() = user_id) OR (user_id IS NULL)));



  create policy "Buzz signals managed by service role"
  on "public"."buzz_signals"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Buzz signals viewable by everyone"
  on "public"."buzz_signals"
  as permissive
  for select
  to public
using (true);



  create policy "Public can insert comprehensive_searches"
  on "public"."comprehensive_searches"
  as permissive
  for insert
  to public
with check (true);



  create policy "Public can update comprehensive_searches"
  on "public"."comprehensive_searches"
  as permissive
  for update
  to public
using (true);



  create policy "Public can view comprehensive_searches"
  on "public"."comprehensive_searches"
  as permissive
  for select
  to public
using (true);



  create policy "Allow public read for dashboard"
  on "public"."events"
  as permissive
  for select
  to public
using (true);



  create policy "Users can insert own events"
  on "public"."events"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can read own events"
  on "public"."events"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Allow public read access"
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);



  create policy "Rating sources managed by service role"
  on "public"."rating_sources"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Rating sources viewable by everyone"
  on "public"."rating_sources"
  as permissive
  for select
  to public
using (true);



  create policy "Review excerpts managed by service role"
  on "public"."review_excerpts"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Review excerpts viewable by everyone"
  on "public"."review_excerpts"
  as permissive
  for select
  to public
using (true);



  create policy "Review sentiment managed by service role"
  on "public"."review_sentiment"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Review sentiment viewable by everyone"
  on "public"."review_sentiment"
  as permissive
  for select
  to public
using (true);



  create policy "Users can delete own captures"
  on "public"."user_captures"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "Users can insert own captures"
  on "public"."user_captures"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can update own captures"
  on "public"."user_captures"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));



  create policy "Users can view own captures"
  on "public"."user_captures"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can delete own imports"
  on "public"."user_imports"
  as permissive
  for delete
  to public
using ((auth.uid() = user_id));



  create policy "Users can insert own imports"
  on "public"."user_imports"
  as permissive
  for insert
  to public
with check ((auth.uid() = user_id));



  create policy "Users can update own imports"
  on "public"."user_imports"
  as permissive
  for update
  to public
using ((auth.uid() = user_id));



  create policy "Users can view own imports"
  on "public"."user_imports"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));



  create policy "Users can manage own ratings"
  on "public"."user_ratings"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "Anyone can update pattern suggestions"
  on "public"."voice_pattern_suggestions"
  as permissive
  for update
  to public
using (true)
with check (true);



  create policy "Anyone can view pattern suggestions"
  on "public"."voice_pattern_suggestions"
  as permissive
  for select
  to public
using (true);



  create policy "Authenticated users can insert pattern suggestions"
  on "public"."voice_pattern_suggestions"
  as permissive
  for insert
  to authenticated
with check (true);



  create policy "Service role full access"
  on "public"."voice_pattern_suggestions"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Allow public read access"
  on "public"."voice_utterance_events"
  as permissive
  for select
  to public
using (true);



  create policy "Anyone can view voice events"
  on "public"."voice_utterance_events"
  as permissive
  for select
  to public
using (true);



  create policy "Work cards managed by service role"
  on "public"."work_cards_cache"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Work cards viewable by everyone"
  on "public"."work_cards_cache"
  as permissive
  for select
  to public
using (true);



  create policy "Works are managed by service role"
  on "public"."works"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Works are viewable by everyone"
  on "public"."works"
  as permissive
  for select
  to public
using (true);



  create policy "Works meta managed by service role"
  on "public"."works_meta"
  as permissive
  for all
  to public
using ((auth.role() = 'service_role'::text));



  create policy "Works meta viewable by everyone"
  on "public"."works_meta"
  as permissive
  for select
  to public
using (true);


CREATE TRIGGER works_updated_at BEFORE UPDATE ON public.works FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER works_meta_updated_at BEFORE UPDATE ON public.works_meta FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


  create policy "Allow public read i53kj9_0"
  on "storage"."objects"
  as permissive
  for select
  to anon
using ((bucket_id = 'movie-images'::text));



  create policy "Allow service uploads i53kj9_0"
  on "storage"."objects"
  as permissive
  for insert
  to service_role
with check ((bucket_id = 'movie-images'::text));



