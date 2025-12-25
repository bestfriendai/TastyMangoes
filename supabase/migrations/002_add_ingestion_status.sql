-- 002_add_ingestion_status.sql
-- Safe-guarded: only applies if legacy tables exist.
-- Reason: current schema may not include public.works / public.works_meta,
-- but migration history still references this file.

DO $$
BEGIN
  -- Legacy table: public.works
  IF to_regclass('public.works') IS NOT NULL THEN
    ALTER TABLE public.works
      ADD COLUMN IF NOT EXISTS ingestion_status TEXT DEFAULT 'pending';

    -- Add/replace constraint safely
    BEGIN
      ALTER TABLE public.works
        ADD CONSTRAINT works_ingestion_status_check
        CHECK (ingestion_status IN ('pending', 'ingesting', 'complete', 'failed'));
    EXCEPTION WHEN duplicate_object THEN
      -- already exists, ignore
      NULL;
    END;
  END IF;

  -- Legacy table: public.works_meta (only if you had it)
  IF to_regclass('public.works_meta') IS NOT NULL THEN
    ALTER TABLE public.works_meta
      ADD COLUMN IF NOT EXISTS similar_movie_ids TEXT[];
  END IF;
END $$;

