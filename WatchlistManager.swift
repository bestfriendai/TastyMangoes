//  WatchlistManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:47 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 21:48 (America/Los_Angeles - Pacific Time)
//  Notes: Added movie card caching for instant watchlist display, batch fetch support, performance optimizations.
//
//  TMDB USAGE: This manager NEVER calls TMDB. It only manages watchlist state and caches MovieCard
//  data that was fetched via batch queries from work_cards_cache. All data comes from Supabase.

import Foundation
import SwiftUI
import Combine
import Auth

// MARK: - Movie Recommendation Data

struct MovieRecommendationData: Codable, Equatable {
    var recommenderName: String?
    var recommendedAt: Date?
    var recommenderNotes: String?
}

// MARK: - Watchlist Snapshot (for caching)

private struct WatchlistSnapshot: Codable {
    let listMovies: [String: Set<String>]
    let movieLists: [String: Set<String>]
    let watchedMovies: [String: Bool]
    let movieRecommendations: [String: MovieRecommendationData]
    let watchlistMetadata: [String: WatchlistItem]
    let nextListId: Int
}

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
    
    // Dictionary: [movieId: MovieRecommendationData] - tracks recommendation data
    @Published private var movieRecommendations: [String: MovieRecommendationData] = [:]
    
    // Dictionary: [listId: WatchlistItem] - stores list metadata
    @Published private var watchlistMetadata: [String: WatchlistItem] = [:]
    
    // Dictionary: [movieId: MasterlistMovie] - cached movie cards for instant display
    @Published private var cachedMovieCards: [String: MasterlistMovie] = [:]
    
    // Loading state for master list count
    @Published var isMasterListCountLoading: Bool = true
    
    private var nextListId: Int = 100
    
    private init() {
        print("🔥 WatchlistManager.init called")
        
        // 1. Load from local cache first (fast + offline)
        loadFromCache()
        
        // 2. Ensure at least a masterlist exists if nothing is cached
        if watchlistMetadata.isEmpty {
            print("ℹ️ WatchlistManager.init: No cached data, creating masterlist")
            loadMockData() // Only to seed masterlist
            saveToCache()
            // Keep loading flag as true since we'll need to sync from Supabase
            isMasterListCountLoading = true
        } else {
            print("✅ WatchlistManager.init: Successfully initialized with cached data")
            // We have cached data, so count is available - set loading to false
            isMasterListCountLoading = false
        }
        
        // Note: Supabase sync will be added later after persistence is confirmed working
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
    
    /// Get cached movie card for a movie ID (for instant display)
    func getCachedMovieCard(movieId: String) -> MasterlistMovie? {
        return cachedMovieCards[movieId]
    }
    
    /// Get all cached movie cards for a list
    func getCachedMovieCardsForList(listId: String) -> [MasterlistMovie] {
        let movieIds = getMoviesInList(listId: listId)
        return movieIds.compactMap { cachedMovieCards[$0] }
            .sorted { $0.title < $1.title } // Sort by title for consistent ordering
    }
    
    /// Cache a movie card
    func cacheMovieCard(_ movie: MasterlistMovie) {
        cachedMovieCards[movie.id] = movie
    }
    
    /// Cache multiple movie cards
    func cacheMovieCards(_ movies: [MasterlistMovie]) {
        for movie in movies {
            cachedMovieCards[movie.id] = movie
        }
    }
    
    /// Clear cached movie cards (call when list changes significantly)
    func clearMovieCardCache() {
        cachedMovieCards.removeAll()
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
            movieRecommendations[movieId] = MovieRecommendationData(
                recommenderName: recommenderName,
                recommendedAt: Date(),
                recommenderNotes: recommenderNotes
            )
            print("✅ WatchlistManager: Stored recommendation data for movie \(movieId) - recommender: '\(recommenderName)'")
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
        
        // Save to cache
        saveToCache()
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        // Write-through to Supabase
        Task {
            do {
                print("💾 WatchlistManager: Syncing movie \(movieId) to Supabase (listId: \(listId), recommender: \(recommenderName ?? "nil"))")
                try await SupabaseWatchlistAdapter.addMovie(
                    movieId: movieId,
                    toListId: listId,
                    recommenderName: recommenderName,
                    recommenderNotes: recommenderNotes
                )
                print("✅ WatchlistManager: Successfully synced movie \(movieId) to Supabase with recommender: \(recommenderName ?? "nil")")
            } catch {
                print("❌ Failed to sync addMovieToList to Supabase:", error)
            }
        }
        
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
        
        // Save to cache
        saveToCache()
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        // Write-through to Supabase
        Task {
            do {
                try await SupabaseWatchlistAdapter.removeMovie(
                    movieId: movieId,
                    fromListId: listId
                )
            } catch {
                print("❌ Failed to sync removeMovieFromList to Supabase:", error)
            }
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
        print("✅ WatchlistManager.markAsWatched: movieId=\(movieId)")
        watchedMovies[movieId] = true
        saveToCache()
        
        // Notify observers that watched state changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        // Write-through to Supabase (via watch_history)
        Task {
            do {
                guard let userId = try await SupabaseService.shared.getCurrentUser()?.id else {
                    print("⚠️ WatchlistManager.markAsWatched: No user ID available")
                    return
                }
                _ = try await SupabaseService.shared.addToWatchHistory(
                    userId: userId,
                    movieId: movieId,
                    platform: nil
                )
                print("✅ WatchlistManager.markAsWatched: Successfully synced to Supabase")
            } catch {
                print("❌ Failed to sync markAsWatched to Supabase:", error)
            }
        }
    }
    
    /// Mark a movie as not watched
    func markAsNotWatched(movieId: String) {
        print("❌ WatchlistManager.markAsNotWatched: movieId=\(movieId)")
        watchedMovies[movieId] = false
        saveToCache()
        
        // Notify observers that watched state changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        // Write-through to Supabase (remove from watch_history)
        Task {
            do {
                guard let userId = try await SupabaseService.shared.getCurrentUser()?.id else {
                    print("⚠️ WatchlistManager.markAsNotWatched: No user ID available")
                    return
                }
                try await SupabaseService.shared.removeFromWatchHistory(
                    userId: userId,
                    movieId: movieId
                )
                print("✅ WatchlistManager.markAsNotWatched: Successfully synced to Supabase")
            } catch {
                print("❌ Failed to sync markAsNotWatched to Supabase:", error)
            }
        }
    }
    
    /// Toggle watched status
    func toggleWatched(movieId: String) {
        let currentStatus = isWatched(movieId: movieId)
        print("🎬 WatchlistManager.toggleWatched: movieId=\(movieId), currentStatus=\(currentStatus)")
        if currentStatus {
            markAsNotWatched(movieId: movieId)
        } else {
            markAsWatched(movieId: movieId)
        }
        print("   New watched status: \(isWatched(movieId: movieId))")
    }
    
    /// Check if a movie is watched
    func isWatched(movieId: String) -> Bool {
        return watchedMovies[movieId] ?? false
    }
    
    /// Get recommendation data for a movie
    func getRecommendationData(movieId: String) -> (recommenderName: String?, recommendedAt: Date?, recommenderNotes: String?)? {
        guard let data = movieRecommendations[movieId] else {
            return nil
        }
        return (data.recommenderName, data.recommendedAt, data.recommenderNotes)
    }
    
    /// Get the count of movies in a list
    func getListCount(listId: String) -> Int {
        return listMovies[listId]?.count ?? 0
    }
    
    // MARK: - List Management
    
    /// Create a new watchlist
    func createWatchlist(name: String) -> WatchlistItem {
        // Optimistic local creation with temporary ID
        let tempListId = String(nextListId)
        nextListId += 1
        
        let watchlist = WatchlistItem(
            id: tempListId,
            name: name,
            filmCount: 0,
            thumbnailURL: nil
        )
        
        watchlistMetadata[tempListId] = watchlist
        listMovies[tempListId] = Set<String>()
        
        // Save to cache
        saveToCache()
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        // Write-through to Supabase
        Task {
            do {
                let realId = try await SupabaseWatchlistAdapter.createWatchlist(name: name)
                let realIdString = realId.uuidString
                
                // Update local state with real Supabase ID
                await MainActor.run {
                    if let existingMetadata = self.watchlistMetadata[tempListId] {
                        // Move data to real ID
                        self.watchlistMetadata[realIdString] = WatchlistItem(
                            id: realIdString,
                            name: existingMetadata.name,
                            filmCount: existingMetadata.filmCount,
                            thumbnailURL: existingMetadata.thumbnailURL
                        )
                        
                        if let movies = self.listMovies[tempListId] {
                            self.listMovies[realIdString] = movies
                            // Update movieLists reverse index
                            for movieId in movies {
                                self.movieLists[movieId]?.remove(tempListId)
                                if self.movieLists[movieId] == nil {
                                    self.movieLists[movieId] = Set<String>()
                                }
                                self.movieLists[movieId]?.insert(realIdString)
                            }
                        }
                        
                        // Remove temp entry
                        self.watchlistMetadata.removeValue(forKey: tempListId)
                        self.listMovies.removeValue(forKey: tempListId)
                        
                        self.saveToCache()
                        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
                    }
                }
            } catch {
                print("❌ Failed to sync createWatchlist to Supabase:", error)
            }
        }
        
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
        
        // Save to cache
        saveToCache()
        
        // Notify observers that lists have changed
        NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
        
        // Write-through to Supabase
        Task {
            do {
                try await SupabaseWatchlistAdapter.deleteWatchlist(listId: listId)
            } catch {
                print("❌ Failed to sync deleteWatchlist to Supabase:", error)
            }
        }
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
            // Sort by creation order (list ID as number, or UUID string comparison)
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
            
            // Save to cache
            saveToCache()
            
            // Notify observers that lists have changed
            NotificationCenter.default.post(name: Notification.Name("WatchlistManagerDidUpdate"), object: nil)
            
            // Write-through to Supabase
            Task {
                do {
                    try await SupabaseWatchlistAdapter.updateWatchlistName(
                        listId: listId,
                        newName: newName
                    )
                } catch {
                    print("❌ Failed to sync updateWatchlistName to Supabase:", error)
                }
            }
        }
    }
    
    /// Duplicate a watchlist
    func duplicateWatchlist(listId: String) -> WatchlistItem? {
        guard let sourceMetadata = watchlistMetadata[listId],
              let sourceMovies = listMovies[listId] else {
            return nil
        }
        
        // Create new list with "Copy of" prefix
        let newName = "Copy of \(sourceMetadata.name)"
        let newWatchlist = createWatchlist(name: newName)
        
        // Copy all movies to the new list
        for movieId in sourceMovies {
            // Get recommendation data from source if it exists
            let recommendationData = movieRecommendations[movieId]
            _ = addMovieToList(
                movieId: movieId,
                listId: newWatchlist.id,
                recommenderName: recommendationData?.recommenderName,
                recommenderNotes: recommendationData?.recommenderNotes
            )
        }
        
        return newWatchlist
    }
    
    // MARK: - Supabase Sync
    
    /// Sync watchlist data from Supabase
    func syncFromSupabase() async {
        // Set loading flag to true before starting sync
        await MainActor.run {
            self.isMasterListCountLoading = true
        }
        
        do {
            let remoteData = try await SupabaseWatchlistAdapter.fetchAllWatchlistDataForCurrentUser()
            
            await MainActor.run {
                self.listMovies = remoteData.listMovies
                self.movieLists = remoteData.movieLists
                self.watchedMovies = remoteData.watchedMovies
                self.movieRecommendations = remoteData.movieRecommendations
                self.watchlistMetadata = remoteData.watchlistMetadata
                self.nextListId = remoteData.nextListId
                
                self.saveToCache()
                
                // Set loading flag to false after data is updated
                self.isMasterListCountLoading = false
                
                NotificationCenter.default.post(
                    name: Notification.Name("WatchlistManagerDidUpdate"),
                    object: nil
                )
            }
        } catch {
            print("❌ WatchlistManager.syncFromSupabase error:", error)
            // On error, we keep using the cached/local state.
            // Still set loading flag to false so spinner doesn't spin forever
            await MainActor.run {
                self.isMasterListCountLoading = false
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func cacheURL() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Ensure the documents directory exists
        try? FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        
        return documentsDir.appendingPathComponent("watchlists_cache.json")
    }
    
    private func saveToCache() {
        guard let url = cacheURL() else {
            print("⚠️ WatchlistManager.saveToCache: Could not get cache URL")
            return
        }
        
        let snapshot = WatchlistSnapshot(
            listMovies: listMovies,
            movieLists: movieLists,
            watchedMovies: watchedMovies,
            movieRecommendations: movieRecommendations,
            watchlistMetadata: watchlistMetadata,
            nextListId: nextListId
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            let totalMovies = listMovies.values.reduce(0) { $0 + $1.count }
            print("✅ WatchlistManager.saveToCache: Saved \(watchlistMetadata.count) watchlists, \(totalMovies) movies to \(url.path)")
        } catch {
            print("❌ WatchlistManager.saveToCache error:", error)
            if let encodingError = error as? EncodingError {
                print("   Encoding error details: \(encodingError)")
            }
        }
    }
    
    private func loadFromCache() {
        guard let url = cacheURL() else {
            print("⚠️ WatchlistManager.loadFromCache: Could not get cache URL")
            return
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("ℹ️ WatchlistManager.loadFromCache: No cached data found at \(url.path)")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(WatchlistSnapshot.self, from: data)
            
            self.listMovies = snapshot.listMovies
            self.movieLists = snapshot.movieLists
            self.watchedMovies = snapshot.watchedMovies
            self.movieRecommendations = snapshot.movieRecommendations
            self.watchlistMetadata = snapshot.watchlistMetadata
            self.nextListId = snapshot.nextListId
            
            let totalMovies = listMovies.values.reduce(0) { $0 + $1.count }
            print("✅ WatchlistManager.loadFromCache: Loaded \(watchlistMetadata.count) watchlists, \(totalMovies) movies from \(url.path)")
        } catch {
            print("❌ WatchlistManager.loadFromCache error:", error)
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
            }
            // If cache is corrupted, remove it so we can start fresh
            try? FileManager.default.removeItem(at: url)
            print("   Removed corrupted cache file")
        }
    }
    
    // MARK: - Mock Data Loading
    
    private func loadMockData() {
        // Initialize masterlist only - no mock watchlists
        let masterlist = WatchlistItem(id: "masterlist", name: "Masterlist", filmCount: 0, thumbnailURL: nil)
        watchlistMetadata["masterlist"] = masterlist
        listMovies["masterlist"] = Set<String>()
        
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
