//
//  SearchViewModel.swift
//  TastyMangoes
//
//  Originally created by Claude on 11/13/25 at 9:07 PM
//  Modified by Claude on 2025-12-02 at 12:15 AM (Pacific Time)
//  Modified by Claude on 2025-12-15 at 11:50 AM (Pacific Time) - Fixed voice selection tracking
//  Modified by Claude on 2025-12-15 at 4:00 PM (Pacific Time) - Fixed duplicate observer & parallel search bugs
//
//  Changes made by Claude (2025-12-02):
//  - Fixed flashing "no movies found" issue during typing
//  - Keep previous results visible while new search is in progress
//  - Only show empty state after debounced search truly completes with no results
//  - Fixed Task cancellation not resetting isSearching state
//
//  Changes made by Claude (2025-12-15 11:50 AM):
//  - Moved pendingVoiceEventId clearing from performSearch() to clearSearch()
//  - This allows SearchMovieCard to track which movie the user selects
//
//  Changes made by Claude (2025-12-15 4:00 PM):
//  - Fixed duplicate NotificationCenter observer registration causing 3x search execution
//  - Added isSearchInFlight guard to prevent parallel searches
//  - Removed auto-open single result feature (was causing UI freezes)
//  - Added proper observer cleanup in deinit

import Foundation
import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    static let shared = SearchViewModel()
    
    // MARK: - Published Properties
    
    @Published var searchQuery = ""
    @Published var searchResults: [Movie] = []
    @Published var isSearching = false
    @Published var error: TMDBError?
    @Published var hasSearched = false
    @Published var searchSuggestions: [String] = []
    @Published var showSuggestions = false
    
    // Track the query that produced current results
    private var lastSearchedQuery: String = ""
    
    // Track if current search was initiated by Mango (for speech responses)
    var isMangoInitiatedSearch: Bool = false
    
    // Track last query for Mango speech responses
    var lastQuery: String? {
        return lastSearchedQuery.isEmpty ? nil : lastSearchedQuery
    }
    
    // MARK: - Properties
    
    private let tmdbService = TMDBService.shared
    private var searchTask: Task<Void, Never>?
    private let historyManager = SearchHistoryManager.shared
    
    // FIX: Prevent duplicate observer registration
    private static var observerRegistered = false
    private var notificationObserver: NSObjectProtocol?
    
    // FIX: Prevent parallel searches
    private var isSearchInFlight = false
    
    // MARK: - Initialization
    
    init() {
        setupNotificationObserver()
    }
    
    deinit {
        // Clean up observer
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotificationObserver() {
        // FIX: Only register observer once across all instances
        guard !SearchViewModel.observerRegistered else {
            print("⚠️ [SearchViewModel] Observer already registered, skipping duplicate")
            return
        }
        SearchViewModel.observerRegistered = true
        
        // Listen for Mango-initiated queries
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.mangoPerformMovieQuery,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Extract query from notification before async context
            guard let query = note.object as? String else {
                print("🍋 [SearchViewModel] mangoPerformMovieQuery notification received but no query string")
                return
            }
            
            // Execute on MainActor
            Task { @MainActor in
                print("🍋 [SearchViewModel] Received mangoPerformMovieQuery notification with query: '\(query)'")
                self?.isMangoInitiatedSearch = true
                self?.search(query: query)
            }
        }
        
        print("✅ [SearchViewModel] Notification observer registered")
    }
    
    // MARK: - Search Methods
    
    /// Public method to trigger search with a query string (for programmatic access)
    func search(query: String) {
        searchQuery = query
        search()
    }
    
    /// Perform search with debouncing - shows real-time results as user types
    func search() {
        // Cancel previous search
        searchTask?.cancel()
        
        print("🔍 Search called with query: '\(searchQuery)' (length: \(searchQuery.count))")
        
        // Clear results and reset state if query is too short
        guard searchQuery.count >= 1 else {
            print("⚠️ Query too short, clearing results")
            searchResults = []
            hasSearched = false
            showSuggestions = false
            isSearching = false
            error = nil
            lastSearchedQuery = ""
            return
        }
        
        // Show loading state - but keep previous results visible
        isSearching = true
        showSuggestions = false
        error = nil
        
        print("⏳ Starting debounced search for '\(searchQuery)'")
        
        // Debounce - wait 0.4 seconds before searching (slightly longer for smoother UX)
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            
            guard !Task.isCancelled else {
                print("❌ Search task cancelled")
                // Don't change isSearching here - a new search might be starting
                return
            }
            
            print("✅ Executing search for '\(searchQuery)'")
            await performSearch()
        }
    }
    
    /// Update search suggestions
    private func updateSuggestions() {
        if searchQuery.isEmpty {
            searchSuggestions = []
            showSuggestions = false
        } else {
            searchSuggestions = historyManager.getSuggestions(for: searchQuery)
            showSuggestions = !searchSuggestions.isEmpty
        }
    }
    
    /// Execute the actual search - using Supabase endpoint with filters
    @MainActor
    private func performSearch() async {
        // FIX: Prevent parallel searches
        guard !isSearchInFlight else {
            print("⚠️ [SearchViewModel] Search already in flight, skipping duplicate")
            return
        }
        isSearchInFlight = true
        defer { isSearchInFlight = false }
        
        error = nil
        showSuggestions = false
        
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        
        if query.isEmpty {
            searchResults = []
            hasSearched = false
            isSearching = false
            lastSearchedQuery = ""
            return
        }
        
        do {
            // Get filter state - use APPLIED filters (not staged)
            let filterState = SearchFilterState.shared
            
            // Debug: Log current applied year range
            print("🔍 [SEARCH] Current appliedYearRange: \(filterState.appliedYearRange.lowerBound)-\(filterState.appliedYearRange.upperBound)")
            
            // Determine year range (only apply if not default range)
            let yearRange: ClosedRange<Int>? = (filterState.appliedYearRange.lowerBound == 1925 && filterState.appliedYearRange.upperBound == 2025)
                ? nil
                : filterState.appliedYearRange
            
            // Get genres (only apply if not empty)
            let genres: Set<String>? = filterState.appliedSelectedGenres.isEmpty ? nil : filterState.appliedSelectedGenres
            
            // Call Supabase search-movies endpoint with filters
            print("🌐 Calling Supabase search-movies for query: '\(query)'")
            if let yearRange = yearRange {
                print("   ✅ Year range: \(yearRange.lowerBound)-\(yearRange.upperBound) (will be sent to API)")
            } else {
                print("   ⚠️ Year range: NIL (default range detected, not sending to API)")
            }
            if let genres = genres {
                print("   Genres: \(genres.joined(separator: ", "))")
            }
            
            let movieSearchResults = try await SupabaseService.shared.searchMovies(
                query: query,
                yearRange: yearRange,
                genres: genres
            )
            
            // Check if this search is still relevant (user might have typed more)
            guard query == searchQuery.trimmingCharacters(in: .whitespaces) else {
                print("⚠️ Query changed during search, discarding results for '\(query)'")
                return
            }
            
            // Convert MovieSearchResult to Movie
            var convertedMovies = movieSearchResults.map { result in
                Movie(
                    id: result.tmdbId,
                    title: result.title,
                    year: result.year ?? 0,
                    trailerURL: nil,
                    trailerDuration: nil,
                    posterImageURL: result.posterUrl,
                    tastyScore: nil,
                    aiScore: result.voteAverage,
                    genres: [],
                    rating: nil,
                    director: nil,
                    writer: nil,
                    screenplay: nil,
                    composer: nil,
                    runtime: nil,
                    releaseDate: nil,
                    language: nil,
                    overview: result.overviewShort
                )
            }
            
            // Apply sorting based on applied sortBy filter
            let sortBy = filterState.appliedSortBy
            print("🔀 [SEARCH VIEW MODEL] Applying sort: '\(sortBy)' to \(convertedMovies.count) movies")
            switch sortBy {
            case "Alphabetical":
                // Sort alphabetically by title (A-Z)
                convertedMovies.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                print("   ✅ Sorted alphabetically (A-Z)")
            case "Year":
                // Sort by year (ascending - oldest first)
                convertedMovies.sort { $0.year < $1.year }
                print("   ✅ Sorted by year (oldest first)")
            case "Tasty Score":
                // Sort by Tasty Score (descending - highest first)
                convertedMovies.sort { ($0.tastyScore ?? 0) > ($1.tastyScore ?? 0) }
                print("   ✅ Sorted by Tasty Score (highest first)")
            case "AI Score":
                // Sort by AI Score (descending - highest first)
                convertedMovies.sort { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
                print("   ✅ Sorted by AI Score (highest first)")
            case "Watched":
                // Sort watched movies first, then unwatched
                convertedMovies.sort { movie1, movie2 in
                    let watched1 = WatchlistManager.shared.isWatched(movieId: movie1.id)
                    let watched2 = WatchlistManager.shared.isWatched(movieId: movie2.id)
                    if watched1 == watched2 {
                        return false // Keep relative order if both have same watched status
                    }
                    return watched1 && !watched2 // Watched movies first
                }
                print("   ✅ Sorted by watched status")
            default:
                // "List order" - keep original order from API
                print("   ✅ Keeping list order (no sort applied)")
                break
            }
            
            self.searchResults = convertedMovies
            self.lastSearchedQuery = query
            
            // Mark as searched
            hasSearched = true
            
            // Add to search history
            historyManager.addToHistory(searchQuery)
            
            print("✅ Found \(searchResults.count) movies from Supabase for '\(query)'")
            
            // Log search analytics
            let searchSource = isMangoInitiatedSearch ? "voice" : "keyboard"
            AnalyticsService.shared.logMovieSearch(query: query, resultCount: searchResults.count, source: searchSource)
            
            // Update voice event with search results if this was a Mango-initiated search
            if isMangoInitiatedSearch, let eventId = SearchFilterState.shared.pendingVoiceEventId {
                // Capture result count for the async task
                let resultCount = searchResults.count
                
                Task {
                    let result: String
                    if resultCount == 0 {
                        result = "no_results"
                    } else if resultCount >= 10 {
                        result = "ambiguous"
                    } else {
                        result = "success"
                    }
                    
                    await VoiceAnalyticsLogger.updateVoiceEventResult(
                        eventId: eventId,
                        result: result,
                        resultCount: resultCount
                    )
                    
                    // Trigger self-healing if needed (for search commands)
                    let utterance = SearchFilterState.shared.pendingVoiceUtterance ?? query
                    let originalCommand = SearchFilterState.shared.pendingVoiceCommand ?? .movieSearch(query: query, raw: query)
                    
                    // Convert string result to VoiceHandlerResult enum
                    let handlerResult: VoiceHandlerResult? = {
                        switch result {
                        case "success": return .success
                        case "no_results": return .noResults
                        case "ambiguous": return .ambiguous
                        case "network_error": return .networkError
                        case "parse_error": return .parseError
                        default: return nil
                        }
                    }()
                    
                    // Use the proper extension method with correct types
                    VoiceIntentRouter.checkAndTriggerSelfHealing(
                        utterance: utterance,
                        originalCommand: originalCommand,
                        handlerResult: handlerResult,
                        screen: "SearchView",
                        movieContext: nil,
                        voiceEventId: eventId
                    )
                    
                    // NOTE: Do NOT clear pendingVoiceEventId here!
                    // SearchMovieCard needs it to track which movie the user selects.
                    // It will be cleared in clearSearch() or after selection is logged.
                }
            }
            
            // Reset Mango flag after search completes (speech will be handled by SearchView onChange)
            isMangoInitiatedSearch = false
            
            // NOTE: Removed auto-open single result feature - it was causing UI freezes
            // If we want this feature back, it needs proper async handling and state management
            // See: https://github.com/user/repo/issues/XXX
            
        } catch let searchError {
            // Only show error if this search is still relevant
            guard query == searchQuery.trimmingCharacters(in: .whitespaces) else {
                return
            }
            
            // Handle errors
            self.error = TMDBError.networkError(searchError)
            searchResults = []
            hasSearched = true
            lastSearchedQuery = query
            print("❌ Search error: \(searchError.localizedDescription)")
            
            // Update voice event with error if this was a Mango-initiated search
            if isMangoInitiatedSearch, let eventId = SearchFilterState.shared.pendingVoiceEventId {
                Task {
                    await VoiceAnalyticsLogger.updateVoiceEventResult(
                        eventId: eventId,
                        result: "network_error",
                        errorMessage: searchError.localizedDescription
                    )
                    
                    // Trigger self-healing if needed (for network errors with action words)
                    let utterance = SearchFilterState.shared.pendingVoiceUtterance ?? query
                    let originalCommand = SearchFilterState.shared.pendingVoiceCommand ?? .movieSearch(query: query, raw: query)
                    
                    // Use the proper extension method with correct types
                    VoiceIntentRouter.checkAndTriggerSelfHealing(
                        utterance: utterance,
                        originalCommand: originalCommand,
                        handlerResult: .networkError,
                        screen: "SearchView",
                        movieContext: nil,
                        voiceEventId: eventId
                    )
                    
                    // NOTE: Do NOT clear pendingVoiceEventId here!
                    // Keep it for potential retry or selection tracking.
                    // It will be cleared in clearSearch().
                }
            }
        }
        
        isSearching = false
    }
    
    /// Select a suggestion
    func selectSuggestion(_ suggestion: String) {
        searchQuery = suggestion
        showSuggestions = false
        Task {
            await performSearch()
        }
    }
    
    /// Apply sorting to existing search results
    func applySorting() {
        guard !searchResults.isEmpty else { return }
        
        let filterState = SearchFilterState.shared
        let sortBy = filterState.appliedSortBy
        print("🔀 [SEARCH VIEW MODEL] Applying sort: '\(sortBy)' to \(searchResults.count) existing movies")
        
        switch sortBy {
        case "Alphabetical":
            searchResults.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            print("   ✅ Sorted alphabetically (A-Z)")
        case "Year":
            searchResults.sort { $0.year < $1.year }
            print("   ✅ Sorted by year (oldest first)")
        case "Tasty Score":
            searchResults.sort { ($0.tastyScore ?? 0) > ($1.tastyScore ?? 0) }
            print("   ✅ Sorted by Tasty Score (highest first)")
        case "AI Score":
            searchResults.sort { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
            print("   ✅ Sorted by AI Score (highest first)")
        case "Watched":
            searchResults.sort { movie1, movie2 in
                let watched1 = WatchlistManager.shared.isWatched(movieId: movie1.id)
                let watched2 = WatchlistManager.shared.isWatched(movieId: movie2.id)
                if watched1 == watched2 {
                    return false
                }
                return watched1 && !watched2
            }
            print("   ✅ Sorted by watched status")
        default:
            // "List order" - keep original order (would need to re-fetch)
            print("   ⚠️ List order - would need to re-fetch to restore original order")
            break
        }
    }
    
    /// Clear search - returns to categories view
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        hasSearched = false
        error = nil
        searchSuggestions = []
        showSuggestions = false
        isSearching = false
        lastSearchedQuery = ""
        searchTask?.cancel()
        // Also clear searchQuery in SearchFilterState for tab bar visibility
        SearchFilterState.shared.searchQuery = ""
        
        // Clear voice event tracking when search is cleared
        SearchFilterState.shared.pendingVoiceEventId = nil
        SearchFilterState.shared.pendingVoiceUtterance = nil
        SearchFilterState.shared.pendingVoiceCommand = nil
    }
    
    /// Load popular movies (for when search is empty)
    /// Load popular movies from TMDB
    /// NOTE: This is allowed because it's for search/discovery, not watchlist.
    /// Watchlist should never call TMDB - it uses work_cards_cache only.
    func loadPopularMovies() async {
        isSearching = true
        error = nil
        
        do {
            print("[TMDB CALL] SearchViewModel fetching popular movies from TMDB (search/discovery path)")
            let response = try await tmdbService.getPopularMovies()
            searchResults = response.results.map { $0.toMovie() }
            print("✅ Loaded \(searchResults.count) popular movies")
        } catch let tmdbError as TMDBError {
            self.error = tmdbError
            print("❌ Error loading popular movies: \(tmdbError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
        }
        
        isSearching = false
    }
    
    /// Load trending movies from TMDB
    /// NOTE: This is allowed because it's for search/discovery, not watchlist.
    /// Watchlist should never call TMDB - it uses work_cards_cache only.
    func loadTrendingMovies() async {
        isSearching = true
        error = nil
        
        do {
            print("[TMDB CALL] SearchViewModel fetching trending movies from TMDB (search/discovery path)")
            let response = try await tmdbService.getTrendingMovies()
            searchResults = response.results.map { $0.toMovie() }
            print("✅ Loaded \(searchResults.count) trending movies")
        } catch let tmdbError as TMDBError {
            self.error = tmdbError
            print("❌ Error loading trending movies: \(tmdbError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
        }
        
        isSearching = false
    }
}
