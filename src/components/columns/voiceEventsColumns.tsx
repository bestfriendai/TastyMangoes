// voiceEventsColumns.tsx
// Created automatically by Cursor Assistant
// Created on: 2025-01-15 at 14:35 (America/Los_Angeles - Pacific Time)
// Notes: Column definitions for voice events data table with result badges and command type display

import { ColumnDef } from '@tanstack/react-table'
import { VoiceEvent } from '@/lib/supabase'
import { formatDistanceToNow, format } from 'date-fns'

// Result badge component
function ResultBadge({ event }: { event: VoiceEvent }) {
  if (!event.handler_result) {
    return (
      <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-700 text-slate-400">
        —
      </span>
    )
  }

  const colors: Record<string, string> = {
    success: 'bg-green-900/50 text-green-400 border-green-800',
    no_results: 'bg-amber-900/50 text-amber-400 border-amber-800',
    ambiguous: 'bg-blue-900/50 text-blue-400 border-blue-800',
    network_error: 'bg-red-900/50 text-red-400 border-red-800',
    parse_error: 'bg-red-900/50 text-red-400 border-red-800',
  }

  const labels: Record<string, string> = {
    success: '✓',
    no_results: '∅',
    ambiguous: '?',
    network_error: '⚠',
    parse_error: '✗',
  }

  return (
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium border ${
        colors[event.handler_result] || 'bg-slate-700 text-slate-400'
      }`}
    >
      {labels[event.handler_result] || event.handler_result}
      {event.result_count !== null && event.handler_result === 'success' && (
        <span className="opacity-70">({event.result_count})</span>
      )}
    </span>
  )
}

// Command type badge
function CommandType({ event }: { event: VoiceEvent }) {
  const type = event.final_command_type || event.mango_command_type
  const typeColors: Record<string, string> = {
    movie_search: 'text-blue-400',
    recommender_search: 'text-purple-400',
    markWatched: 'text-green-400',
    unknown: 'text-slate-500',
  }

  return <span className={typeColors[type] || 'text-slate-400'}>{type}</span>
}

export const voiceEventsColumns: ColumnDef<VoiceEvent>[] = [
  {
    id: 'time',
    accessorKey: 'created_at',
    header: 'TIME',
    size: 120,
    cell: ({ row }) => {
      const createdAt = new Date(row.original.created_at)
      const timeAgo = formatDistanceToNow(createdAt, { addSuffix: true })
      const fullTime = format(createdAt, 'HH:mm:ss')

      return (
        <div className="text-sm">
          <div className="text-slate-300 font-medium">{fullTime}</div>
          <div className="text-xs text-slate-500">{timeAgo}</div>
        </div>
      )
    },
    sortingFn: (rowA, rowB) => {
      return new Date(rowA.original.created_at).getTime() - new Date(rowB.original.created_at).getTime()
    },
  },
  {
    id: 'utterance',
    accessorKey: 'utterance',
    header: 'UTTERANCE',
    size: 300,
    cell: ({ row }) => {
      const event = row.original
      return (
        <div>
          <div className="text-slate-200 truncate" title={event.utterance}>
            "{event.utterance}"
          </div>
          {event.mango_command_movie_title && (
            <div className="text-xs text-slate-500 mt-0.5">
              🎬 {event.mango_command_movie_title}
            </div>
          )}
          {event.mango_command_recommender && (
            <div className="text-xs text-slate-500 mt-0.5">
              👤 {event.mango_command_recommender}
            </div>
          )}
        </div>
      )
    },
  },
  {
    id: 'command',
    accessorKey: 'final_command_type',
    header: 'COMMAND',
    size: 140,
    cell: ({ row }) => <CommandType event={row.original} />,
  },
  {
    id: 'result',
    accessorKey: 'handler_result',
    header: 'RESULT',
    size: 100,
    cell: ({ row }) => <ResultBadge event={row.original} />,
  },
  {
    id: 'llm',
    accessorKey: 'llm_used',
    header: 'LLM',
    size: 60,
    cell: ({ row }) =>
      row.original.llm_used ? (
        <span className="text-amber-400" title="LLM fallback was used">
          🤖
        </span>
      ) : (
        <span className="text-slate-600">—</span>
      ),
  },
]
