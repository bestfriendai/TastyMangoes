//  SupabaseWatchlistAdapter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-17 at 00:00 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-06 at 12:00 (America/Los_Angeles - Pacific Time)
//  Notes: Adapter to fetch and sync watchlist data from Supabase for WatchlistManager. Fixed masterlist sync - now creates/finds Masterlist watchlist in Supabase and syncs movies properly. Added extensive logging to debug masterlist movie loading issues.

import Foundation
import Auth

// MARK: - Watchlist Data Snapshot

struct WatchlistDataSnapshot {
    let listMovies: [String: Set<String>]
    let movieLists: [String: Set<String>]
    let watchedMovies: [String: Bool]
    let movieRecommendations: [String: MovieRecommendationData]
    let watchlistMetadata: [String: WatchlistItem]
    let nextListId: Int
}

// MARK: - Supabase Watchlist Adapter

@MainActor
struct SupabaseWatchlistAdapter {
    static func fetchAllWatchlistDataForCurrentUser() async throws -> WatchlistDataSnapshot {
        guard let userId = try await getCurrentUserId() else {
            throw SupabaseError.noSession
        }
        
        let supabaseService = SupabaseService.shared
        
        // Fetch all watchlists for the user
        let watchlists = try await supabaseService.getUserWatchlists(userId: userId)
        
        // Build data structures
        var listMovies: [String: Set<String>] = [:]
        var movieLists: [String: Set<String>] = [:]
        var movieRecommendations: [String: MovieRecommendationData] = [:]
        var watchlistMetadata: [String: WatchlistItem] = [:]
        var maxListId = 100
        
        // Find masterlist watchlist if it exists
        var masterlistWatchlist: Watchlist?
        var regularWatchlists: [Watchlist] = []
        
        for watchlist in watchlists {
            if watchlist.name.lowercased() == "masterlist" {
                masterlistWatchlist = watchlist
            } else {
                regularWatchlists.append(watchlist)
            }
        }
        
        // Process regular watchlists (non-masterlist)
        for watchlist in regularWatchlists {
            let listId = watchlist.id.uuidString
            
            // Store watchlist metadata
            watchlistMetadata[listId] = WatchlistItem(
                id: listId,
                name: watchlist.name,
                filmCount: 0, // Will be updated below
                thumbnailURL: watchlist.thumbnailURL
            )
            
            // Track max ID for nextListId calculation
            if let numericId = Int(listId) {
                maxListId = max(maxListId, numericId)
            }
            
            // Fetch movies in this watchlist
            let watchlistMovies = try await supabaseService.getWatchlistMovies(watchlistId: watchlist.id)
            
            var movieSet: Set<String> = []
            for watchlistMovie in watchlistMovies {
                let movieId = watchlistMovie.movieId
                movieSet.insert(movieId)
                
                // Update movieLists (reverse index)
                if movieLists[movieId] == nil {
                    movieLists[movieId] = Set<String>()
                }
                movieLists[movieId]?.insert(listId)
                
                // Store recommendation data if present
                if let recommenderName = watchlistMovie.recommenderName {
                    movieRecommendations[movieId] = MovieRecommendationData(
                        recommenderName: recommenderName,
                        recommendedAt: watchlistMovie.recommendedAt,
                        recommenderNotes: watchlistMovie.recommenderNotes
                    )
                    print("✅ SupabaseWatchlistAdapter: Loaded watchlist item for movie \(movieId) with recommendedBy = \(recommenderName)")
                }
            }
            
            listMovies[listId] = movieSet
            
            // Update film count in metadata
            watchlistMetadata[listId] = WatchlistItem(
                id: listId,
                name: watchlist.name,
                filmCount: movieSet.count,
                thumbnailURL: watchlist.thumbnailURL
            )
        }
        
        // Fetch watch history for watched status
        var watchedMovies: [String: Bool] = [:]
        let watchHistory = try await supabaseService.getUserWatchHistory(userId: userId)
        for history in watchHistory {
            watchedMovies[history.movieId] = true
        }
        
        // Handle masterlist: Find or create a "Masterlist" watchlist in Supabase
        var masterlistWatchlistId: UUID?
        if let existingMasterlist = masterlistWatchlist {
            masterlistWatchlistId = existingMasterlist.id
            print("✅ Found existing Masterlist watchlist: \(existingMasterlist.id)")
        } else {
            // Create masterlist watchlist if it doesn't exist
            do {
                let newMasterlistWatchlist = try await supabaseService.createWatchlist(userId: userId, name: "Masterlist")
                masterlistWatchlistId = newMasterlistWatchlist.id
                print("✅ Created new Masterlist watchlist: \(newMasterlistWatchlist.id)")
            } catch {
                print("⚠️ Failed to create Masterlist watchlist: \(error)")
            }
        }
        
        // Fetch masterlist movies if we have a masterlist watchlist
        var masterlistMovieSet: Set<String> = []
        if let masterlistId = masterlistWatchlistId {
            print("🔄 [SupabaseWatchlistAdapter] Fetching movies for masterlist watchlist: \(masterlistId)")
            let masterlistMovies = try await supabaseService.getWatchlistMovies(watchlistId: masterlistId)
            print("✅ [SupabaseWatchlistAdapter] Found \(masterlistMovies.count) movies in masterlist watchlist")
            
            for watchlistMovie in masterlistMovies {
                let movieId = watchlistMovie.movieId
                masterlistMovieSet.insert(movieId)
                print("  📽️ [SupabaseWatchlistAdapter] Masterlist movie: \(movieId)")
                
                // Update movieLists (reverse index) - use "masterlist" string for backward compatibility
                if movieLists[movieId] == nil {
                    movieLists[movieId] = Set<String>()
                }
                movieLists[movieId]?.insert("masterlist")
                
                // Store recommendation data if present
                if let recommenderName = watchlistMovie.recommenderName {
                    movieRecommendations[movieId] = MovieRecommendationData(
                        recommenderName: recommenderName,
                        recommendedAt: watchlistMovie.recommendedAt,
                        recommenderNotes: watchlistMovie.recommenderNotes
                    )
                }
            }
            
            print("✅ [SupabaseWatchlistAdapter] Masterlist movie set contains \(masterlistMovieSet.count) movies")
            
            // Store masterlist metadata with UUID as the key
            let masterlistName = masterlistWatchlist?.name ?? "Masterlist"
            let masterlistThumbnail = masterlistWatchlist?.thumbnailURL
            watchlistMetadata[masterlistId.uuidString] = WatchlistItem(
                id: masterlistId.uuidString,
                name: masterlistName,
                filmCount: masterlistMovieSet.count,
                thumbnailURL: masterlistThumbnail
            )
            listMovies[masterlistId.uuidString] = masterlistMovieSet
        }
        
        // Also map "masterlist" string ID to the same data for backward compatibility
        if masterlistWatchlistId != nil {
            watchlistMetadata["masterlist"] = WatchlistItem(
                id: "masterlist",
                name: "Masterlist",
                filmCount: masterlistMovieSet.count,
                thumbnailURL: nil
            )
            listMovies["masterlist"] = masterlistMovieSet
            print("✅ [SupabaseWatchlistAdapter] Mapped masterlist string ID to \(masterlistMovieSet.count) movies")
        } else {
            // Fallback: ensure masterlist exists even if creation failed
            watchlistMetadata["masterlist"] = WatchlistItem(
                id: "masterlist",
                name: "Masterlist",
                filmCount: 0,
                thumbnailURL: nil
            )
            listMovies["masterlist"] = Set<String>()
            print("⚠️ [SupabaseWatchlistAdapter] Masterlist watchlist not found, using empty set")
        }
        
        return WatchlistDataSnapshot(
            listMovies: listMovies,
            movieLists: movieLists,
            watchedMovies: watchedMovies,
            movieRecommendations: movieRecommendations,
            watchlistMetadata: watchlistMetadata,
            nextListId: maxListId + 1
        )
    }
    
    static func addMovie(
        movieId: String,
        toListId: String,
        recommenderName: String?,
        recommenderNotes: String?
    ) async throws {
        print("🔄 [SupabaseWatchlistAdapter] addMovie called: movieId=\(movieId), toListId=\(toListId)")
        let supabaseService = SupabaseService.shared
        
        // Handle masterlist specially: find or create the Masterlist watchlist
        if toListId == "masterlist" {
            print("🔄 [SupabaseWatchlistAdapter] Adding to masterlist - finding/creating watchlist...")
            guard let userId = try await getCurrentUserId() else {
                print("❌ [SupabaseWatchlistAdapter] No user ID available")
                throw SupabaseError.noSession
            }
            
            // Find or create masterlist watchlist
            let watchlists = try await supabaseService.getUserWatchlists(userId: userId)
            var masterlistWatchlistId: UUID?
            
            if let existingMasterlist = watchlists.first(where: { $0.name.lowercased() == "masterlist" }) {
                masterlistWatchlistId = existingMasterlist.id
                print("✅ [SupabaseWatchlistAdapter] Found existing masterlist watchlist: \(existingMasterlist.id)")
            } else {
                // Create masterlist watchlist if it doesn't exist
                print("🔄 [SupabaseWatchlistAdapter] Creating new masterlist watchlist...")
                let masterlistWatchlist = try await supabaseService.createWatchlist(userId: userId, name: "Masterlist")
                masterlistWatchlistId = masterlistWatchlist.id
                print("✅ [SupabaseWatchlistAdapter] Created masterlist watchlist: \(masterlistWatchlist.id)")
            }
            
            guard let watchlistId = masterlistWatchlistId else {
                print("❌ [SupabaseWatchlistAdapter] Failed to get masterlist watchlist ID")
                throw SupabaseError.invalidResponse
            }
            
            // Add movie to masterlist watchlist
            print("🔄 [SupabaseWatchlistAdapter] Adding movie \(movieId) to masterlist watchlist \(watchlistId)...")
            _ = try await supabaseService.addMovieToWatchlist(
                watchlistId: watchlistId,
                movieId: movieId,
                recommenderName: recommenderName,
                recommenderNotes: recommenderNotes
            )
            print("✅ [SupabaseWatchlistAdapter] Successfully added movie \(movieId) to masterlist watchlist")
            return
        }
        
        // Handle regular watchlists
        guard let watchlistId = UUID(uuidString: toListId) else {
            throw SupabaseError.invalidResponse
        }
        
        _ = try await supabaseService.addMovieToWatchlist(
            watchlistId: watchlistId,
            movieId: movieId,
            recommenderName: recommenderName,
            recommenderNotes: recommenderNotes
        )
    }
    
    static func removeMovie(
        movieId: String,
        fromListId: String
    ) async throws {
        let supabaseService = SupabaseService.shared
        
        // Handle masterlist specially: find the Masterlist watchlist
        if fromListId == "masterlist" {
            guard let userId = try await getCurrentUserId() else {
                throw SupabaseError.noSession
            }
            
            // Find masterlist watchlist
            let watchlists = try await supabaseService.getUserWatchlists(userId: userId)
            guard let masterlistWatchlist = watchlists.first(where: { $0.name.lowercased() == "masterlist" }) else {
                // Masterlist doesn't exist, nothing to remove
                return
            }
            
            try await supabaseService.removeMovieFromWatchlist(
                watchlistId: masterlistWatchlist.id,
                movieId: movieId
            )
            return
        }
        
        // Handle regular watchlists
        guard let watchlistId = UUID(uuidString: fromListId) else {
            throw SupabaseError.invalidResponse
        }
        
        try await supabaseService.removeMovieFromWatchlist(
            watchlistId: watchlistId,
            movieId: movieId
        )
    }
    
    static func createWatchlist(name: String) async throws -> UUID {
        guard let userId = try await getCurrentUserId() else {
            throw SupabaseError.noSession
        }
        
        let supabaseService = SupabaseService.shared
        let watchlist = try await supabaseService.createWatchlist(userId: userId, name: name)
        return watchlist.id
    }
    
    static func deleteWatchlist(listId: String) async throws {
        guard let watchlistId = UUID(uuidString: listId) else {
            // If it's "masterlist" or not a UUID, skip Supabase sync
            if listId == "masterlist" {
                return
            }
            throw SupabaseError.invalidResponse
        }
        
        let supabaseService = SupabaseService.shared
        try await supabaseService.deleteWatchlist(watchlistId: watchlistId)
    }
    
    static func updateWatchlistName(listId: String, newName: String) async throws {
        guard let watchlistId = UUID(uuidString: listId) else {
            // If it's "masterlist" or not a UUID, skip Supabase sync
            if listId == "masterlist" {
                return
            }
            throw SupabaseError.invalidResponse
        }
        
        let supabaseService = SupabaseService.shared
        _ = try await supabaseService.updateWatchlist(
            watchlistId: watchlistId,
            name: newName,
            thumbnailURL: nil
        )
    }
    
    // MARK: - Helper
    
    private static func getCurrentUserId() async throws -> UUID? {
        let supabaseService = SupabaseService.shared
        guard let user = try await supabaseService.getCurrentUser() else {
            return nil
        }
        return user.id
    }
}

