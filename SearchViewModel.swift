//
//  SearchViewModel.swift
//  TastyMangoes
//
//  Created by Claude on 11/13/25 at 9:07 PM
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchQuery = ""
    @Published var searchResults: [Movie] = []
    @Published var isSearching = false
    @Published var error: TMDBError?
    @Published var hasSearched = false
    @Published var searchSuggestions: [String] = []
    @Published var showSuggestions = false
    
    // MARK: - Properties
    
    private let tmdbService = TMDBService.shared
    private var searchTask: Task<Void, Never>?
    private let historyManager = SearchHistoryManager.shared
    
    // MARK: - Search Methods
    
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
            return
        }
        
        // Show loading state immediately
        isSearching = true
        showSuggestions = false
        error = nil
        
        print("⏳ Starting debounced search for '\(searchQuery)'")
        
        // Debounce - wait 0.3 seconds before searching (reduced for better responsiveness)
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard !Task.isCancelled else {
                print("❌ Search task cancelled")
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
        error = nil
        showSuggestions = false
        
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        
        if query.isEmpty {
            searchResults = []
            hasSearched = false
            isSearching = false
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
            
            // Mark as searched
            hasSearched = true
            
            // Add to search history
            historyManager.addToHistory(searchQuery)
            
            print("✅ Found \(searchResults.count) movies from Supabase for '\(query)'")
            
        } catch let searchError {
            // Handle errors
            self.error = TMDBError.networkError(searchError)
            searchResults = []
            hasSearched = true
            print("❌ Search error: \(searchError.localizedDescription)")
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
        searchTask?.cancel()
        // Also clear searchQuery in SearchFilterState for tab bar visibility
        SearchFilterState.shared.searchQuery = ""
    }
    
    /// Load popular movies (for when search is empty)
    func loadPopularMovies() async {
        isSearching = true
        error = nil
        
        do {
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
    
    /// Load trending movies
    func loadTrendingMovies() async {
        isSearching = true
        error = nil
        
        do {
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
