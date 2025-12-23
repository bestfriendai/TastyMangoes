'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase, VoiceEvent } from '@/lib/supabase'
import StatsBar from '@/components/StatsBar'
import DataTable from '@/components/DataTable'
import { voiceEventsColumns } from '@/components/columns/voiceEventsColumns'
import EventDetail from '@/components/EventDetail'
import PatternSuggestions from '@/components/PatternSuggestions'
import TMDBAnalytics, { TMDBAnalyticsRef } from '@/components/TMDBAnalytics'
import MoviesList, { MoviesListRef } from '@/components/MoviesList'

type Tab = 'events' | 'patterns' | 'tmdb' | 'movies'

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState<Tab>('events')
  const [events, setEvents] = useState<VoiceEvent[]>([])
  const [selectedEvent, setSelectedEvent] = useState<VoiceEvent | null>(null)
  const [isLive, setIsLive] = useState(true)
  const [filter, setFilter] = useState<'all' | 'success' | 'failed' | 'llm'>('all')
  const [newEventIds, setNewEventIds] = useState<Set<string>>(new Set())
  const [pendingPatternsCount, setPendingPatternsCount] = useState(0)
  
  // Refs for child component refresh functions
  const tmdbAnalyticsRef = useRef<TMDBAnalyticsRef | null>(null)
  const moviesListRef = useRef<MoviesListRef | null>(null)

  // Fetch initial events
  const fetchEvents = useCallback(async () => {
    const { data, error } = await supabase
      .from('voice_utterance_events')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100)

    if (error) {
      console.error('Error fetching events:', error)
      return
    }

    setEvents(data || [])
  }, [])

  // Fetch pending patterns count
  const fetchPendingCount = useCallback(async () => {
    const { count, error } = await supabase
      .from('voice_pattern_suggestions')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pending')

    if (!error && count !== null) {
      setPendingPatternsCount(count)
    }
  }, [])

  useEffect(() => {
    fetchEvents()
    fetchPendingCount()

    // Subscribe to real-time events
    const eventsChannel = supabase
      .channel('voice-events-changes')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'voice_utterance_events',
        },
        (payload) => {
          if (isLive) {
            const newEvent = payload.new as VoiceEvent
            setEvents((prev) => [newEvent, ...prev.slice(0, 99)])
            setNewEventIds((prev) => {
              const s = new Set(Array.from(prev))
              s.add(newEvent.id)
              return s
            })

            // Clear highlight after 3 seconds
            setTimeout(() => {
              setNewEventIds((prev) => {
                const updated = new Set(Array.from(prev))
                updated.delete(newEvent.id)
                return updated
              })
            }, 3000)
          }
        }
      )
      .subscribe()

    // Subscribe to pattern suggestions
    const patternsChannel = supabase
      .channel('pattern-suggestions-count')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'voice_pattern_suggestions',
        },
        () => {
          fetchPendingCount()
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(eventsChannel)
      supabase.removeChannel(patternsChannel)
    }
  }, [fetchEvents, fetchPendingCount, isLive])

  // Filter events
  const filteredEvents = events.filter((event) => {
    if (filter === 'all') return true
    if (filter === 'success') return event.handler_result === 'success'
    if (filter === 'failed')
      return event.handler_result === 'no_results' || event.handler_result === 'parse_error'
    if (filter === 'llm') return event.llm_used
    return true
  })

  // Master refresh function that refreshes all tabs
  const refreshAll = useCallback(() => {
    console.log('🔄 Refresh button clicked - refreshing all tabs')
    
    // Refresh events tab
    fetchEvents()
    fetchPendingCount()
    
    // Refresh TMDB Analytics tab (only if component is mounted)
    if (tmdbAnalyticsRef.current) {
      console.log('🔄 Refreshing TMDB Analytics')
      tmdbAnalyticsRef.current.refresh()
    } else {
      console.log('⚠️ TMDB Analytics ref not available')
    }
    
    // Refresh Movies tab (only if component is mounted)
    if (moviesListRef.current) {
      console.log('🔄 Refreshing Movies List')
      moviesListRef.current.refresh()
    } else {
      console.log('⚠️ Movies List ref not available')
    }
  }, [fetchEvents, fetchPendingCount])

  // Calculate stats
  const stats = {
    total: events.length,
    success: events.filter((e) => e.handler_result === 'success').length,
    failed: events.filter(
      (e) => e.handler_result === 'no_results' || e.handler_result === 'parse_error'
    ).length,
    llmUsed: events.filter((e) => e.llm_used).length,
    pending: events.filter((e) => !e.handler_result).length,
    successRate:
      events.length > 0
        ? Math.round(
            (events.filter((e) => e.handler_result === 'success').length / events.length) * 100
          )
        : 0,
  }

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100">
      {/* Header */}
      <header className="border-b border-slate-800 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-2xl">🥭</span>
            <h1 className="text-xl font-semibold tracking-tight">Voice Debugger</h1>
            {isLive && activeTab === 'events' && (
              <span className="flex items-center gap-1.5 text-sm text-green-400">
                <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                Live
              </span>
            )}
          </div>
          <div className="flex items-center gap-3">
            {activeTab === 'events' && (
              <button
                onClick={() => setIsLive(!isLive)}
                className={`px-4 py-2 rounded font-medium transition-colors ${
                  isLive ? 'bg-slate-700 text-slate-200' : 'bg-slate-800 text-slate-400'
                }`}
              >
                {isLive ? 'Pause' : 'Resume'}
              </button>
            )}
            <button
              onClick={refreshAll}
              className="px-4 py-2 bg-slate-800 text-slate-200 rounded font-medium hover:bg-slate-700 transition-colors"
            >
              Refresh
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 mt-4">
          <button
            onClick={() => setActiveTab('events')}
            className={`px-4 py-2 rounded-t font-medium transition-colors ${
              activeTab === 'events'
                ? 'bg-slate-800 text-slate-100'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Voice Events
          </button>
          <button
            onClick={() => setActiveTab('patterns')}
            className={`px-4 py-2 rounded-t font-medium transition-colors flex items-center gap-2 ${
              activeTab === 'patterns'
                ? 'bg-slate-800 text-slate-100'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Pattern Suggestions
            {pendingPatternsCount > 0 && (
              <span className="px-2 py-0.5 bg-amber-600 text-white text-xs rounded-full">
                {pendingPatternsCount}
              </span>
            )}
          </button>
          <button
            onClick={() => setActiveTab('tmdb')}
            className={`px-4 py-2 rounded-t font-medium transition-colors ${
              activeTab === 'tmdb'
                ? 'bg-slate-800 text-slate-100'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            TMDB Analytics v2
          </button>
          <button
            onClick={() => setActiveTab('movies')}
            className={`px-4 py-2 rounded-t font-medium transition-colors ${
              activeTab === 'movies'
                ? 'bg-slate-800 text-slate-100'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Movies
          </button>
        </div>
      </header>

      {/* Content */}
      <main className="p-6">
        {/* Events Tab */}
        <div className={activeTab === 'events' ? '' : 'hidden'}>
          {/* Stats */}
          <StatsBar {...stats} />

          {/* Filters */}
          <div className="flex items-center gap-4 my-4">
            <div className="flex gap-2">
              {(['all', 'success', 'failed', 'llm'] as const).map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`px-3 py-1.5 rounded text-sm font-medium transition-colors ${
                    filter === f
                      ? f === 'all'
                        ? 'bg-orange-600 text-white'
                        : f === 'success'
                        ? 'bg-green-600 text-white'
                        : f === 'failed'
                        ? 'bg-red-600 text-white'
                        : 'bg-purple-600 text-white'
                      : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
                  }`}
                >
                  {f === 'all' && 'All'}
                  {f === 'success' && '✓ Success'}
                  {f === 'failed' && '✗ Failed'}
                  {f === 'llm' && '🤖 LLM'}
                </button>
              ))}
            </div>
            <span className="text-slate-500 text-sm">{filteredEvents.length} events</span>
          </div>

          {/* Events Table */}
          <DataTable
            columns={voiceEventsColumns}
            data={filteredEvents}
            onRowClick={(event) => setSelectedEvent(event)}
            selectedRowId={selectedEvent?.id ?? null}
            getRowId={(event) => event.id}
            newRowIds={newEventIds}
          />

          {/* Event Detail Panel */}
          {selectedEvent && (
            <EventDetail event={selectedEvent} onClose={() => setSelectedEvent(null)} />
          )}
        </div>

        {/* Patterns Tab */}
        <div className={activeTab === 'patterns' ? '' : 'hidden'}>
          <PatternSuggestions />
        </div>

        {/* TMDB Analytics Tab */}
        <div className={activeTab === 'tmdb' ? '' : 'hidden'}>
          <TMDBAnalytics ref={tmdbAnalyticsRef} />
        </div>

        {/* Movies Tab */}
        <div className={activeTab === 'movies' ? '' : 'hidden'}>
          <MoviesList ref={moviesListRef} />
        </div>
      </main>

      {/* Footer */}
      <footer className="fixed bottom-4 left-6 text-xs text-slate-600">
        Real-time monitoring of TalkToMango voice interactions
      </footer>
    </div>
  )
}
