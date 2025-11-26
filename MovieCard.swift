//  MovieCard.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:45 (America/Los_Angeles - Pacific Time)
//  Notes: Movie card model for pre-built movie data from ingestion pipeline

import Foundation

// MARK: - Movie Card (Pre-built from ingestion pipeline)

struct MovieCard: Codable, Identifiable {
    let workId: Int
    let tmdbId: String
    let imdbId: String?
    let title: String
    let originalTitle: String?
    let year: Int?
    let releaseDate: String?
    let runtimeMinutes: Int?
    let runtimeDisplay: String?
    let tagline: String?
    let overview: String?
    let overviewShort: String?
    let genres: [String]?
    let poster: PosterUrls?
    let backdrop: String?
    let trailerYoutubeId: String?
    let cast: [MovieCardCastMember]?
    let director: String?
    let aiScore: Double?
    let aiScoreRange: [Double]?
    let sourceScores: SourceScores?
    let lastUpdated: String?
    
    var id: Int { workId }
    
    enum CodingKeys: String, CodingKey {
        case workId = "work_id"
        case tmdbId = "tmdb_id"
        case imdbId = "imdb_id"
        case title
        case originalTitle = "original_title"
        case year
        case releaseDate = "release_date"
        case runtimeMinutes = "runtime_minutes"
        case runtimeDisplay = "runtime_display"
        case tagline
        case overview
        case overviewShort = "overview_short"
        case genres
        case poster
        case backdrop
        case trailerYoutubeId = "trailer_youtube_id"
        case cast
        case director
        case aiScore = "ai_score"
        case aiScoreRange = "ai_score_range"
        case sourceScores = "source_scores"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Poster URLs

struct PosterUrls: Codable {
    let small: String?
    let medium: String?
    let large: String?
}

// MARK: - Cast Member (for MovieCard)

struct MovieCardCastMember: Codable, Identifiable {
    let personId: String
    let name: String
    let character: String?
    let order: Int?
    let photoUrlSmall: String?
    let photoUrlMedium: String?
    let photoUrlLarge: String?
    let gender: String?
    
    var id: String { personId }
    
    enum CodingKeys: String, CodingKey {
        case personId = "person_id"
        case name
        case character
        case order
        case photoUrlSmall = "photo_url_small"
        case photoUrlMedium = "photo_url_medium"
        case photoUrlLarge = "photo_url_large"
        case gender
    }
}

// MARK: - Source Scores

struct SourceScores: Codable {
    let tmdb: ScoreDetail?
}

// MARK: - Score Detail

struct ScoreDetail: Codable {
    let score: Double
    let votes: Int?
}

// MARK: - Movie Search Result

struct MovieSearchResult: Codable, Identifiable {
    let tmdbId: String
    let title: String
    let year: Int?
    let posterUrl: String?
    let overviewShort: String?
    let voteAverage: Double?
    let voteCount: Int?
    
    var id: String { tmdbId }
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case title
        case year
        case posterUrl = "poster_url"
        case overviewShort = "overview_short"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

// MARK: - Search Response

struct SearchResponse: Codable {
    let movies: [MovieSearchResult]
}

