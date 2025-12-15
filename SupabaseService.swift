//  SupabaseService.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:45 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-01-15 at 16:20 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-15 at 11:25 (America/Los_Angeles - Pacific Time) / 19:25 UTC
//  Changes: Added fetchMovieCardsBatch() method for efficient batch fetching of multiple
//           movie cards in a single Supabase query. This eliminates the N+1 query problem
//           when loading watchlists.
//           Phase 2: Added new VoiceEvent fields for intent tracking (search_intent,
//           confidence_score, extracted_hints, handoff tracking, clarification, selected_movie_id)

import Foundation
import Supabase
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
    
    func getAllUsers() async throws -> [UserProfile] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [UserProfile] = try await client
            .from("profiles")
            .select("id, username, created_at")
            .order("created_at", ascending: false)
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
        print("📋 [Watchlist] getUserWatchlists called for user: \(userId)")
        
        guard let client = client else {
            print("❌ [Watchlist] Supabase client not configured")
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
        
        print("📋 [Watchlist] Loaded \(response.count) watchlists from Supabase for user \(userId)")
        for watchlist in response {
            print("  📋 [Watchlist] - \(watchlist.name) (ID: \(watchlist.id))")
        }
        
        return response
    }
    
    func createWatchlist(userId: UUID, name: String) async throws -> Watchlist {
        print("📋 [Watchlist] createWatchlist called: name=\(name), userId=\(userId)")
        
        guard let client = client else {
            print("❌ [Watchlist] Supabase client not configured")
            throw SupabaseError.notConfigured
        }
        
        let watchlist = Watchlist(
            userId: userId,
            name: name,
            thumbnailURL: nil,
            sortOrder: 0
        )
        
        print("📋 [Watchlist] Inserting watchlist into Supabase...")
        let response: Watchlist = try await client
            .from("watchlists")
            .insert(watchlist)
            .select()
            .single()
            .execute()
            .value
        
        print("📋 [Watchlist] Successfully created watchlist in Supabase: \(name) (ID: \(response.id))")
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
    
    func addMovieToWatchlist(
        watchlistId: UUID,
        movieId: String,
        recommenderName: String? = nil,
        recommenderNotes: String? = nil
    ) async throws -> WatchlistMovie {
        print("📋 [Supabase] addMovieToWatchlist called: watchlistId=\(watchlistId), movieId=\(movieId), recommenderName=\(recommenderName ?? "nil")")
        
        guard let client = client else {
            print("❌ [Supabase] Client not configured")
            throw SupabaseError.notConfigured
        }
        
        let watchlistMovie = WatchlistMovie(
            watchlistId: watchlistId,
            movieId: movieId,
            recommenderName: recommenderName,
            recommendedAt: recommenderName != nil ? Date() : nil,
            recommenderNotes: recommenderNotes
        )
        
        print("📋 [Supabase] Inserting into watchlist_movies table...")
        let response: WatchlistMovie = try await client
            .from("watchlist_movies")
            .insert(watchlistMovie)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ [Supabase] Successfully inserted movie \(movieId) into watchlist \(watchlistId)")
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
    
    // MARK: - Voice Events Operations
    
    /// Voice event from voice_utterance_events table
    /// Phase 2: Added intent tracking fields
    struct VoiceEvent: Identifiable, Codable {
        let id: UUID
        let created_at: String
        let utterance: String
        let mango_command_type: String?
        let final_command_type: String?
        let handler_result: String?
        let result_count: Int?
        let llm_used: Bool?
        let mango_command_movie_title: String?
        let mango_command_recommender: String?
        let error_message: String?
        
        // Phase 2: Intent tracking fields
        let search_intent: String?
        let confidence_score: Double?
        let extracted_hints: String?
        let handoff_initiated: Bool?
        let handoff_returned: Bool?
        let clarifying_question_asked: String?
        let clarifying_answer: String?
        let selected_movie_id: Int?
        let candidates_shown: Int?
    }
    
    func getVoiceEvents(limit: Int = 100) async throws -> [VoiceEvent] {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let response: [VoiceEvent] = try await client
            .from("voice_utterance_events")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response
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
        
        // Check if response is wrapped in a "card" property
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let cardData = jsonObject["card"] {
            // Response is wrapped: { "card": { ... } }
            let cardJSON = try JSONSerialization.data(withJSONObject: cardData)
            let decoder = JSONDecoder()
            // Don't use .convertFromSnakeCase since MovieCard has explicit CodingKeys
            return try decoder.decode(MovieCard.self, from: cardJSON)
        } else {
            // Response is direct: { "work_id": 3, "trailer_youtube_id": "...", ... }
            let decoder = JSONDecoder()
            // Don't use .convertFromSnakeCase since MovieCard has explicit CodingKeys
            return try decoder.decode(MovieCard.self, from: data)
        }
    }
    
    /// Fetches a pre-built movie card using Int tmdbId
    func fetchMovieCard(tmdbId: Int) async throws -> MovieCard {
        return try await fetchMovieCard(tmdbId: String(tmdbId))
    }
    
    /// Fetches multiple movie cards in a single batch query
    /// This is much more efficient than calling fetchMovieCard() multiple times
    /// Returns cards keyed by tmdbId for easy lookup
    func fetchMovieCardsBatch(tmdbIds: [String]) async throws -> [String: MovieCard] {
        guard !tmdbIds.isEmpty else {
            return [:]
        }
        
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        print("🎬 [SupabaseService] Batch fetching \(tmdbIds.count) movie cards...")
        
        // Step 1: Get work_ids for all tmdb_ids in one query
        struct WorkMapping: Codable {
            let workId: Int
            let tmdbId: String
            
            enum CodingKeys: String, CodingKey {
                case workId = "work_id"
                case tmdbId = "tmdb_id"
            }
        }
        
        let workMappings: [WorkMapping] = try await client
            .from("works")
            .select("work_id, tmdb_id")
            .in("tmdb_id", values: tmdbIds)
            .execute()
            .value
        
        guard !workMappings.isEmpty else {
            print("⚠️ [SupabaseService] No works found for provided tmdb_ids")
            return [:]
        }
        
        // Create mapping from work_id to tmdb_id for later
        let workIdToTmdbId = Dictionary(uniqueKeysWithValues: workMappings.map { ($0.workId, $0.tmdbId) })
        let workIds = workMappings.map { $0.workId }
        
        // Step 2: Fetch all cached cards in one query
        struct CacheEntry: Codable {
            let workId: Int
            let payload: MovieCard
            
            enum CodingKeys: String, CodingKey {
                case workId = "work_id"
                case payload
            }
        }
        
        let cacheEntries: [CacheEntry] = try await client
            .from("work_cards_cache")
            .select("work_id, payload")
            .in("work_id", values: workIds)
            .execute()
            .value
        
        // Step 3: Build result dictionary keyed by tmdb_id
        var result: [String: MovieCard] = [:]
        for entry in cacheEntries {
            if let tmdbId = workIdToTmdbId[entry.workId] {
                result[tmdbId] = entry.payload
            }
        }
        
        print("🎬 [SupabaseService] Batch fetch complete: \(result.count)/\(tmdbIds.count) cards found")
        
        // Log which ones were missing (for debugging)
        let foundIds = Set(result.keys)
        let missingIds = Set(tmdbIds).subtracting(foundIds)
        if !missingIds.isEmpty {
            print("⚠️ [SupabaseService] Missing from cache: \(missingIds)")
        }
        
        return result
    }
    
    /// Fetches a movie card directly from work_cards_cache table (no edge function call)
    /// Returns nil if the movie is not in the cache
    func fetchMovieCardFromCache(tmdbId: String) async throws -> MovieCard? {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // First, find the work_id from tmdb_id
        struct Work: Codable {
            let workId: Int
            
            enum CodingKeys: String, CodingKey {
                case workId = "work_id"
            }
        }
        
        struct CrewMember: Codable {
            let name: String
            let job: String
        }
        
        let works: [Work] = try await client
            .from("works")
            .select("work_id")
            .eq("tmdb_id", value: tmdbId)
            .execute()
            .value
        
        guard let work = works.first else {
            // Movie not found in works table
            return nil
        }
        
        // Now fetch from work_cards_cache
        struct CacheEntry: Codable {
            let payload: MovieCard
        }
        
        let cacheEntries: [CacheEntry] = try await client
            .from("work_cards_cache")
            .select("payload")
            .eq("work_id", value: work.workId)
            .execute()
            .value
        
        guard let cacheEntry = cacheEntries.first else {
            // Not in cache
            return nil
        }
        
        // Fetch crew members from works_meta
        struct WorksMeta: Codable {
            let crewMembers: [CrewMember]?
            
            enum CodingKeys: String, CodingKey {
                case crewMembers = "crew_members"
            }
        }
        
        let metaEntries: [WorksMeta] = try await client
            .from("works_meta")
            .select("crew_members")
            .eq("work_id", value: work.workId)
            .execute()
            .value
        
        // Extract crew roles from the crew_members array
        var writer: String? = nil
        var screenplay: String? = nil
        var composer: String? = nil
        
        if let crewMembers = metaEntries.first?.crewMembers {
            // Get all writers (job = "Writer")
            let writers = crewMembers.filter { $0.job == "Writer" }.map { $0.name }
            if !writers.isEmpty {
                writer = writers.joined(separator: ", ")
            }
            
            // Get all screenplay writers (job = "Screenplay")
            let screenwriters = crewMembers.filter { $0.job == "Screenplay" }.map { $0.name }
            if !screenwriters.isEmpty {
                screenplay = screenwriters.joined(separator: ", ")
            }
            
            // Get composer (job = "Original Music Composer")
            composer = crewMembers.first { $0.job == "Original Music Composer" }?.name
        }
        
        // Create MovieCard with crew data populated
        let card = cacheEntry.payload
        return MovieCard(
            workId: card.workId,
            tmdbId: card.tmdbId,
            imdbId: card.imdbId,
            title: card.title,
            originalTitle: card.originalTitle,
            year: card.year,
            releaseDate: card.releaseDate,
            runtimeMinutes: card.runtimeMinutes,
            runtimeDisplay: card.runtimeDisplay,
            tagline: card.tagline,
            overview: card.overview,
            overviewShort: card.overviewShort,
            genres: card.genres,
            poster: card.poster,
            backdrop: card.backdrop,
            trailerYoutubeId: card.trailerYoutubeId,
            trailerThumbnail: card.trailerThumbnail,
            certification: card.certification,
            cast: card.cast,
            director: card.director,
            writer: writer,
            screenplay: screenplay,
            composer: composer,
            aiScore: card.aiScore,
            aiScoreRange: card.aiScoreRange,
            sourceScores: card.sourceScores,
            similarMovieIds: card.similarMovieIds,
            stillImages: card.stillImages,
            trailers: card.trailers,
            lastUpdated: card.lastUpdated
        )
    }
    
    // MARK: - Similar Movies
    
    // TODO: Similar movies disabled - re-enable later
    // NOTE: Similar movies feature is completely disabled - no API calls, no UI display
    
    /// Similar movie result from get-similar-movies endpoint
    struct SimilarMovieResult: Codable {
        let tmdbId: Int
        let title: String
        let year: Int?
        let posterUrl: String?
        let rating: Double?
        
        enum CodingKeys: String, CodingKey {
            case tmdbId = "tmdb_id"
            case title
            case year
            case posterUrl = "poster_url"
            case rating
        }
    }
    
    /// Similar movies response
    struct SimilarMoviesResponse: Codable {
        let movies: [SimilarMovieResult]
    }
    
    /// Fetches similar movies by TMDB IDs with auto-ingestion
    // TODO: Similar movies disabled - re-enable later
    /*
    func fetchSimilarMovies(tmdbIds: [Int]) async throws -> [SimilarMovieResult] {
        guard let url = URL(string: "\(SupabaseConfig.supabaseURL)/functions/v1/get-similar-movies") else {
            throw SupabaseError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = ["tmdb_ids": tmdbIds]
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
        // Don't use .convertFromSnakeCase since SimilarMovieResult has explicit CodingKeys
        let responseObj = try decoder.decode(SimilarMoviesResponse.self, from: data)
        return responseObj.movies
    }
    */
    
    /// Gets the count of movies in our database for a specific genre
    func getGenreCount(genreName: String) async throws -> Int {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        // Create a simple struct to decode the response
        struct WorksMetaGenre: Codable {
            let genres: [String]?
        }
        
        let response: [WorksMetaGenre] = try await client
            .from("works_meta")
            .select("genres")
            .execute()
            .value
        
        // Count where genres array contains the genre name
        let count = response.filter { worksMeta in
            guard let genres = worksMeta.genres else { return false }
            return genres.contains(genreName)
        }.count
        
        return count
    }
    
    /// Searches for movies using TMDB API with optional year range and genre filters
    func searchMovies(query: String, yearRange: ClosedRange<Int>? = nil, genres: Set<String>? = nil) async throws -> [MovieSearchResult] {
        guard client != nil else {
            throw SupabaseError.notConfigured
        }
        
        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(SupabaseConfig.supabaseURL)/functions/v1/search-movies")
        var queryItems = [URLQueryItem(name: "q", value: query)]
        
        // Add year range parameters
        if let yearRange = yearRange {
            print("   📅 Adding year filter to URL: year_from=\(yearRange.lowerBound), year_to=\(yearRange.upperBound)")
            queryItems.append(URLQueryItem(name: "year_from", value: String(yearRange.lowerBound)))
            queryItems.append(URLQueryItem(name: "year_to", value: String(yearRange.upperBound)))
        } else {
            print("   📅 No year range provided (yearRange is nil)")
        }
        
        // Add genres parameter (comma-separated genre names)
        if let genres = genres, !genres.isEmpty {
            let genresString = genres.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "genres", value: genresString))
            print("   🎭 Adding genre filter to URL: genres=\(genresString)")
        } else {
            print("   🎭 No genres provided (genres is nil or empty)")
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw SupabaseError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(SupabaseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 Making request to: \(url.absoluteString)")
        print("   Method: GET")
        print("   Headers: Authorization=Bearer [REDACTED], Content-Type=application/json")
        
        // Verify year parameters are in the URL
        let urlString = url.absoluteString
        if urlString.contains("year_from") || urlString.contains("year_to") {
            print("   ✅ Year parameters found in URL")
        } else if yearRange != nil {
            print("   ⚠️ WARNING: yearRange was provided but not found in URL!")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("📥 Received response - Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        if let responseString = String(data: data, encoding: .utf8) {
            let preview = responseString.prefix(500)
            print("   Response preview: \(preview)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        // Try to decode response first - even if status code indicates error,
        // the Edge Function may return a valid movies array
        // NOTE: Don't use .convertFromSnakeCase because MovieSearchResult has explicit CodingKeys
        let decoder = JSONDecoder()
        
        // First, try to decode as SearchResponse to get movies
        if let result = try? decoder.decode(SearchResponse.self, from: data) {
            // Successfully decoded - return movies even if status code indicates error
            if !result.movies.isEmpty || (200...299).contains(httpResponse.statusCode) {
                return result.movies
            }
        }
        
        // If decoding failed or status code indicates error, check for error message
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
            
            // If we can't decode error, try to see what we got
            if let responseString = String(data: data, encoding: .utf8) {
                print("⚠️ Search API error response: \(responseString)")
            }
            
            throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
        }
        
        // If we get here, status is OK but decoding failed - try again with better error info
        do {
            // Don't use .convertFromSnakeCase - MovieSearchResult has explicit CodingKeys
            let result = try decoder.decode(SearchResponse.self, from: data)
            return result.movies
        } catch {
            print("❌ Failed to decode SearchResponse: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response body: \(responseString.prefix(1000))")
            }
            throw SupabaseError.networkError(NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"]))
        }
    }
    
    /// Logs a movie search event for analytics
    func logMovieSearch(query: String, resultCount: Int, source: String = "keyboard") {
        let properties: [String: Any] = [
            "query": query,
            "result_count": resultCount,
            "source": source
        ]
        
        // TODO: Implement actual analytics logging
        print("📊 [Analytics] Movie search logged: \(properties)")
    }
    
    /// Triggers ingestion for a movie (force refresh)
    func ingestMovie(tmdbId: String, forceRefresh: Bool = false) async throws -> MovieCard {
        guard client != nil else {
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
        
        // Check if response is wrapped in a "card" property
        // The API can return: { "card": { ... } } or { "work_id": 3, ... } directly
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let cardData = jsonObject["card"] {
            // Response is wrapped: { "card": { "work_id": 3, ... } }
            let cardJSON = try JSONSerialization.data(withJSONObject: cardData)
            let decoder = JSONDecoder()
            // Don't use .convertFromSnakeCase since MovieCard has explicit CodingKeys
            return try decoder.decode(MovieCard.self, from: cardJSON)
        } else {
            // Response is direct: { "work_id": 3, "trailer_youtube_id": "...", ... }
            let decoder = JSONDecoder()
            // Don't use .convertFromSnakeCase since MovieCard has explicit CodingKeys
            return try decoder.decode(MovieCard.self, from: data)
        }
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
