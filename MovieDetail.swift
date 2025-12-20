//
//  MovieDetail.swift
//  TastyMangoes
//
//  Created by Claude on 11/13/25 at 7:02 PM
//

import Foundation

// MARK: - Movie Detail Model

struct MovieDetail: Codable, Identifiable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let backdropPath: String?
    let runtime: Int?
    let genres: [Genre]
    let director: String?
    let rating: String? // e.g., "PG-13", "R"
    
    // Tasty Mangoes Specific
    let tastyScore: Double?
    let aiScore: Double?
    let criticsScore: Double?
    let audienceScore: Double?
    
    // Video/Trailer
    let trailerURL: String?
    let trailerYoutubeId: String? // Raw YouTube ID (e.g., "CxwTLktovTU")
    let trailerDuration: Int? // in seconds
    
    // Cast & Crew
    let cast: [CastMember]?
    let crew: [CrewMember]?
    
    // Additional Info
    let budget: Int?
    let revenue: Int?
    let tagline: String?
    let status: String? // "Released", "Post Production", etc.
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    
    // Store original string ID if needed
    var stringId: String?
    
    // Streaming providers
    let streaming: StreamingInfo?
    
    // Computed Properties
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        // If it's already a full URL, use it
        if posterPath.starts(with: "http") {
            return URL(string: posterPath)
        }
        // Otherwise use TMDB path
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        // If it's already a full URL, use it
        if backdropPath.starts(with: "http") {
            return URL(string: backdropPath)
        }
        // Otherwise use TMDB path
        return URL(string: "https://image.tmdb.org/t/p/original\(backdropPath)")
    }
    
    var releaseYear: String {
        String(releaseDate.prefix(4))
    }
    
    var formattedRuntime: String {
        guard let runtime = runtime else { return "N/A" }
        let hours = runtime / 60
        let minutes = runtime % 60
        return "\(hours)h \(minutes)m"
    }
    
    var genresList: String {
        genres.map { $0.name }.joined(separator: ", ")
    }
    
    var formattedBudget: String {
        guard let budget = budget, budget > 0 else { return "N/A" }
        return formatCurrency(budget)
    }
    
    var formattedRevenue: String {
        guard let revenue = revenue, revenue > 0 else { return "N/A" }
        return formatCurrency(revenue)
    }
    
    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, director, rating
        case originalTitle = "original_title"
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case tastyScore = "tasty_score"
        case aiScore = "ai_score"
        case criticsScore = "critics_score"
        case audienceScore = "audience_score"
        case trailerURL = "trailer_url"
        case trailerYoutubeId = "trailer_youtube_id"
        case trailerDuration = "trailer_duration"
        case cast, crew, budget, revenue, tagline, status
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity
        case streaming
    }
}

// MARK: - Supporting Models

struct Genre: Codable, Identifiable {
    let id: Int
    let name: String
}

struct CastMember: Codable, Identifiable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int?
    
    var profileURL: URL? {
        guard let profilePath = profilePath else { return nil }
        // Handle both full URLs (from Supabase Storage) and TMDB paths
        if profilePath.starts(with: "http") {
            return URL(string: profilePath)
        }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
}

struct CrewMember: Codable, Identifiable {
    let id: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?
    
    var profileURL: URL? {
        guard let profilePath = profilePath else { return nil }
        // Handle both full URLs (from Supabase Storage) and TMDB paths
        if profilePath.starts(with: "http") {
            return URL(string: profilePath)
        }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

// MARK: - Streaming Models

struct StreamingInfo: Codable {
    let us: StreamingCountry?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case us
        case updatedAt = "updated_at"
    }
}

struct StreamingCountry: Codable {
    let link: String?
    let flatrate: [StreamingProvider]?
    let rent: [StreamingProvider]?
    let buy: [StreamingProvider]?
    let ads: [StreamingProvider]?
    let free: [StreamingProvider]?
}

struct StreamingProvider: Codable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    
    var id: Int { providerId }
    
    var logoURL: URL? {
        guard let logoPath = logoPath else { return nil }
        // TMDB logo images use base URL + w92 size
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }
    
    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
}

// MARK: - Mock Data for Previews

extension MovieDetail {
    static func mock() -> MovieDetail {
        MovieDetail(
            id: 550,
            title: "Fight Club",
            originalTitle: "Fight Club",
            overview: "A ticking-time-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy.",
            releaseDate: "1999-10-15",
            posterPath: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            backdropPath: "/hZkgoQYus5vegHoetLkCJzb17zJ.jpg",
            runtime: 139,
            genres: [
                Genre(id: 18, name: "Drama"),
                Genre(id: 53, name: "Thriller")
            ],
            director: "David Fincher",
            rating: "R",
            tastyScore: 92.5,
            aiScore: 88.0,
            criticsScore: 79.0,
            audienceScore: 96.0,
            trailerURL: "https://www.youtube.com/watch?v=SUXWAEX2jlg",
            trailerYoutubeId: "SUXWAEX2jlg",
            trailerDuration: 150,
            cast: [
                CastMember(id: 287, name: "Brad Pitt", character: "Tyler Durden", profilePath: "/cckcYc2v0yh1tc9QjRelptcOBko.jpg", order: 0),
                CastMember(id: 819, name: "Edward Norton", character: "The Narrator", profilePath: "/5XBzD5WuTyVQZeS4VI25z2moMeY.jpg", order: 1),
                CastMember(id: 1283, name: "Helena Bonham Carter", character: "Marla Singer", profilePath: "/DDeITcCpnBd0CkAIRPhggy9bt5.jpg", order: 2)
            ],
            crew: [
                CrewMember(id: 7467, name: "David Fincher", job: "Director", department: "Directing", profilePath: "/tpEczFclQZeKAiCeKZZ0adRvtfz.jpg")
            ],
            budget: 63000000,
            revenue: 100853753,
            tagline: "Mischief. Mayhem. Soap.",
            status: "Released",
            voteAverage: 8.433,
            voteCount: 28304,
            popularity: 61.416,
            streaming: nil
        )
    }
}
