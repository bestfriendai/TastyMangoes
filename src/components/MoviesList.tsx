//  MoviesList.tsx
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-22 at 13:00 (America/Los_Angeles - Pacific Time)
//  Notes: Movies list component showing all movies in database

'use client'

import { useState, useEffect, useCallback } from 'react'
import { supabase, Movie } from '@/lib/supabase'
import DataTable from '@/components/DataTable'
import { moviesColumns } from '@/components/columns/moviesColumns'

interface MovieStats {
  total: number
  complete: number
  ingesting: number
  failed: number
  pending: number
}

export interface MoviesListRef {
  refresh: () => void
}

const MoviesList = forwardRef<MoviesListRef>((props, ref) => {
  const [movies, setMovies] = useState<Movie[]>([])
  const [stats, setStats] = useState<MovieStats>({
    total: 0,
    complete: 0,
    ingesting: 0,
    failed: 0,
    pending: 0,
  })
  const [isLoading, setIsLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'complete' | 'ingesting' | 'failed' | 'pending'>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedMovie, setSelectedMovie] = useState<Movie | null>(null)
  const [currentPage, setCurrentPage] = useState(1)
  const [pageSize] = useState(250)
  const [totalCount, setTotalCount] = useState(0)

  const fetchMovies = useCallback(async () => {
    setIsLoading(true)
    try {
      // First, get total count for stats and pagination
      let countQuery = supabase.from('works').select('*', { count: 'exact', head: true })
      if (filter !== 'all') {
        countQuery = countQuery.eq('ingestion_status', filter)
      }
      if (searchQuery) {
        const searchPattern = `%${searchQuery}%`
        countQuery = countQuery.or(`title.ilike.${searchPattern},original_title.ilike.${searchPattern}`)
      }
      const { count: totalCountResult } = await countQuery
      setTotalCount(totalCountResult || 0)

      // Then fetch the actual data with pagination
      let query = supabase.from('works').select('*').order('created_at', { ascending: false })

      if (filter !== 'all') {
        query = query.eq('ingestion_status', filter)
      }

      if (searchQuery) {
        // Search in both title and original_title
        // Use PostgREST or() syntax: column.operator.value,column.operator.value
        const searchPattern = `%${searchQuery}%`
        query = query.or(`title.ilike.${searchPattern},original_title.ilike.${searchPattern}`)
      }

      // Apply pagination
      const from = (currentPage - 1) * pageSize
      const to = from + pageSize - 1
      const { data, error } = await query.range(from, to)

      if (error) {
        console.error('Error fetching movies:', error)
        return
      }

      setMovies(data || [])
      
      // Calculate stats from all data, not just returned
      if (totalCountResult !== null) {
        // Fetch counts for each status if filter is 'all'
        if (filter === 'all' && !searchQuery) {
          const [completeRes, ingestingRes, failedRes, pendingRes] = await Promise.all([
            supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'complete'),
            supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'ingesting'),
            supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'failed'),
            supabase.from('works').select('*', { count: 'exact', head: true }).eq('ingestion_status', 'pending'),
          ])
          
          setStats({
            total: totalCountResult,
            complete: completeRes.count || 0,
            ingesting: ingestingRes.count || 0,
            failed: failedRes.count || 0,
            pending: pendingRes.count || 0,
          })
        } else {
          // If filtered or searched, calculate from returned data
          calculateStats(data || [])
        }
      } else {
        calculateStats(data || [])
      }
    } catch (error) {
      console.error('Error:', error)
    } finally {
      setIsLoading(false)
    }
  }, [filter, searchQuery, currentPage, pageSize])

  const calculateStats = (moviesData: Movie[]) => {
    setStats({
      total: moviesData.length,
      complete: moviesData.filter((m) => m.ingestion_status === 'complete').length,
      ingesting: moviesData.filter((m) => m.ingestion_status === 'ingesting').length,
      failed: moviesData.filter((m) => m.ingestion_status === 'failed').length,
      pending: moviesData.filter((m) => m.ingestion_status === 'pending').length,
    })
  }

  // Reset to page 1 when filter or search changes
  useEffect(() => {
    setCurrentPage(1)
  }, [filter, searchQuery])

  // Expose refresh function via ref
  useImperativeHandle(ref, () => ({
    refresh: () => {
      console.log('🔄 MoviesList.refresh() called')
      fetchMovies()
    },
  }), [fetchMovies])

  // Query database directly for "Planet of the Apes" on mount
  useEffect(() => {
    const checkPlanetOfTheApes = async () => {
      try {
        const { data, error } = await supabase
          .from('works')
          .select('*')
          .or('title.ilike.%Planet of the Apes%,original_title.ilike.%Planet of the Apes%')
          .limit(10)
        
        if (error) {
          console.error('Error checking for Planet of the Apes:', error)
        } else if (data && data.length > 0) {
          console.log(`✅ Found ${data.length} "Planet of the Apes" movie(s) in database:`, data.map(m => `${m.title} (${m.year})`))
        } else {
          console.log('⚠️ "Planet of the Apes" not found in database')
        }
      } catch (error) {
        console.error('Error checking for Planet of the Apes:', error)
      }
    }
    
    checkPlanetOfTheApes()
  }, [])

  useEffect(() => {
    fetchMovies()

    // Subscribe to real-time updates
    const channel = supabase
      .channel('works-changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'works',
        },
        () => {
          fetchMovies()
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [fetchMovies])

  const filteredMovies = movies

  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div className="bg-slate-800 rounded-lg p-4">
          <div className="text-sm text-slate-400">Total Movies</div>
          <div className="text-2xl font-bold text-white">{stats.total.toLocaleString()}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4">
          <div className="text-sm text-slate-400">Complete</div>
          <div className="text-2xl font-bold text-green-400">{stats.complete.toLocaleString()}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4">
          <div className="text-sm text-slate-400">Ingesting</div>
          <div className="text-2xl font-bold text-yellow-400">{stats.ingesting.toLocaleString()}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4">
          <div className="text-sm text-slate-400">Failed</div>
          <div className="text-2xl font-bold text-red-400">{stats.failed.toLocaleString()}</div>
        </div>
        <div className="bg-slate-800 rounded-lg p-4">
          <div className="text-sm text-slate-400">Pending</div>
          <div className="text-2xl font-bold text-slate-400">{stats.pending.toLocaleString()}</div>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex items-center gap-4">
        <div className="flex gap-2">
          {(['all', 'complete', 'ingesting', 'failed', 'pending'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded text-sm font-medium transition-colors ${
                filter === f
                  ? f === 'all'
                    ? 'bg-orange-600 text-white'
                    : f === 'complete'
                    ? 'bg-green-600 text-white'
                    : f === 'ingesting'
                    ? 'bg-yellow-600 text-white'
                    : f === 'failed'
                    ? 'bg-red-600 text-white'
                    : 'bg-slate-600 text-white'
                  : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
        <input
          type="text"
          placeholder="Search movies..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="flex-1 px-4 py-2 bg-slate-800 text-slate-200 rounded border border-slate-700 focus:outline-none focus:border-orange-500"
        />
        <span className="text-slate-500 text-sm">
          Showing {((currentPage - 1) * pageSize) + 1}-{Math.min(currentPage * pageSize, totalCount)} of {totalCount.toLocaleString()} movies
        </span>
        <button
          onClick={fetchMovies}
          className="px-4 py-2 bg-slate-800 text-slate-200 rounded font-medium hover:bg-slate-700 transition-colors"
        >
          Refresh
        </button>
      </div>

      {/* Movies Table */}
      {isLoading ? (
        <div className="text-center py-12 text-slate-400">Loading...</div>
      ) : (
        <>
          <DataTable
            columns={moviesColumns}
            data={filteredMovies}
            onRowClick={(movie) => setSelectedMovie(movie)}
            selectedRowId={selectedMovie?.work_id.toString() ?? null}
            getRowId={(movie) => movie.work_id.toString()}
          />
          
          {/* Pagination Controls */}
          {totalCount > pageSize && (
            <div className="flex items-center justify-between mt-6">
              <div className="text-slate-400 text-sm">
                Page {currentPage} of {Math.ceil(totalCount / pageSize)}
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                  disabled={currentPage === 1}
                  className={`px-4 py-2 rounded font-medium transition-colors ${
                    currentPage === 1
                      ? 'bg-slate-800 text-slate-600 cursor-not-allowed'
                      : 'bg-slate-800 text-slate-200 hover:bg-slate-700'
                  }`}
                >
                  Previous
                </button>
                <button
                  onClick={() => setCurrentPage(prev => Math.min(Math.ceil(totalCount / pageSize), prev + 1))}
                  disabled={currentPage >= Math.ceil(totalCount / pageSize)}
                  className={`px-4 py-2 rounded font-medium transition-colors ${
                    currentPage >= Math.ceil(totalCount / pageSize)
                      ? 'bg-slate-800 text-slate-600 cursor-not-allowed'
                      : 'bg-slate-800 text-slate-200 hover:bg-slate-700'
                  }`}
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </>
      )}

      {/* Movie Detail Panel */}
      {selectedMovie && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-slate-800 rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-bold text-white">{selectedMovie.title}</h2>
              <button
                onClick={() => setSelectedMovie(null)}
                className="text-slate-400 hover:text-white"
              >
                ✕
              </button>
            </div>
            <div className="space-y-3 text-sm">
              <div>
                <span className="text-slate-400">TMDB ID:</span>{' '}
                <span className="text-white">{selectedMovie.tmdb_id}</span>
              </div>
              {selectedMovie.imdb_id && (
                <div>
                  <span className="text-slate-400">IMDB ID:</span>{' '}
                  <span className="text-white">{selectedMovie.imdb_id}</span>
                </div>
              )}
              <div>
                <span className="text-slate-400">Year:</span>{' '}
                <span className="text-white">{selectedMovie.year || 'N/A'}</span>
              </div>
              <div>
                <span className="text-slate-400">Release Date:</span>{' '}
                <span className="text-white">
                  {selectedMovie.release_date
                    ? new Date(selectedMovie.release_date).toLocaleDateString()
                    : 'N/A'}
                </span>
              </div>
              <div>
                <span className="text-slate-400">Status:</span>{' '}
                <span
                  className={
                    selectedMovie.ingestion_status === 'complete'
                      ? 'text-green-400'
                      : selectedMovie.ingestion_status === 'failed'
                      ? 'text-red-400'
                      : selectedMovie.ingestion_status === 'ingesting'
                      ? 'text-yellow-400'
                      : 'text-slate-400'
                  }
                >
                  {selectedMovie.ingestion_status}
                </span>
              </div>
              <div>
                <span className="text-slate-400">Created:</span>{' '}
                <span className="text-white">
                  {new Date(selectedMovie.created_at).toLocaleString()}
                </span>
              </div>
              {selectedMovie.last_refreshed_at && (
                <div>
                  <span className="text-slate-400">Last Refreshed:</span>{' '}
                  <span className="text-white">
                    {new Date(selectedMovie.last_refreshed_at).toLocaleString()}
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
})

MoviesList.displayName = 'MoviesList'

export default MoviesList
