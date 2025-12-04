//  SupabaseWatchlistAdapter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-17 at 00:00 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 09:09 PST by Cursor Assistant
//  Notes: Adapter to fetch and sync watchlist data from Supabase for WatchlistManager

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
        
        // Process each watchlist
        for watchlist in watchlists {
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
        
        // Ensure masterlist exists
        if watchlistMetadata["masterlist"] == nil {
            watchlistMetadata["masterlist"] = WatchlistItem(
                id: "masterlist",
                name: "Masterlist",
                filmCount: 0,
                thumbnailURL: nil
            )
            listMovies["masterlist"] = Set<String>()
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
        guard let watchlistId = UUID(uuidString: toListId) else {
            // If it's "masterlist" or not a UUID, skip Supabase sync
            // (masterlist is a special local-only list)
            if toListId == "masterlist" {
                return
            }
            throw SupabaseError.invalidResponse
        }
        
        let supabaseService = SupabaseService.shared
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
        guard let watchlistId = UUID(uuidString: fromListId) else {
            // If it's "masterlist" or not a UUID, skip Supabase sync
            if fromListId == "masterlist" {
                return
            }
            throw SupabaseError.invalidResponse
        }
        
        let supabaseService = SupabaseService.shared
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

