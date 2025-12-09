//
//  TMDBModels.swift
//  TastyMangoes
//
//  Created by Claude on 11/13/25 at 8:00 PM
//

import Foundation

// MARK: - TMDB API Response Models

/// Response from TMDB movie search
struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// Basic movie info from TMDB (used in search results, lists)
struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }
}

/// Full movie details from TMDB
struct TMDBMovieDetail: Codable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let genres: [TMDBGenre]?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let budget: Int?
    let revenue: Int?
    let tagline: String?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, popularity, budget, revenue, tagline, status
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

/// Genre from TMDB
struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

/// Movie credits response from TMDB
struct TMDBCredits: Codable {
    let id: Int
    let cast: [TMDBCast]
    let crew: [TMDBCrew]
}

/// Cast member from TMDB
struct TMDBCast: Codable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
}

/// Crew member from TMDB
struct TMDBCrew: Codable {
    let id: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

// MARK: - Images and Videos Models

/// Images response from TMDB
struct TMDBImagesResponse: Codable {
    let id: Int
    let backdrops: [TMDBImage]
    let posters: [TMDBImage]
}

/// Image from TMDB
struct TMDBImage: Codable, Identifiable {
    let filePath: String
    let width: Int?
    let height: Int?
    let aspectRatio: Double?
    let voteAverage: Double?
    let voteCount: Int?
    
    var imageURL: URL? {
        // If filePath is already a full URL (from Supabase storage), use it directly
        if filePath.hasPrefix("http://") || filePath.hasPrefix("https://") {
            return URL(string: filePath)
        }
        // Otherwise, build TMDB URL
        return URL(string: "https://image.tmdb.org/t/p/w500\(filePath)")
    }
    
    var originalImageURL: URL? {
        // If filePath is already a full URL (from Supabase storage), use it directly
        if filePath.hasPrefix("http://") || filePath.hasPrefix("https://") {
            return URL(string: filePath)
        }
        // Otherwise, build TMDB URL
        return URL(string: "https://image.tmdb.org/t/p/original\(filePath)")
    }
    
    // Identifiable conformance - use filePath as ID
    var id: String {
        filePath
    }
    
    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case width = "width"
        case height = "height"
        case aspectRatio = "aspect_ratio"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

/// Videos response from TMDB
struct TMDBVideosResponse: Codable {
    let id: Int
    let results: [TMDBVideo]
}

/// Video from TMDB
struct TMDBVideo: Codable, Identifiable {
    let id: String
    let key: String
    let name: String
    let site: String // "YouTube", "Vimeo", etc.
    let size: Int // 360, 480, 720, 1080
    let type: String // "Trailer", "Teaser", "Clip", etc.
    let official: Bool
    let publishedAt: String
    let customThumbnailURL: String? // Optional custom thumbnail URL (e.g., from Supabase storage)
    
    var youtubeURL: URL? {
        guard site == "YouTube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
    
    var thumbnailURL: URL? {
        // Use custom thumbnail URL if available (from Supabase storage)
        if let customUrl = customThumbnailURL, let url = URL(string: customUrl) {
            return url
        }
        // Otherwise, use YouTube default thumbnail
        guard site == "YouTube" else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(key)/maxresdefault.jpg")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, key, name, site, size, type, official
        case publishedAt = "published_at"
        case customThumbnailURL = "custom_thumbnail_url"
    }
    
    // Custom initializer for creating from MovieClip
    init(id: String, key: String, name: String, site: String, size: Int, type: String, official: Bool, publishedAt: String, customThumbnailURL: String? = nil) {
        self.id = id
        self.key = key
        self.name = name
        self.site = site
        self.size = size
        self.type = type
        self.official = official
        self.publishedAt = publishedAt
        self.customThumbnailURL = customThumbnailURL
    }
}

// MARK: - Conversion to App Models

extension TMDBMovie {
    /// Convert TMDB movie to our lightweight Movie model
    func toMovie() -> Movie {
        // TMDB returns poster paths like "/abc123.jpg" or "abc123.jpg"
        // MoviePosterImage expects just the path and will build the full URL
        return Movie(
            id: String(id),
            title: title,
            year: extractYear(from: releaseDate),
            trailerURL: nil,
            trailerDuration: nil,
            posterImageURL: posterPath, // Pass path as-is, MoviePosterImage will build URL
            tastyScore: nil, // We'll calculate this later
            aiScore: voteAverage,
            genres: [], // Genre names come from a separate API call
            rating: nil,
            director: nil,
            writer: nil,
            screenplay: nil,
            composer: nil,
            runtime: nil,
            releaseDate: releaseDate,
            language: nil,
            overview: overview
        )
    }
    
    private func extractYear(from dateString: String?) -> Int {
        guard let dateString = dateString,
              let year = Int(dateString.prefix(4)) else {
            return 0
        }
        return year
    }
}

extension TMDBMovieDetail {
    /// Convert TMDB movie detail to our MovieDetail model
    func toMovieDetail(credits: TMDBCredits? = nil) -> MovieDetail {
        let director = credits?.crew.first(where: { $0.job == "Director" })?.name
        
        let castMembers = credits?.cast.prefix(20).map { tmdbCast in
            CastMember(
                id: tmdbCast.id,
                name: tmdbCast.name,
                character: tmdbCast.character,
                profilePath: tmdbCast.profilePath,
                order: tmdbCast.order
            )
        }
        
        let crewMembers = credits?.crew.prefix(20).map { tmdbCrew in
            CrewMember(
                id: tmdbCrew.id,
                name: tmdbCrew.name,
                job: tmdbCrew.job,
                department: tmdbCrew.department,
                profilePath: tmdbCrew.profilePath
            )
        }
        
        let genreObjects = genres?.map { Genre(id: $0.id, name: $0.name) } ?? []
        
        return MovieDetail(
            id: id,
            title: title,
            originalTitle: originalTitle,
            overview: overview ?? "",
            releaseDate: releaseDate ?? "",
            posterPath: posterPath,
            backdropPath: backdropPath,
            runtime: runtime,
            genres: genreObjects,
            director: director,
            rating: nil, // TMDB doesn't provide MPAA ratings in basic API
            tastyScore: nil, // We'll calculate this
            aiScore: voteAverage,
            criticsScore: nil,
            audienceScore: voteAverage, // Use TMDB score as audience score
            trailerURL: nil, // Would need separate videos API call
            trailerYoutubeId: nil, // Would need separate videos API call  
            trailerDuration: nil,
            cast: castMembers,
            crew: crewMembers,
            budget: budget,
            revenue: revenue,
            tagline: tagline,
            status: status,
            voteAverage: voteAverage,
            voteCount: voteCount,
            popularity: popularity
        )
    }
}
