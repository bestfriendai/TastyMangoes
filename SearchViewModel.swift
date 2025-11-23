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
    
    // MARK: - Test Movie Data
    
    static let testMovies: [Movie] = [
        Movie(
            id: "juror2",
            title: "Juror 2",
            year: 2024,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.75,
            aiScore: 7.2,
            genres: ["Thriller", "Drama"],
            rating: "R",
            director: "Clint Eastwood",
            runtime: "2h 15m",
            releaseDate: "2024-06-14",
            language: "English",
            overview: "A juror finds himself in a moral dilemma during a murder trial."
        ),
        Movie(
            id: "jurassic-world",
            title: "Jurassic World",
            year: 2015,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.72,
            aiScore: 6.9,
            genres: ["Action", "Sci-Fi"],
            rating: "PG-13",
            director: "Colin Trevorrow",
            runtime: "2h 4m",
            releaseDate: "2015-06-12",
            language: "English",
            overview: "A new theme park is built on the original site of Jurassic Park."
        ),
        Movie(
            id: "jungle-book",
            title: "The Jungle Book",
            year: 2016,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.88,
            aiScore: 7.5,
            genres: ["Family", "Adventure"],
            rating: "PG",
            director: "Jon Favreau",
            runtime: "1h 46m",
            releaseDate: "2016-04-15",
            language: "English",
            overview: "Mowgli, a man-cub raised by wolves, must leave the jungle."
        ),
        Movie(
            id: "juno",
            title: "Juno",
            year: 2007,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.91,
            aiScore: 7.5,
            genres: ["Comedy", "Romance"],
            rating: "PG-13",
            director: "Jason Reitman",
            runtime: "1h 36m",
            releaseDate: "2007-12-05",
            language: "English",
            overview: "A teenage girl faces an unplanned pregnancy."
        ),
        Movie(
            id: "julie-julia",
            title: "Julie & Julia",
            year: 2009,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.78,
            aiScore: 7.0,
            genres: ["Romance", "Drama"],
            rating: "PG-13",
            director: "Nora Ephron",
            runtime: "2h 3m",
            releaseDate: "2009-08-07",
            language: "English",
            overview: "A woman cooks her way through Julia Child's cookbook."
        ),
        Movie(
            id: "inception",
            title: "Inception",
            year: 2010,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.93,
            aiScore: 8.9,
            genres: ["Sci-Fi", "Thriller"],
            rating: "PG-13",
            director: "Christopher Nolan",
            runtime: "2h 28m",
            releaseDate: "2010-07-16",
            language: "English",
            overview: "A thief who steals secrets through dreams is given a chance to plant an idea instead."
        ),
        Movie(
            id: "parasite",
            title: "Parasite",
            year: 2019,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.96,
            aiScore: 9.2,
            genres: ["Thriller", "Drama"],
            rating: "R",
            director: "Bong Joon-ho",
            runtime: "2h 12m",
            releaseDate: "2019-05-30",
            language: "Korean",
            overview: "A poor family schemes to enter the lives of a wealthy household."
        ),
        Movie(
            id: "barbie",
            title: "Barbie",
            year: 2023,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.88,
            aiScore: 7.4,
            genres: ["Comedy", "Fantasy"],
            rating: "PG-13",
            director: "Greta Gerwig",
            runtime: "1h 54m",
            releaseDate: "2023-07-21",
            language: "English",
            overview: "Barbie suffers a crisis that leads her to question her world."
        ),
        Movie(
            id: "dune",
            title: "Dune",
            year: 2021,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.85,
            aiScore: 8.1,
            genres: ["Sci-Fi", "Adventure"],
            rating: "PG-13",
            director: "Denis Villeneuve",
            runtime: "2h 35m",
            releaseDate: "2021-10-22",
            language: "English",
            overview: "Paul Atreides leads a rebellion to restore his family's honor."
        ),
        Movie(
            id: "everything-everywhere",
            title: "Everything Everywhere All at Once",
            year: 2022,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.95,
            aiScore: 8.5,
            genres: ["Action", "Comedy", "Drama"],
            rating: "R",
            director: "Daniel Kwan, Daniel Scheinert",
            runtime: "2h 19m",
            releaseDate: "2022-03-25",
            language: "English",
            overview: "An aging Chinese immigrant is swept up in an insane adventure."
        ),
        Movie(
            id: "oppenheimer",
            title: "Oppenheimer",
            year: 2023,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.92,
            aiScore: 8.3,
            genres: ["Drama", "Biography"],
            rating: "R",
            director: "Christopher Nolan",
            runtime: "3h 0m",
            releaseDate: "2023-07-21",
            language: "English",
            overview: "The story of J. Robert Oppenheimer and the Manhattan Project."
        ),
        Movie(
            id: "top-gun",
            title: "Top Gun: Maverick",
            year: 2022,
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: nil,
            tastyScore: 0.89,
            aiScore: 8.2,
            genres: ["Action", "Drama"],
            rating: "PG-13",
            director: "Joseph Kosinski",
            runtime: "2h 10m",
            releaseDate: "2022-05-27",
            language: "English",
            overview: "After thirty years, Maverick is still pushing the envelope as a top naval aviator."
        )
    ]
    
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
    
    /// Execute the actual search - using test data for now
    private func performSearch() async {
        error = nil
        hasSearched = true
        showSuggestions = false
        
        // Add to search history
        if !searchQuery.isEmpty {
            historyManager.addToHistory(searchQuery)
        }
        
        // Use test data - filter movies by search query (case-insensitive)
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        
        if query.isEmpty {
            searchResults = []
        } else {
            // Filter test movies by title (case-insensitive contains)
            searchResults = SearchViewModel.testMovies.filter { movie in
                movie.title.lowercased().contains(query)
            }
            
            print("✅ Found \(searchResults.count) movies for '\(searchQuery)'")
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
