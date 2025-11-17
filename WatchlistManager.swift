//  WatchlistManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:47 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:38 (America/Los_Angeles - Pacific Time)
//  Notes: Created centralized watchlist state management system to handle adding movies to lists, tracking watched status, and managing list membership. Fixed missing Combine import for ObservableObject conformance. Added list creation, deletion, management methods, and sorting functionality. Fixed variable mutation warning. Added duplicate watchlist functionality.

import Foundation
import SwiftUI
import Combine

// MARK: - Watchlist Manager

@MainActor
class WatchlistManager: ObservableObject {
    static let shared = WatchlistManager()
    
    // Dictionary: [listId: Set<movieId>]
    @Published private var listMovies: [String: Set<String>] = [:]
    
    // Dictionary: [movieId: Set<listId>]
    @Published private var movieLists: [String: Set<String>] = [:]
    
    // Dictionary: [movieId: Bool] - tracks watched status
    @Published private var watchedMovies: [String: Bool] = [:]
    
    // Dictionary: [listId: WatchlistItem] - stores list metadata
    @Published private var watchlistMetadata: [String: WatchlistItem] = [:]
    
    private var nextListId: Int = 100 // Start from 100 to avoid conflicts with mock data
    
    private init() {
        // Initialize with mock data
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    /// Check if a movie is in a specific list
    func isMovieInList(movieId: String, listId: String) -> Bool {
        return listMovies[listId]?.contains(movieId) ?? false
    }
    
    /// Get all lists that contain a movie
    func getListsForMovie(movieId: String) -> Set<String> {
        return movieLists[movieId] ?? []
    }
    
    /// Get all movies in a list
    func getMoviesInList(listId: String) -> Set<String> {
        return listMovies[listId] ?? []
    }
    
    /// Add a movie to a list
    func addMovieToList(movieId: String, listId: String) -> Bool {
        // Check if already in list
        if isMovieInList(movieId: movieId, listId: listId) {
            return false // Already added
        }
        
        // Add to listMovies
        if listMovies[listId] == nil {
            listMovies[listId] = Set<String>()
        }
        listMovies[listId]?.insert(movieId)
        
        // Add to movieLists
        if movieLists[movieId] == nil {
            movieLists[movieId] = Set<String>()
        }
        movieLists[movieId]?.insert(listId)
        
        return true // Successfully added
    }
    
    /// Remove a movie from a list
    func removeMovieFromList(movieId: String, listId: String) {
        listMovies[listId]?.remove(movieId)
        movieLists[movieId]?.remove(listId)
        
        // Clean up empty sets
        if listMovies[listId]?.isEmpty ?? false {
            listMovies.removeValue(forKey: listId)
        }
        if movieLists[movieId]?.isEmpty ?? false {
            movieLists.removeValue(forKey: movieId)
        }
    }
    
    /// Add a movie to multiple lists
    func addMovieToLists(movieId: String, listIds: Set<String>) -> (added: Set<String>, alreadyIn: Set<String>) {
        var added: Set<String> = []
        var alreadyIn: Set<String> = []
        
        for listId in listIds {
            if addMovieToList(movieId: movieId, listId: listId) {
                added.insert(listId)
            } else {
                alreadyIn.insert(listId)
            }
        }
        
        return (added, alreadyIn)
    }
    
    /// Mark a movie as watched
    func markAsWatched(movieId: String) {
        watchedMovies[movieId] = true
    }
    
    /// Mark a movie as not watched
    func markAsNotWatched(movieId: String) {
        watchedMovies[movieId] = false
    }
    
    /// Toggle watched status
    func toggleWatched(movieId: String) {
        let currentStatus = isWatched(movieId: movieId)
        watchedMovies[movieId] = !currentStatus
    }
    
    /// Check if a movie is watched
    func isWatched(movieId: String) -> Bool {
        return watchedMovies[movieId] ?? false
    }
    
    /// Get the count of movies in a list
    func getListCount(listId: String) -> Int {
        return listMovies[listId]?.count ?? 0
    }
    
    // MARK: - List Management
    
    /// Create a new watchlist
    func createWatchlist(name: String) -> WatchlistItem {
        let listId = String(nextListId)
        nextListId += 1
        
        let watchlist = WatchlistItem(
            id: listId,
            name: name,
            filmCount: 0,
            thumbnailURL: nil
        )
        
        watchlistMetadata[listId] = watchlist
        listMovies[listId] = Set<String>() // Initialize empty set
        
        return watchlist
    }
    
    /// Delete a watchlist
    func deleteWatchlist(listId: String) {
        // Remove all movies from this list
        if let movies = listMovies[listId] {
            for movieId in movies {
                movieLists[movieId]?.remove(listId)
                if movieLists[movieId]?.isEmpty ?? false {
                    movieLists.removeValue(forKey: movieId)
                }
            }
        }
        
        // Remove the list
        listMovies.removeValue(forKey: listId)
        watchlistMetadata.removeValue(forKey: listId)
    }
    
    /// Get all watchlists (excluding masterlist)
    func getAllWatchlists(sortBy: SortOption = .listOrder) -> [WatchlistItem] {
        let lists = watchlistMetadata.values
            .filter { $0.id != "masterlist" && $0.id != "1" } // Exclude masterlist
        
        switch sortBy {
        case .listOrder:
            // Sort by creation order (list ID as number)
            return lists.sorted { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }
        case .dateAdded:
            // For now, use list order (in a real app, you'd track creation dates)
            return lists.sorted { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }
        case .alphabetical:
            return lists.sorted { $0.name < $1.name }
        }
    }
    
    enum SortOption {
        case listOrder
        case dateAdded
        case alphabetical
    }
    
    /// Get a watchlist by ID
    func getWatchlist(listId: String) -> WatchlistItem? {
        if let metadata = watchlistMetadata[listId] {
            // Update film count
            let count = getListCount(listId: listId)
            return WatchlistItem(
                id: metadata.id,
                name: metadata.name,
                filmCount: count,
                thumbnailURL: metadata.thumbnailURL
            )
        }
        return nil
    }
    
    /// Update watchlist name
    func updateWatchlistName(listId: String, newName: String) {
        if let metadata = watchlistMetadata[listId] {
            let count = getListCount(listId: listId)
            watchlistMetadata[listId] = WatchlistItem(
                id: metadata.id,
                name: newName,
                filmCount: count,
                thumbnailURL: metadata.thumbnailURL
            )
        }
    }
    
    /// Duplicate a watchlist
    func duplicateWatchlist(listId: String) -> WatchlistItem? {
        guard let sourceMetadata = watchlistMetadata[listId],
              let sourceMovies = listMovies[listId] else {
            return nil
        }
        
        // Create new list with "Copy of" prefix
        let newListId = String(nextListId)
        nextListId += 1
        
        let newName = "Copy of \(sourceMetadata.name)"
        let newWatchlist = WatchlistItem(
            id: newListId,
            name: newName,
            filmCount: sourceMovies.count,
            thumbnailURL: sourceMetadata.thumbnailURL
        )
        
        // Add metadata
        watchlistMetadata[newListId] = newWatchlist
        
        // Copy all movies
        listMovies[newListId] = sourceMovies
        
        // Update movieLists for each movie
        for movieId in sourceMovies {
            if movieLists[movieId] == nil {
                movieLists[movieId] = Set<String>()
            }
            movieLists[movieId]?.insert(newListId)
        }
        
        return newWatchlist
    }
    
    // MARK: - Mock Data Loading
    
    private func loadMockData() {
        // Initialize masterlist
        let masterlist = WatchlistItem(id: "masterlist", name: "Masterlist", filmCount: 0, thumbnailURL: nil)
        watchlistMetadata["masterlist"] = masterlist
        
        // Initialize some mock watchlists
        let mockLists = [
            WatchlistItem(id: "2", name: "Must-Watch Movies", filmCount: 0, thumbnailURL: nil),
            WatchlistItem(id: "3", name: "Sci-Fi Masterpieces", filmCount: 0, thumbnailURL: nil),
            WatchlistItem(id: "4", name: "Action Blockbusters", filmCount: 0, thumbnailURL: nil),
            WatchlistItem(id: "5", name: "My Favorite Films", filmCount: 0, thumbnailURL: nil),
            WatchlistItem(id: "6", name: "Animated Adventures", filmCount: 0, thumbnailURL: nil)
        ]
        
        for list in mockLists {
            watchlistMetadata[list.id] = list
            listMovies[list.id] = Set<String>()
        }
        
        // Add some movies to Masterlist
        let masterlistMovies = ["1", "2", "3", "4", "5", "6", "7", "8"]
        for movieId in masterlistMovies {
            _ = addMovieToList(movieId: movieId, listId: "masterlist")
        }
        
        // Mark some movies as watched
        markAsWatched(movieId: "1") // Jurassic World: Reborn
        markAsWatched(movieId: "5") // Jurassic World
        markAsWatched(movieId: "7") // Jurassic Park III
        
        // Add some movies to other lists
        _ = addMovieToList(movieId: "1", listId: "2") // Must-Watch Movies
        _ = addMovieToList(movieId: "2", listId: "2") // Must-Watch Movies
        _ = addMovieToList(movieId: "3", listId: "3") // Sci-Fi Masterpieces
        
        // Update nextListId to avoid conflicts
        nextListId = 10
    }
}

// MARK: - Watchlist Manager Environment Key

struct WatchlistManagerKey: EnvironmentKey {
    static let defaultValue = WatchlistManager.shared
}

extension EnvironmentValues {
    var watchlistManager: WatchlistManager {
        get { self[WatchlistManagerKey.self] }
        set { self[WatchlistManagerKey.self] = newValue }
    }
}

