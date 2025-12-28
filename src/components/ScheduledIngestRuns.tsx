//  ScheduledIngestRuns.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:55 (America/Los_Angeles - Pacific Time)
//  Notes: Dashboard component showing scheduled ingestion run history

'use client'

import { useState, useEffect, useCallback, forwardRef, useImperativeHandle } from 'react'
import { supabase, ScheduledIngestRun } from '@/lib/supabase'
import DataTable from '@/components/DataTable'
import { scheduledIngestRunsColumns } from '@/components/columns/scheduledIngestRunsColumns'

export interface ScheduledIngestRunsRef {
  refresh: () => void
}

const ScheduledIngestRuns = forwardRef<ScheduledIngestRunsRef>((props, ref) => {
  const [runs, setRuns] = useState<ScheduledIngestRun[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [selectedRun, setSelectedRun] = useState<ScheduledIngestRun | null>(null)
  const [expandedRows, setExpandedRows] = useState<Set<number>>(new Set())

  const fetchRuns = useCallback(async () => {
    setIsLoading(true)
    try {
      const { data, error } = await supabase
        .from('scheduled_ingestion_log')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50)

      if (error) {
        console.error('Error fetching scheduled ingestion runs:', error)
        return
      }

      setRuns(data || [])
    } catch (err) {
      console.error('Exception fetching scheduled ingestion runs:', err)
    } finally {
      setIsLoading(false)
    }
  }, [])

  useImperativeHandle(ref, () => ({
    refresh: fetchRuns,
  }))

  useEffect(() => {
    fetchRuns()
  }, [fetchRuns])

  const toggleRowExpansion = (runId: number) => {
    setExpandedRows((prev) => {
      const next = new Set(prev)
      if (next.has(runId)) {
        next.delete(runId)
      } else {
        next.add(runId)
      }
      return next
    })
  }

  // Calculate summary stats
  const stats = {
    totalRuns: runs.length,
    totalIngested: runs.reduce((sum, r) => sum + r.movies_ingested, 0),
    totalFailed: runs.reduce((sum, r) => sum + r.movies_failed, 0),
    avgDuration: runs.length > 0
      ? Math.round(runs.reduce((sum, r) => sum + r.duration_ms, 0) / runs.length)
      : 0,
    scheduledCount: runs.filter((r) => r.trigger_type === 'scheduled').length,
    manualCount: runs.filter((r) => r.trigger_type === 'manual').length,
  }

  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-slate-800 rounded-lg p-4 border border-slate-700">
          <div className="text-slate-400 text-sm mb-1">Total Runs</div>
          <div className="text-2xl font-bold text-slate-100">{stats.totalRuns}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 border border-slate-700">
          <div className="text-slate-400 text-sm mb-1">Total Ingested</div>
          <div className="text-2xl font-bold text-green-400">{stats.totalIngested}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 border border-slate-700">
          <div className="text-slate-400 text-sm mb-1">Total Failed</div>
          <div className="text-2xl font-bold text-red-400">{stats.totalFailed}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 border border-slate-700">
          <div className="text-slate-400 text-sm mb-1">Avg Duration</div>
          <div className="text-2xl font-bold text-slate-100">
            {(stats.avgDuration / 1000).toFixed(1)}s
          </div>
        </div>
      </div>

      {/* Trigger Type Breakdown */}
      <div className="flex gap-4 text-sm">
        <div className="text-slate-400">
          <span className="text-blue-400">⏰ Scheduled:</span> {stats.scheduledCount}
        </div>
        <div className="text-slate-400">
          <span className="text-purple-400">👤 Manual:</span> {stats.manualCount}
        </div>
      </div>

      {/* Runs Table */}
      {isLoading ? (
        <div className="text-center py-8 text-slate-400">Loading runs...</div>
      ) : runs.length === 0 ? (
        <div className="text-center py-8 text-slate-400">
          No scheduled ingestion runs found. Trigger a run to see results here.
        </div>
      ) : (
        <div className="space-y-2">
          {runs.map((run) => {
            const isExpanded = expandedRows.has(run.id)
            return (
              <div
                key={run.id}
                className="bg-slate-800 rounded-lg border border-slate-700 overflow-hidden"
              >
                {/* Main Row */}
                <div
                  className="p-4 cursor-pointer hover:bg-slate-750 transition-colors"
                  onClick={() => toggleRowExpansion(run.id)}
                >
                  <div className="grid grid-cols-8 gap-4 items-center">
                    <div>
                      <div className="text-slate-200 font-medium">
                        {new Date(run.created_at).toLocaleString()}
                      </div>
                      <div className="text-xs text-slate-400">
                        {run.trigger_type === 'scheduled' ? '⏰ Scheduled' : '👤 Manual'}
                      </div>
                    </div>
                    <div className="text-slate-300">
                      {run.source === 'mixed' ? '🌐 Mixed' : 
                       run.source === 'popular' ? '🔥 Popular' :
                       run.source === 'now_playing' ? '🎬 Now Playing' :
                       run.source === 'trending' ? '📈 Trending' : run.source}
                    </div>
                    <div className="text-slate-300">Checked: {run.movies_checked}</div>
                    <div className="text-slate-400">Skipped: {run.movies_skipped}</div>
                    <div className="text-green-400 font-medium">Ingested: {run.movies_ingested}</div>
                    <div className={run.movies_failed > 0 ? 'text-red-400 font-medium' : 'text-slate-500'}>
                      Failed: {run.movies_failed}
                    </div>
                    <div className="text-slate-300 text-sm">
                      {(run.duration_ms / 1000).toFixed(1)}s
                      <span className="ml-2 text-slate-500">
                        {isExpanded ? '▲' : '▼'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Expanded Details */}
                {isExpanded && (
                  <div className="border-t border-slate-700 p-4 bg-slate-850">
                    <div className="grid grid-cols-2 gap-6">
                      {/* Ingested Titles */}
                      <div>
                        <div className="text-sm font-medium text-slate-300 mb-2">
                          ✅ Ingested Movies ({run.ingested_titles?.length || 0})
                        </div>
                        {run.ingested_titles && run.ingested_titles.length > 0 ? (
                          <ul className="space-y-1">
                            {run.ingested_titles.map((title, idx) => (
                              <li key={idx} className="text-sm text-slate-400">
                                • {title}
                              </li>
                            ))}
                          </ul>
                        ) : (
                          <div className="text-sm text-slate-500">None</div>
                        )}
                      </div>

                      {/* Failed Titles */}
                      <div>
                        <div className="text-sm font-medium text-slate-300 mb-2">
                          ❌ Failed Movies ({run.failed_titles?.length || 0})
                        </div>
                        {run.failed_titles && run.failed_titles.length > 0 ? (
                          <ul className="space-y-1">
                            {run.failed_titles.map((title, idx) => (
                              <li key={idx} className="text-sm text-red-400">
                                • {title}
                              </li>
                            ))}
                          </ul>
                        ) : (
                          <div className="text-sm text-slate-500">None</div>
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
})

ScheduledIngestRuns.displayName = 'ScheduledIngestRuns'

export default ScheduledIngestRuns

