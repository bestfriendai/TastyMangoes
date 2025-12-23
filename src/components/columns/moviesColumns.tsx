//  moviesColumns.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: Column definitions for movies table

import { ColumnDef } from '@tanstack/react-table'
import { Movie } from '@/lib/supabase'

export const moviesColumns: ColumnDef<Movie>[] = [
  {
    accessorKey: 'title',
    header: 'Title',
    cell: ({ row }) => {
      const title = row.getValue('title') as string
      return <div className="text-slate-200 font-medium">{title}</div>
    },
  },
  {
    accessorKey: 'year',
    header: 'Year',
    cell: ({ row }) => {
      const year = row.getValue('year') as number | null
      return <div className="text-slate-300">{year || 'N/A'}</div>
    },
  },
  {
    accessorKey: 'tmdb_id',
    header: 'TMDB ID',
    cell: ({ row }) => {
      const tmdbId = row.getValue('tmdb_id') as string
      return <div className="text-slate-300 font-mono text-sm">{tmdbId}</div>
    },
  },
  {
    accessorKey: 'ingestion_status',
    header: 'Status',
    cell: ({ row }) => {
      const status = row.getValue('ingestion_status') as string
      const color =
        status === 'complete'
          ? 'text-green-400'
          : status === 'failed'
          ? 'text-red-400'
          : status === 'ingesting'
          ? 'text-yellow-400'
          : 'text-slate-400'
      return (
        <div className={color}>
          {status.charAt(0).toUpperCase() + status.slice(1)}
        </div>
      )
    },
  },
  {
    accessorKey: 'created_at',
    header: 'Created',
    cell: ({ row }) => {
      const date = new Date(row.getValue('created_at') as string)
      return <div className="text-slate-400 text-sm">{date.toLocaleDateString()}</div>
    },
  },
]
