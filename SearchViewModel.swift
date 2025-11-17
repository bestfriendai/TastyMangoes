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
        
        // Clear results and reset state if query is too short
        guard searchQuery.count >= 2 else {
            searchResults = []
            hasSearched = false
            showSuggestions = false
            isSearching = false
            return
        }
        
        // Show loading state immediately
        isSearching = true
        showSuggestions = false
        
        // Debounce - wait 0.5 seconds before searching
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            guard !Task.isCancelled else { return }
            
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
    
    /// Execute the actual search
    private func performSearch() async {
        error = nil
        hasSearched = true
        showSuggestions = false
        
        // Add to search history
        if !searchQuery.isEmpty {
            historyManager.addToHistory(searchQuery)
        }
        
        do {
            let response = try await tmdbService.searchMovies(query: searchQuery)
            
            // Convert TMDB movies to our Movie model
            searchResults = response.results.map { $0.toMovie() }
            
            print("✅ Found \(searchResults.count) movies for '\(searchQuery)'")
            
        } catch let tmdbError as TMDBError {
            self.error = tmdbError
            searchResults = []
            print("❌ Search error: \(tmdbError.localizedDescription)")
        } catch {
            self.error = .networkError(error)
            searchResults = []
            print("❌ Unexpected error: \(error)")
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
