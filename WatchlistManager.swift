//  WatchlistManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:47 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:38 (America/Los_Angeles - Pacific Time)
//  Notes: Created centralized watchlist state management system to handle adding movies to lists, tracking watched status, and managing list membership. Fixed missing Combine import for ObservableObject conformance. Added list creation, deletion, management methods, and sorting functionality. Fixed variable mutation warning. Added duplicate watchlist functionality.

import Foundation
import SwiftUI
import Combine
import Auth

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
    
    // Dictionary: [movieId: (recommenderName: String?, recommendedAt: Date?, recommenderNotes: String?)] - tracks recommendation data
    @Published private var movieRecommendations: [String: (recommenderName: String?, recommendedAt: Date?, recommenderNotes: String?)] = [:]
    
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
        return addMovieToList(movieId: movieId, listId: listId, recommenderName: nil, recommenderNotes: nil)
    }
    
    /// Add a movie to a list with optional recommendation info
    func addMovieToList(
        movieId: String,
        listId: String,
        recommenderName: String? = nil,
        recommenderNotes: String? = nil
    ) -> Bool {
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
        
        // Store recommendation data if provided
        if let recommenderName = recommenderName {
            movieRecommendations[movieId] = (
                recommenderName: recommenderName,
                recommendedAt: Date(),
                recommenderNotes: recommenderNotes
            )
        }
        
        // Update watchlist metadata with new film count
        if let metadata = watchlistMetadata[listId] {
            let count = getListCount(listId: listId)
            watchlistMetadata[listId] = WatchlistItem(
                id: metadata.id,
                name: metadata.name,
                filmCount: count,
                thumbnailURL: metadata.thumbnailURL
            )
        }
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        return true // Successfully added
    }
    
    /// Remove a movie from a list
    func removeMovieFromList(movieId: String, listId: String) {
        listMovies[listId]?.remove(movieId)
        movieLists[movieId]?.remove(listId)
        
        // Update watchlist metadata with new film count
        if let metadata = watchlistMetadata[listId] {
            let count = getListCount(listId: listId)
            watchlistMetadata[listId] = WatchlistItem(
                id: metadata.id,
                name: metadata.name,
                filmCount: count,
                thumbnailURL: metadata.thumbnailURL
            )
        }
        
        // Clean up empty sets
        if listMovies[listId]?.isEmpty ?? false {
            listMovies.removeValue(forKey: listId)
        }
        if movieLists[movieId]?.isEmpty ?? false {
            movieLists.removeValue(forKey: movieId)
        }
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
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
    
    /// Get recommendation data for a movie
    func getRecommendationData(movieId: String) -> (recommenderName: String?, recommendedAt: Date?, recommenderNotes: String?)? {
        return movieRecommendations[movieId]
    }
    
    /// Get the count of movies in a list
    func getListCount(listId: String) -> Int {
        return listMovies[listId]?.count ?? 0
    }
    
    // MARK: - List Management
    
    /// Create a new watchlist (local only - use createWatchlistAsync for Supabase sync)
    func createWatchlist(name: String) -> WatchlistItem {
        print("📋 [Watchlist] Creating watchlist locally: \(name)")
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
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        print("📋 [Watchlist] Created watchlist locally: \(name) (ID: \(listId))")
        return watchlist
    }
    
    /// Create a new watchlist and sync to Supabase
    func createWatchlistAsync(name: String) async throws -> WatchlistItem {
        print("📋 [Watchlist] Creating watchlist: \(name)")
        
        // Create in Supabase first
        let supabaseWatchlistId = try await SupabaseWatchlistAdapter.createWatchlist(name: name)
        print("📋 [Watchlist] Created watchlist in Supabase: \(name) (ID: \(supabaseWatchlistId.uuidString))")
        
        // Update local state with Supabase UUID
        let listId = supabaseWatchlistId.uuidString
        let watchlist = WatchlistItem(
            id: listId,
            name: name,
            filmCount: 0,
            thumbnailURL: nil
        )
        
        watchlistMetadata[listId] = watchlist
        listMovies[listId] = Set<String>() // Initialize empty set
        
        // Update nextListId to be higher than the UUID-based ID (if it's numeric)
        if let numericId = Int(listId) {
            nextListId = max(nextListId, numericId + 1)
        }
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        print("📋 [Watchlist] Successfully created watchlist: \(name) (ID: \(listId))")
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
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
    }
    
    /// Get all watchlists (excluding masterlist)
    func getAllWatchlists(sortBy: SortOption = .listOrder) -> [WatchlistItem] {
        let lists = watchlistMetadata.values
            .filter { $0.id != "masterlist" && $0.id != "1" } // Exclude masterlist
            .map { metadata -> WatchlistItem in
                // Update film count dynamically
                let count = getListCount(listId: metadata.id)
                return WatchlistItem(
                    id: metadata.id,
                    name: metadata.name,
                    filmCount: count,
                    thumbnailURL: metadata.thumbnailURL
                )
            }
        
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
    
    // Published sort option so views can observe changes
    @Published var currentSortOption: SortOption = .listOrder
    
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
            
            // Notify observers that lists have changed
            NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
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
    
    // MARK: - Supabase Sync
    
    /// Sync watchlist data from Supabase
    func syncFromSupabase() async {
        print("📋 [Watchlist] Starting sync from Supabase...")
        
        do {
            // Get current user ID for logging
            if let userId = try? await SupabaseService.shared.getCurrentUser() {
                print("📋 [Watchlist] Fetching watchlists for user: \(userId.id)")
            }
            
            let snapshot = try await SupabaseWatchlistAdapter.fetchAllWatchlistDataForCurrentUser()
            
            print("📋 [Watchlist] Loaded \(snapshot.watchlistMetadata.count) watchlists from Supabase")
            print("📋 [Watchlist] Loaded \(snapshot.listMovies.values.reduce(0) { $0 + $1.count }) total movies across all lists")
            
            // Update all data structures
            listMovies = snapshot.listMovies
            movieLists = snapshot.movieLists
            watchedMovies = snapshot.watchedMovies
            watchlistMetadata = snapshot.watchlistMetadata
            nextListId = snapshot.nextListId
            
            // Convert movieRecommendations from snapshot format
            for (movieId, recommendation) in snapshot.movieRecommendations {
                movieRecommendations[movieId] = (
                    recommenderName: recommendation.recommenderName,
                    recommendedAt: recommendation.recommendedAt,
                    recommenderNotes: recommendation.recommenderNotes
                )
            }
            
            // Notify observers that lists have changed
            NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
            
            print("✅ [Watchlist] Synced watchlist data from Supabase - \(snapshot.watchlistMetadata.count) lists, nextListId: \(snapshot.nextListId)")
        } catch {
            print("❌ [Watchlist] Error syncing from Supabase: \(error)")
            print("❌ [Watchlist] Error details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mock Data Loading
    
    private func loadMockData() {
        // Initialize masterlist only - no mock watchlists
        let masterlist = WatchlistItem(id: "masterlist", name: "Masterlist", filmCount: 0, thumbnailURL: nil)
        watchlistMetadata["masterlist"] = masterlist
        listMovies["masterlist"] = Set<String>() // Initialize empty set
        
        // Start nextListId from 100 to avoid conflicts
        nextListId = 100
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

