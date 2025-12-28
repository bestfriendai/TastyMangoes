//  TMDBAnalytics.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: TMDB API Analytics dashboard component

'use client'

import { useState, useEffect, useCallback, forwardRef, useImperativeHandle } from 'react'
import { supabase, TMDBAPILog } from '@/lib/supabase'
import DataTable from '@/components/DataTable'
import { tmdbLogsColumns } from '@/components/columns/tmdbLogsColumns'

interface TMDBStats {
  totalCalls: number
  uniqueEndpoints: number
  avgResponseTime: number
  errorRate: number
  callsToday: number
  callsThisWeek: number
}

interface MovieDatabaseStats {
  totalMovies: number
  moviesWithPosters: number
  moviesWithTrailers: number
  complete: number
  pending: number
  ingesting: number
  failed: number
  ingestedToday: number
  ingestedThisWeek: number
}

export interface TMDBAnalyticsRef {
  refresh: () => void
}

const TMDBAnalytics = forwardRef<TMDBAnalyticsRef>((props, ref) => {
  const [logs, setLogs] = useState<TMDBAPILog[]>([])
  const [stats, setStats] = useState<TMDBStats>({
    totalCalls: 0,
    uniqueEndpoints: 0,
    avgResponseTime: 0,
    errorRate: 0,
    callsToday: 0,
    callsThisWeek: 0,
  })
  const [movieStats, setMovieStats] = useState<MovieDatabaseStats>({
    totalMovies: 0,
    moviesWithPosters: 0,
    moviesWithTrailers: 0,
    complete: 0,
    pending: 0,
    ingesting: 0,
    failed: 0,
    ingestedToday: 0,
    ingestedThisWeek: 0,
  })
  const [isLoading, setIsLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'success' | 'error'>('all')
  const [endpointFilter, setEndpointFilter] = useState<string>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedLog, setSelectedLog] = useState<TMDBAPILog | null>(null)

  const fetchLogs = useCallback(async () => {
    setIsLoading(true)
    try {
      let query = supabase
        .from('tmdb_api_logs')
        .select('*')
        .order('created_at', { ascending: false })
      
      // Apply search filter if provided (search in user_query, endpoint, or edge_function)
      if (searchQuery) {
        query = query.or(`user_query.ilike.%${searchQuery}%,endpoint.ilike.%${searchQuery}%,edge_function.ilike.%${searchQuery}%`)
      }
      
      // Apply endpoint filter if not 'all'
      if (endpointFilter !== 'all') {
        query = query.eq('endpoint', endpointFilter)
      }
      
      const { data, error } = await query.limit(1000)
      
      if (error) {
        console.error('Error fetching TMDB logs:', error)
        return
      }
      
      console.log(`[TMDBAnalytics] Fetched ${data?.length || 0} logs`, {
        searchQuery,
        endpointFilter,
        sampleLogs: data?.slice(0, 3).map(log => ({
          endpoint: log.endpoint,
          edge_function: log.edge_function,
          user_query: log.user_query,
          created_at: log.created_at,
        }))
      })
      
      // Log specific search for "Planet of the apes" if no search query
      if (!searchQuery && !endpointFilter) {
        const planetLogs = data?.filter(log => 
          log.user_query?.toLowerCase().includes('planet') && 
          log.user_query?.toLowerCase().includes('apes')
        ) || []
        if (planetLogs.length > 0) {
          console.log(`✅ Found ${planetLogs.length} "Planet of the apes" logs:`, planetLogs.map(log => ({
            endpoint: log.endpoint,
            edge_function: log.edge_function,
            user_query: log.user_query,
            created_at: log.created_at,
          })))
        } else {
          console.log('⚠️ No "Planet of the apes" logs found in database')
        }
      }

      setLogs(data || [])
      calculateStats(data || [])
    } catch (error) {
      console.error('Error:', error)
    } finally {
      setIsLoading(false)
    }
  }, [searchQuery, endpointFilter])

  // Expose refresh function via ref
  useImperativeHandle(ref, () => ({
    refresh: () => {
      console.log('🔄 TMDBAnalytics.refresh() called')
      fetchLogs()
      fetchMovieStats()
    },
  }), [fetchLogs, fetchMovieStats])

  const fetchMovieStats = useCallback(async () => {
    try {
      console.log('[TMDBAnalytics v2] Fetching movie stats...')
      const now = new Date()
      const todayStart = new Date(now.setHours(0, 0, 0, 0))
      const weekStart = new Date(now.setDate(now.getDate() - 7))

      // Get total movies and status breakdown
      const [totalRes, completeRes, pendingRes, ingestingRes, failedRes, postersRes, trailersRes, todayRes, weekRes] = await Promise.all([
        supabase.from('works').select('*', { count: 'exact', head: true }),
        supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'complete'),
        supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'pending'),
        supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'ingesting'),
        supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'failed'),
        supabase.from('works_meta').select('work_id', { count: 'exact', head: true }).not('poster_url_medium', 'is', null),
        supabase.from('works_meta').select('work_id', { count: 'exact', head: true }).not('trailer_youtube_id', 'is', null),
        supabase.from('works').select('*', { count: 'exact', head: true }).gte('created_at', todayStart.toISOString()),
        supabase.from('works').select('*', { count: 'exact', head: true }).gte('created_at', weekStart.toISOString()),
      ])

      const stats = {
        totalMovies: totalRes.count || 0,
        moviesWithPosters: postersRes.count || 0,
        moviesWithTrailers: trailersRes.count || 0,
        complete: completeRes.count || 0,
        pending: pendingRes.count || 0,
        ingesting: ingestingRes.count || 0,
        failed: failedRes.count || 0,
        ingestedToday: todayRes.count || 0,
        ingestedThisWeek: weekRes.count || 0,
      }

      console.log('[TMDBAnalytics v2] Movie stats fetched:', stats)
      setMovieStats(stats)
    } catch (error) {
      console.error('[TMDBAnalytics v2] Error fetching movie stats:', error)
    }
  }, [])

  const calculateStats = (logsData: TMDBAPILog[]) => {
    const now = new Date()
    const todayStart = new Date(now.setHours(0, 0, 0, 0))
    const weekStart = new Date(now.setDate(now.getDate() - 7))

    const callsToday = logsData.filter(
      (log) => new Date(log.created_at) >= todayStart
    ).length

    const callsThisWeek = logsData.filter(
      (log) => new Date(log.created_at) >= weekStart
    ).length

    const successfulCalls = logsData.filter(
      (log) => log.http_status && log.http_status >= 200 && log.http_status < 300
    )
    const errorCalls = logsData.filter(
      (log) => log.http_status === null || log.http_status >= 400 || log.error_message
    )

    const avgResponseTime =
      logsData.length > 0
        ? Math.round(
            logsData.reduce((sum, log) => sum + log.response_time_ms, 0) /
              logsData.length
          )
        : 0

    const uniqueEndpoints = new Set(logsData.map((log) => log.endpoint)).size

    setStats({
      totalCalls: logsData.length,
      uniqueEndpoints,
      avgResponseTime,
      errorRate:
        logsData.length > 0
          ? Math.round((errorCalls.length / logsData.length) * 100)
          : 0,
      callsToday,
      callsThisWeek,
    })
  }

  // Reset search when component mounts to show all logs initially
  useEffect(() => {
    setSearchQuery('')
    setEndpointFilter('all')
  }, [])

  useEffect(() => {
    fetchLogs()
    fetchMovieStats()

    // Subscribe to real-time updates
    const channel = supabase
      .channel('tmdb-api-logs-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'tmdb_api_logs',
        },
        () => {
          fetchLogs()
        }
      )
      .subscribe()

    const worksChannel = supabase
      .channel('works-changes-for-stats')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'works',
        },
        () => {
          fetchMovieStats()
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
      supabase.removeChannel(worksChannel)
    }
  }, [fetchLogs, fetchMovieStats])

  const filteredLogs = logs.filter((log) => {
    if (filter === 'success') {
      return log.http_status && log.http_status >= 200 && log.http_status < 300
    }
    if (filter === 'error') {
      return log.http_status === null || log.http_status >= 400 || log.error_message
    }
    if (endpointFilter !== 'all') {
      return log.endpoint === endpointFilter
    }
    return true
  })

  const uniqueEndpoints = Array.from(new Set(logs.map((log) => log.endpoint))).sort()

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-white">TMDB Analytics v2</h1>
        <div className="text-sm text-slate-400">Direct database queries - all fields shown</div>
      </div>

      {/* Movie Database Stats Section */}
      <div>
        <h2 className="text-xl font-semibold text-white mb-4">Movie Database Stats</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Total Movies</div>
            <div className="text-2xl font-bold text-white">{movieStats.totalMovies.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">With Posters</div>
            <div className="text-2xl font-bold text-green-400">{movieStats.moviesWithPosters.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">With Trailers</div>
            <div className="text-2xl font-bold text-blue-400">{movieStats.moviesWithTrailers.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Ingested Today</div>
            <div className="text-2xl font-bold text-cyan-400">{movieStats.ingestedToday.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Ingested This Week</div>
            <div className="text-2xl font-bold text-cyan-400">{movieStats.ingestedThisWeek.toLocaleString()}</div>
          </div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mt-4">
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Complete</div>
            <div className="text-2xl font-bold text-green-400">{movieStats.complete.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Pending</div>
            <div className="text-2xl font-bold text-yellow-400">{movieStats.pending.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Ingesting</div>
            <div className="text-2xl font-bold text-blue-400">{movieStats.ingesting.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Failed</div>
            <div className="text-2xl font-bold text-red-400">{movieStats.failed.toLocaleString()}</div>
          </div>
        </div>
      </div>

      {/* TMDB API Calls Stats Section */}
      <div>
        <h2 className="text-xl font-semibold text-white mb-4">TMDB API Calls</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Total Calls</div>
            <div className="text-2xl font-bold text-white">{stats.totalCalls.toLocaleString()}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Endpoints</div>
            <div className="text-2xl font-bold text-white">{stats.uniqueEndpoints}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Avg Response</div>
            <div className="text-2xl font-bold text-white">{stats.avgResponseTime}ms</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Error Rate</div>
            <div className="text-2xl font-bold text-red-400">{stats.errorRate}%</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">Today</div>
            <div className="text-2xl font-bold text-white">{stats.callsToday}</div>
          </div>
          <div className="bg-slate-800 rounded-lg p-4">
            <div className="text-sm text-slate-400">This Week</div>
            <div className="text-2xl font-bold text-white">{stats.callsThisWeek}</div>
          </div>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex items-center gap-4 flex-wrap">
        <div className="flex gap-2">
          {(['all', 'success', 'error'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded text-sm font-medium transition-colors ${
                filter === f
                  ? f === 'all'
                    ? 'bg-orange-600 text-white'
                    : f === 'success'
                    ? 'bg-green-600 text-white'
                    : 'bg-red-600 text-white'
                  : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
              }`}
            >
              {f === 'all' && 'All'}
              {f === 'success' && '✓ Success'}
              {f === 'error' && '✗ Errors'}
            </button>
          ))}
        </div>
        <select
          value={endpointFilter}
          onChange={(e) => setEndpointFilter(e.target.value)}
          className="px-3 py-1.5 rounded text-sm bg-slate-800 text-slate-200 border border-slate-700"
        >
          <option value="all">All Endpoints</option>
          {uniqueEndpoints.map((endpoint) => (
            <option key={endpoint} value={endpoint}>
              {endpoint}
            </option>
          ))}
        </select>
        <input
          type="text"
          placeholder="Search by user query (e.g., 'Planet of the apes')..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="flex-1 min-w-[200px] px-4 py-2 bg-slate-800 text-slate-200 rounded border border-slate-700 focus:outline-none focus:border-orange-500"
        />
        <span className="text-slate-500 text-sm whitespace-nowrap">{filteredLogs.length} logs</span>
        <button
          onClick={fetchLogs}
          className="px-4 py-2 bg-slate-800 text-slate-200 rounded font-medium hover:bg-slate-700 transition-colors whitespace-nowrap"
        >
          Refresh
        </button>
      </div>

      {/* Logs Table */}
      {isLoading ? (
        <div className="text-center py-12 text-slate-400">Loading...</div>
      ) : filteredLogs.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-slate-400 mb-2">No logs found</div>
          {searchQuery || endpointFilter !== 'all' ? (
            <div className="text-slate-500 text-sm">
              Try clearing filters or search query to see all logs
            </div>
          ) : (
            <div className="text-slate-500 text-sm">
              No TMDB API logs in database. Logs will appear here when API calls are made.
            </div>
          )}
        </div>
      ) : (
        <DataTable
          columns={tmdbLogsColumns}
          data={filteredLogs}
          onRowClick={(log) => setSelectedLog(log)}
          selectedRowId={selectedLog?.id.toString() ?? null}
          getRowId={(log) => log.id.toString()}
        />
      )}

      {/* Log Detail Panel */}
      {selectedLog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-bold text-white">TMDB API Call Details</h2>
              <button
                onClick={() => setSelectedLog(null)}
                className="text-slate-400 hover:text-white"
              >
                ✕
              </button>
            </div>
            <div className="space-y-3 text-sm">
              <div>
                <span className="text-slate-400">Endpoint:</span>{' '}
                <span className="text-white font-mono">{selectedLog.endpoint}</span>
              </div>
              <div>
                <span className="text-slate-400">Method:</span>{' '}
                <span className="text-white">{selectedLog.method}</span>
              </div>
              <div>
                <span className="text-slate-400">Status:</span>{' '}
                <span
                  className={
                    selectedLog.http_status && selectedLog.http_status >= 200 && selectedLog.http_status < 300
                      ? 'text-green-400'
                      : 'text-red-400'
                  }
                >
                  {selectedLog.http_status || 'N/A'}
                </span>
              </div>
              <div>
                <span className="text-slate-400">Response Time:</span>{' '}
                <span className="text-white">{selectedLog.response_time_ms}ms</span>
              </div>
              <div>
                <span className="text-slate-400">Edge Function:</span>{' '}
                <span className="text-white">{selectedLog.edge_function || 'N/A'}</span>
              </div>
              {selectedLog.user_query && (
                <div>
                  <span className="text-slate-400">User Query:</span>{' '}
                  <span className="text-white">{selectedLog.user_query}</span>
                </div>
              )}
              {selectedLog.tmdb_id && (
                <div>
                  <span className="text-slate-400">TMDB ID:</span>{' '}
                  <span className="text-white">{selectedLog.tmdb_id}</span>
                </div>
              )}
              {selectedLog.query_params && (
                <div>
                  <span className="text-slate-400">Query Params:</span>
                  <pre className="mt-1 p-2 bg-slate-900 rounded text-xs overflow-x-auto">
                    {JSON.stringify(selectedLog.query_params, null, 2)}
                  </pre>
                </div>
              )}
              {selectedLog.error_message && (
                <div>
                  <span className="text-slate-400">Error:</span>{' '}
                  <span className="text-red-400">{selectedLog.error_message}</span>
                </div>
              )}
              <div>
                <span className="text-slate-400">Created At:</span>{' '}
                <span className="text-white">
                  {new Date(selectedLog.created_at).toLocaleString()}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
})

TMDBAnalytics.displayName = 'TMDBAnalytics'

export default TMDBAnalytics
