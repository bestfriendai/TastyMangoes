//  SupabaseService.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:45 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-01-15 at 16:20 (America/Los_Angeles - Pacific Time)
//  Notes: Supabase service layer for database operations - updated to match revised schema with watch_history and user_ratings

import Foundation
import Supabase
import Auth
import Combine

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private var client: SupabaseClient?
    
    private init() {
        setupClient()
    }
    
    private func setupClient() {
        guard let url = URL(string: SupabaseConfig.supabaseURL),
              !SupabaseConfig.supabaseAnonKey.isEmpty else {
            print("⚠️ Supabase not configured. Please set SupabaseConfig values.")
            return
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: Auth.AuthResponse = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        return AuthResponse(
            user: response.user,
            session: response.session
        )
    }
    
    func signIn(email: String, password: String) async throws -> SupabaseSession {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // Supabase auth.signIn returns Session directly
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        return session
    }
    
    func signOut() async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        try await client.auth.signOut()
    }
    
    func getCurrentUser() async throws -> SupabaseUser? {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        return client.auth.currentUser
    }
    
    func getCurrentSession() async throws -> SupabaseSession? {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        return client.auth.currentSession
    }
    
    // MARK: - Profile Operations
    
    func getProfile(userId: UUID) async throws -> UserProfile {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: UserProfile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        return response
    }
    
    func updateProfile(userId: UUID, username: String?, avatarURL: String?) async throws -> UserProfile {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // Wait a moment for the trigger to create the profile (if it hasn't already)
        // Then try to update it
        var retries = 3
        
        while retries > 0 {
            do {
                // Try to get existing profile first
                let existing: UserProfile = try await client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                // Profile exists, update it
                struct ProfileUpdate: Codable {
                    let username: String?
                    let avatar_url: String?
                }
                
                let updateData = ProfileUpdate(
                    username: username ?? existing.username,
                    avatar_url: avatarURL ?? existing.avatarURL
                )
                
                let response: UserProfile = try await client
                    .from("profiles")
                    .update(updateData)
                    .eq("id", value: userId.uuidString)
                    .select()
                    .single()
                    .execute()
                    .value
                
                return response
            } catch {
                retries -= 1
                
                // If profile doesn't exist yet, wait a moment and retry
                // The trigger should create it automatically
                if retries > 0 {
                    try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                    continue
                }
            }
        }
        
        // If we get here, the profile still doesn't exist after retries
        // Try to create it manually (we're authenticated, so RLS should allow it)
        let finalUsername = username ?? "user_\(userId.uuidString.prefix(8))"
        
        struct ProfileInsert: Codable {
            let id: UUID
            let username: String
            let avatar_url: String?
        }
        
        let insertData = ProfileInsert(
            id: userId,
            username: finalUsername,
            avatar_url: avatarURL
        )
        
        do {
            let response: UserProfile = try await client
                .from("profiles")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value
            
            return response
        } catch {
            // If insert also fails, throw the original error
            throw SupabaseError.profileNotFound
        }
    }
    
    // MARK: - Subscription Operations
    
    func getUserSubscriptions(userId: UUID) async throws -> [String] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [UserSubscription] = try await client
            .from("user_subscriptions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return response.map { $0.platform }
    }
    
    func setUserSubscriptions(userId: UUID, platforms: [String]) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // Delete existing subscriptions
        try await client
            .from("user_subscriptions")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // Insert new subscriptions
        if !platforms.isEmpty {
            let subscriptions = platforms.map { platform in
                UserSubscription(userId: userId, platform: platform)
            }
            
            try await client
                .from("user_subscriptions")
                .insert(subscriptions)
                .execute()
        }
    }
    
    // MARK: - Watchlist Operations
    
    func getUserWatchlists(userId: UUID) async throws -> [Watchlist] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [Watchlist] = try await client
            .from("watchlists")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func createWatchlist(userId: UUID, name: String) async throws -> Watchlist {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let watchlist = Watchlist(
            userId: userId,
            name: name,
            thumbnailURL: nil,
            sortOrder: 0
        )
        
        let response: Watchlist = try await client
            .from("watchlists")
            .insert(watchlist)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func updateWatchlist(watchlistId: UUID, name: String?, thumbnailURL: String?) async throws -> Watchlist {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // Create a Codable struct for updates
        struct WatchlistUpdate: Codable {
            let name: String?
            let thumbnail_url: String?
        }
        
        let updateData = WatchlistUpdate(
            name: name,
            thumbnail_url: thumbnailURL
        )
        
        let response: Watchlist = try await client
            .from("watchlists")
            .update(updateData)
            .eq("id", value: watchlistId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func deleteWatchlist(watchlistId: UUID) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        try await client
            .from("watchlists")
            .delete()
            .eq("id", value: watchlistId.uuidString)
            .execute()
    }
    
    // MARK: - Watchlist Movie Operations (simplified - no watched/rating fields)
    
    func getWatchlistMovies(watchlistId: UUID) async throws -> [WatchlistMovie] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [WatchlistMovie] = try await client
            .from("watchlist_movies")
            .select()
            .eq("watchlist_id", value: watchlistId.uuidString)
            .order("added_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func addMovieToWatchlist(watchlistId: UUID, movieId: String) async throws -> WatchlistMovie {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let watchlistMovie = WatchlistMovie(
            watchlistId: watchlistId,
            movieId: movieId
        )
        
        let response: WatchlistMovie = try await client
            .from("watchlist_movies")
            .insert(watchlistMovie)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func removeMovieFromWatchlist(watchlistId: UUID, movieId: String) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        try await client
            .from("watchlist_movies")
            .delete()
            .eq("watchlist_id", value: watchlistId.uuidString)
            .eq("movie_id", value: movieId)
            .execute()
    }
    
    // MARK: - Watch History Operations
    
    func addToWatchHistory(userId: UUID, movieId: String, platform: String?) async throws -> WatchHistory {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let watchHistory = WatchHistory(
            userId: userId,
            movieId: movieId,
            watchedAt: Date(),
            platform: platform
        )
        
        // Use upsert to handle duplicates (UNIQUE constraint)
        let response: WatchHistory = try await client
            .from("watch_history")
            .upsert(watchHistory)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func removeFromWatchHistory(userId: UUID, movieId: String) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        try await client
            .from("watch_history")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("movie_id", value: movieId)
            .execute()
    }
    
    func getUserWatchHistory(userId: UUID) async throws -> [WatchHistory] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [WatchHistory] = try await client
            .from("watch_history")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("watched_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func isMovieWatched(userId: UUID, movieId: String) async throws -> Bool {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [WatchHistory] = try await client
            .from("watch_history")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("movie_id", value: movieId)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    // MARK: - User Rating Operations
    
    func addOrUpdateRating(userId: UUID, movieId: String, rating: Int, reviewText: String?) async throws -> UserRating {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let userRating = UserRating(
            userId: userId,
            movieId: movieId,
            rating: rating,
            reviewText: reviewText
        )
        
        // Use upsert to handle duplicates (UNIQUE constraint)
        let response: UserRating = try await client
            .from("user_ratings")
            .upsert(userRating)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func deleteRating(userId: UUID, movieId: String) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        try await client
            .from("user_ratings")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("movie_id", value: movieId)
            .execute()
    }
    
    func getUserRating(userId: UUID, movieId: String) async throws -> UserRating? {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [UserRating] = try await client
            .from("user_ratings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("movie_id", value: movieId)
            .execute()
            .value
        
        return response.first
    }
    
    func getMovieRatings(movieId: String) async throws -> [UserRating] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [UserRating] = try await client
            .from("user_ratings")
            .select()
            .eq("movie_id", value: movieId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Movie Cache Operations
    
    func cacheMovie(_ movie: Movie) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let dbMovie = DatabaseMovie(from: movie)
        
        try await client
            .from("movies")
            .upsert(dbMovie)
            .execute()
    }
    
    // MARK: - Movie Card Operations (New Ingestion Pipeline)
    
    /// Fetches a pre-built movie card from the ingestion pipeline
    /// If the movie doesn't exist, it will trigger ingestion automatically
    /// Accepts tmdbId as String or Int
    func fetchMovieCard(tmdbId: String) async throws -> MovieCard {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/functions/v1/get-movie-card") else {
            throw SupabaseError.invalidResponse
        }
        
        // Use POST with body (supports both string and number)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Try to convert to Int if possible, otherwise use as String
        let tmdbIdValue: Any = Int(tmdbId) ?? tmdbId
        let requestBody: [String: Any] = ["tmdb_id": tmdbIdValue]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
            throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MovieCard.self, from: data)
    }
    
    /// Fetches a pre-built movie card using Int tmdbId
    func fetchMovieCard(tmdbId: Int) async throws -> MovieCard {
        return try await fetchMovieCard(tmdbId: String(tmdbId))
    }
    
    /// Searches for movies using TMDB API
    func searchMovies(query: String, year: Int? = nil) async throws -> [MovieSearchResult] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(SupabaseConfig.supabaseURL)/functions/v1/search-movies")
        var queryItems = [URLQueryItem(name: "q", value: query)]
        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw SupabaseError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(SupabaseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
            throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(SearchResponse.self, from: data)
        return result.movies
    }
    
    /// Triggers ingestion for a movie (force refresh)
    func ingestMovie(tmdbId: String, forceRefresh: Bool = false) async throws -> MovieCard {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/functions/v1/ingest-movie") else {
            throw SupabaseError.invalidResponse
        }
        
        struct IngestRequest: Codable {
            let tmdb_id: String
            let force_refresh: Bool
        }
        
        let requestBody = IngestRequest(tmdb_id: tmdbId, force_refresh: forceRefresh)
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
            throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Response might have 'card' wrapper or be the card directly
        if let wrapper = try? decoder.decode([String: AnyCodable].self, from: data),
           let cardData = wrapper["card"],
           let cardJSON = try? JSONSerialization.data(withJSONObject: cardData.value) {
            return try decoder.decode(MovieCard.self, from: cardJSON)
        }
        return try decoder.decode(MovieCard.self, from: data)
    }
}

// MARK: - Helper for Dynamic JSON Decoding

private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

// MARK: - Error Types

enum SupabaseError: LocalizedError {
    case notConfigured
    case noSession
    case invalidResponse
    case networkError(Error)
    case profileNotFound
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Please set your Supabase URL and key."
        case .profileNotFound:
            return "User profile not found. Please try signing up again."
        case .noSession:
            return "No active session found."
        case .invalidResponse:
            return "Invalid response from server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
