-- 003_add_schema_version.sql
-- Safe-guarded: only applies if legacy table public.works_meta exists.
-- Reason: current schema may not include public.works_meta, but migration history references this file.

DO $$
BEGIN
  IF to_regclass('public.works_meta') IS NOT NULL THEN
    ALTER TABLE public.works_meta
      ADD COLUMN IF NOT EXISTS schema_version INTEGER DEFAULT 1;

    ALTER TABLE public.works_meta
      ADD COLUMN IF NOT EXISTS trailers JSONB;

    UPDATE public.works_meta
      SET schema_version = 1
      WHERE schema_version IS NULL;

    CREATE INDEX IF NOT EXISTS idx_works_meta_schema_version
      ON public.works_meta(schema_version);
  END IF;
END $$;

