//  scheduledIngestRunsColumns.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:55 (America/Los_Angeles - Pacific Time)
//  Notes: Column definitions for scheduled ingestion runs table

import { ColumnDef } from '@tanstack/react-table'
import { ScheduledIngestRun } from '@/lib/supabase'

export const scheduledIngestRunsColumns: ColumnDef<ScheduledIngestRun>[] = [
  {
    accessorKey: 'created_at',
    header: 'Run Time',
    cell: ({ row }) => {
      const date = new Date(row.getValue('created_at') as string)
      return (
        <div className="text-slate-200">
          <div className="font-medium">{date.toLocaleDateString()}</div>
          <div className="text-xs text-slate-400">{date.toLocaleTimeString()}</div>
        </div>
      )
    },
  },
  {
    accessorKey: 'trigger_type',
    header: 'Trigger',
    cell: ({ row }) => {
      const triggerType = row.getValue('trigger_type') as string
      const color = triggerType === 'scheduled' ? 'text-blue-400' : 'text-purple-400'
      return (
        <div className={color}>
          {triggerType === 'scheduled' ? '⏰ Scheduled' : '👤 Manual'}
        </div>
      )
    },
  },
  {
    accessorKey: 'source',
    header: 'Source',
    cell: ({ row }) => {
      const source = row.getValue('source') as string
      const sourceLabels: Record<string, string> = {
        popular: '🔥 Popular',
        now_playing: '🎬 Now Playing',
        trending: '📈 Trending',
        mixed: '🌐 Mixed (All)',
      }
      return (
        <div className="text-slate-300">
          {sourceLabels[source] || source}
        </div>
      )
    },
  },
  {
    accessorKey: 'movies_checked',
    header: 'Checked',
    cell: ({ row }) => {
      const checked = row.getValue('movies_checked') as number
      return <div className="text-slate-300">{checked}</div>
    },
  },
  {
    accessorKey: 'movies_skipped',
    header: 'Skipped',
    cell: ({ row }) => {
      const skipped = row.getValue('movies_skipped') as number
      return <div className="text-slate-400">{skipped}</div>
    },
  },
  {
    accessorKey: 'movies_ingested',
    header: 'Ingested',
    cell: ({ row }) => {
      const ingested = row.getValue('movies_ingested') as number
      return <div className="text-green-400 font-medium">{ingested}</div>
    },
  },
  {
    accessorKey: 'movies_failed',
    header: 'Failed',
    cell: ({ row }) => {
      const failed = row.getValue('movies_failed') as number
      return failed > 0 ? (
        <div className="text-red-400 font-medium">{failed}</div>
      ) : (
        <div className="text-slate-500">0</div>
      )
    },
  },
  {
    accessorKey: 'duration_ms',
    header: 'Duration',
    cell: ({ row }) => {
      const durationMs = row.getValue('duration_ms') as number
      const seconds = (durationMs / 1000).toFixed(1)
      return <div className="text-slate-300 text-sm">{seconds}s</div>
    },
  },
]

