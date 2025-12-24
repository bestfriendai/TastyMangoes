# Tasty Mangoes – Scheduled Jobs (Cron)

This document tracks all automated jobs running in production.

## Platform
- Scheduler: Supabase pg_cron
- HTTP calls: pg_net → Supabase Edge Functions
- Environment: Production

---

## Active Jobs

### 1) Scheduled Ingest – Daily
- Job name: scheduled_ingest_daily
- Schedule: Daily @ 03:00 America/Los_Angeles
- Trigger: pg_cron → pg_net.http_post
- Edge Function: scheduled-ingest
- Payload:
  {
    "source": "mixed_daily",
    "max_movies": 30,
    "trigger_type": "scheduled"
  }
- Purpose:
  - Import newly released / trending movies
  - Keep catalog fresh

---

### 2) Scheduled Ingest – Weekly
- Job name: scheduled_ingest_weekly
- Schedule: Sundays @ 02:00 America/Los_Angeles
- Trigger: pg_cron → pg_net.http_post
- Edge Function: scheduled-ingest
- Payload:
  {
    "source": "mixed_weekly",
    "max_movies": 80,
    "trigger_type": "scheduled"
  }
- Purpose:
  - Broader catalog refresh (popular + trending)

---

### 3) Daily Refresh – Queue Fill
- Job name: daily_refresh_enqueue
- Schedule: Daily @ 03:30 America/Los_Angeles
- Edge Function: daily-refresh
- Purpose:
  - Find stale movies via is_stale()
  - Enqueue them for refresh

---

### 4) Refresh Worker
- Job name: refresh_worker
- Schedule: Every 10 minutes
- Edge Function: refresh-worker
- Purpose:
  - Process refresh_queue
  - Refresh movie metadata via ingest-movie

---

## Observability
- Ingest run logs: scheduled_ingestion_log
- TMDB API usage: tmdb_api_logs
- Refresh queue status: refresh_queue
- Sync state: sync_state

---

## Notes
- pg_cron + pg_net confirmed working on Supabase free plan
- Canary job was created and removed successfully
- All jobs can be paused or modified via cron.schedule / cron.unschedule

