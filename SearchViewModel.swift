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
    
    /// Execute the actual search - using TMDB API
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
            // Call TMDB API to search for movies
            print("🌐 Calling TMDB API for query: '\(query)'")
            let response = try await tmdbService.searchMovies(query: query, page: 1)
            
            // Convert TMDB movies to our Movie model
            searchResults = response.results.map { tmdbMovie in
                tmdbMovie.toMovie()
            }
            
            // Mark as searched
            hasSearched = true
            
            // Add to search history
            historyManager.addToHistory(searchQuery)
            
            print("✅ Found \(searchResults.count) movies from TMDB for '\(query)' (total: \(response.totalResults))")
            
        } catch let searchError as TMDBError {
            // Handle TMDB-specific errors
            self.error = searchError
            searchResults = []
            hasSearched = true
            print("❌ TMDB API error: \(searchError.localizedDescription)")
            
        } catch let networkError {
            // Handle other errors
            self.error = TMDBError.networkError(networkError)
            searchResults = []
            hasSearched = true
            print("❌ Search error: \(networkError.localizedDescription)")
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
