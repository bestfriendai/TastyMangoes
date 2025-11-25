//  SupabaseModels.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:50 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-01-15 at 16:15 (America/Los_Angeles - Pacific Time)
//  Notes: Data models for Supabase database tables - updated to match revised schema

import Foundation

// MARK: - User Profile

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let username: String
    let avatarURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - User Subscription

struct UserSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let platform: String
    let createdAt: Date
    
    init(id: UUID = UUID(), userId: UUID, platform: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.platform = platform
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case platform
        case createdAt = "created_at"
    }
}

// MARK: - Watchlist

struct Watchlist: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let thumbnailURL: String?
    let createdAt: Date
    let updatedAt: Date
    let sortOrder: Int
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        thumbnailURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case thumbnailURL = "thumbnail_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sortOrder = "sort_order"
    }
}

// MARK: - Watchlist Movie (simplified - just "want to watch")

struct WatchlistMovie: Codable, Identifiable {
    let id: UUID
    let watchlistId: UUID
    let movieId: String
    let addedAt: Date
    
    init(
        id: UUID = UUID(),
        watchlistId: UUID,
        movieId: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.watchlistId = watchlistId
        self.movieId = movieId
        self.addedAt = addedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case watchlistId = "watchlist_id"
        case movieId = "movie_id"
        case addedAt = "added_at"
    }
}

// MARK: - Watch History

struct WatchHistory: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let movieId: String
    let watchedAt: Date
    let platform: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        movieId: String,
        watchedAt: Date = Date(),
        platform: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.movieId = movieId
        self.watchedAt = watchedAt
        self.platform = platform
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case movieId = "movie_id"
        case watchedAt = "watched_at"
        case platform
        case createdAt = "created_at"
    }
}

// MARK: - User Rating

struct UserRating: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let movieId: String
    let rating: Int // 0-5 stars
    let reviewText: String?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        movieId: String,
        rating: Int,
        reviewText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.movieId = movieId
        self.rating = rating
        self.reviewText = reviewText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case movieId = "movie_id"
        case rating
        case reviewText = "review_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Database Movie (for caching)

struct DatabaseMovie: Codable {
    let id: String
    let tmdbId: Int?
    let title: String
    let year: Int?
    let posterURL: String?
    let backdropURL: String?
    let overview: String?
    let runtime: Int?
    let releaseDate: Date?
    let genres: [String]
    let rating: String?
    let director: String?
    let language: String?
    let tastyScore: Double? // Keep as-is
    let aiScore: Double? // Keep as-is
    let trailerURL: String?
    let trailerDuration: Int?
    let createdAt: Date
    let updatedAt: Date
    
    init(from movie: Movie) {
        self.id = movie.id
        self.tmdbId = Int(movie.id)
        self.title = movie.title
        self.year = movie.year
        self.posterURL = movie.posterImageURL
        self.backdropURL = nil
        self.overview = movie.overview
        self.runtime = movie.runtime.flatMap { Self.parseRuntime($0) }
        self.releaseDate = movie.releaseDate.flatMap { Self.parseDate($0) }
        self.genres = movie.genres
        self.rating = movie.rating
        self.director = movie.director
        self.language = movie.language
        self.tastyScore = movie.tastyScore
        self.aiScore = movie.aiScore
        self.trailerURL = movie.trailerURL
        self.trailerDuration = movie.trailerDuration.flatMap { Self.parseDuration($0) }
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case tmdbId = "tmdb_id"
        case title
        case year
        case posterURL = "poster_url"
        case backdropURL = "backdrop_url"
        case overview
        case runtime
        case releaseDate = "release_date"
        case genres
        case rating
        case director
        case language
        case tastyScore = "tasty_score"
        case aiScore = "ai_score"
        case trailerURL = "trailer_url"
        case trailerDuration = "trailer_duration"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    private static func parseRuntime(_ runtime: String) -> Int? {
        let components = runtime.components(separatedBy: " ")
        var totalMinutes = 0
        
        for component in components {
            if component.hasSuffix("h") {
                if let hours = Int(component.dropLast()) {
                    totalMinutes += hours * 60
                }
            } else if component.hasSuffix("m") {
                if let minutes = Int(component.dropLast()) {
                    totalMinutes += minutes
                }
            }
        }
        
        return totalMinutes > 0 ? totalMinutes : nil
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString)
    }
    
    private static func parseDuration(_ duration: String) -> Int? {
        // Parse "2:24" format to seconds
        let components = duration.components(separatedBy: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }
}

// MARK: - Auth Response

// Note: User and Session types come from Supabase Auth SDK
// Using the actual types from the Supabase Swift SDK
import Auth
typealias SupabaseUser = Auth.User
typealias SupabaseSession = Auth.Session

struct AuthResponse {
    let user: SupabaseUser
    let session: SupabaseSession?
}
