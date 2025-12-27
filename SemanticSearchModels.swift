//  SemanticSearchModels.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Data models for semantic search API integration

import Foundation

// MARK: - Request

struct SemanticSearchRequest: Codable {
    let query: String
    let sessionId: String?
    let sessionContext: SessionContext?
    let limit: Int?
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case query
        case sessionId = "session_id"
        case sessionContext = "session_context"
        case limit
        case userId = "user_id"
    }
}

struct SessionContext: Codable {
    var queries: [QueryHistoryItem]
    var shownMovieIds: [Int]
    var preferences: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case queries
        case shownMovieIds = "shown_movie_ids"
        case preferences
    }
    
    init() {
        self.queries = []
        self.shownMovieIds = []
        self.preferences = [:]
    }
}

struct QueryHistoryItem: Codable {
    let text: String
    let timestamp: String
    
    init(text: String) {
        self.text = text
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Response

struct SemanticSearchResponse: Codable {
    let mangoVoice: MangoVoice
    let movies: [SemanticMovie]
    let refinementChips: [String]
    let sessionUpdate: SessionUpdate
    let meta: SearchMeta
    
    enum CodingKeys: String, CodingKey {
        case mangoVoice = "mango_voice"
        case movies
        case refinementChips = "refinement_chips"
        case sessionUpdate = "session_update"
        case meta
    }
}

struct MangoVoice: Codable {
    let text: String
}

struct SemanticMovie: Codable, Identifiable {
    let status: MovieStatus
    let card: MovieCard?
    let preview: MoviePreview?
    let mangoReason: String
    let matchStrength: MatchStrength
    let tags: [String]
    
    var id: String {
        card?.tmdbId ?? preview?.tmdbId?.description ?? UUID().uuidString
    }
    
    var displayTitle: String {
        card?.title ?? preview?.title ?? "Unknown"
    }
    
    var displayYear: Int? {
        card?.year ?? preview?.year
    }
    
    enum CodingKeys: String, CodingKey {
        case status, card, preview, tags
        case mangoReason = "mango_reason"
        case matchStrength = "match_strength"
    }
}

enum MovieStatus: String, Codable {
    case ready
    case loading
}

enum MatchStrength: String, Codable {
    case strong
    case good
    case worthConsidering = "worth_considering"
}

struct MoviePreview: Codable {
    let title: String
    let year: Int?
    let tmdbId: Int?
    let posterPath: String?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case title, year
        case tmdbId = "tmdb_id"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
    }
}

struct SessionUpdate: Codable {
    let addToShown: [Int]
    let detectedPreferences: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case addToShown = "add_to_shown"
        case detectedPreferences = "detected_preferences"
    }
}

struct SearchMeta: Codable {
    let query: String
    let interpretation: String
    let totalRecommended: Int
    let availableNow: Int
    let loading: Int
    let confidence: String
    let openaiTimeMs: Int?
    let totalTimeMs: Int?
    
    enum CodingKeys: String, CodingKey {
        case query, interpretation, confidence
        case totalRecommended = "total_recommended"
        case availableNow = "available_now"
        case loading
        case openaiTimeMs = "openai_time_ms"
        case totalTimeMs = "total_time_ms"
    }
}

