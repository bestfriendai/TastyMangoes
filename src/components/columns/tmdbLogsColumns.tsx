//  tmdbLogsColumns.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: Column definitions for TMDB API logs table

import { ColumnDef } from '@tanstack/react-table'
import { TMDBAPILog } from '@/lib/supabase'

export const tmdbLogsColumns: ColumnDef<TMDBAPILog>[] = [
  {
    accessorKey: 'created_at',
    header: 'Time',
    cell: ({ row }) => {
      const date = new Date(row.getValue('created_at'))
      return <div className="text-slate-300">{date.toLocaleTimeString()}</div>
    },
  },
  {
    accessorKey: 'endpoint',
    header: 'Endpoint',
    cell: ({ row }) => {
      const endpoint = row.getValue('endpoint') as string
      return (
        <div className="font-mono text-sm text-slate-200" title={endpoint}>
          {endpoint || 'N/A'}
        </div>
      )
    },
  },
  {
    accessorKey: 'edge_function',
    header: 'Edge Function',
    cell: ({ row }) => {
      const func = row.getValue('edge_function') as string
      return (
        <div className="text-slate-300 font-medium" title={func || 'N/A'}>
          {func || 'N/A'}
        </div>
      )
    },
  },
  {
    accessorKey: 'user_query',
    header: 'User Query',
    cell: ({ row }) => {
      const query = row.getValue('user_query') as string
      return (
        <div className="text-slate-200 font-medium" title={query || 'N/A'}>
          {query || 'N/A'}
        </div>
      )
    },
  },
  {
    accessorKey: 'http_status',
    header: 'Status',
    cell: ({ row }) => {
      const status = row.getValue('http_status') as number | null
      const isSuccess = status && status >= 200 && status < 300
      return (
        <div className={isSuccess ? 'text-green-400' : 'text-red-400'}>
          {status || 'N/A'}
        </div>
      )
    },
  },
  {
    accessorKey: 'response_time_ms',
    header: 'Time (ms)',
    cell: ({ row }) => {
      const time = row.getValue('response_time_ms') as number
      const color = time > 1000 ? 'text-red-400' : time > 500 ? 'text-yellow-400' : 'text-green-400'
      return <div className={color}>{time.toLocaleString()}</div>
    },
  },
  {
    accessorKey: 'results_count',
    header: 'Results',
    cell: ({ row }) => {
      const count = row.getValue('results_count') as number | null
      return <div className="text-slate-300">{count || 'N/A'}</div>
    },
  },
]
