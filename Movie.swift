//
//  Movie.swift
//  TastyMangoes
//
//  Created by Claude on 11/13/25 at 7:21 PM
//

import Foundation

// MARK: - Movie Model

struct Movie: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let year: Int
    let trailerURL: String?
    let trailerDuration: String?
    let posterImageURL: String?
    let tastyScore: Double?
    let aiScore: Double?
    let voteAverage: Double? // TMDB score (0-10 scale) - used when aiScore is nil
    let genres: [String]
    let rating: String?
    let director: String?
    let writer: String?
    let screenplay: String?
    let composer: String?
    let runtime: String?
    let releaseDate: String?
    let language: String?
    let overview: String?
    
    // Coding Keys for JSON mapping
    enum CodingKeys: String, CodingKey {
        case id, title, year, genres, rating, director, writer, screenplay, composer, runtime, language, overview
        case trailerURL
        case trailerDuration
        case posterImageURL
        case tastyScore
        case aiScore
        case voteAverage
        case releaseDate
    }
}

// MARK: - Computed Properties

extension Movie {
    var posterURL: URL? {
        guard let posterImageURL = posterImageURL else { return nil }
        return URL(string: posterImageURL)
    }
    
    var releaseYear: String {
        String(year)
    }
    
    var genresList: String {
        genres.joined(separator: ", ")
    }
    
    var formattedTastyScore: String {
        guard let tastyScore = tastyScore else { return "N/A" }
        return String(format: "%.0f", tastyScore)
    }
    
    var formattedAiScore: String {
        guard let aiScore = aiScore else { return "N/A" }
        return String(format: "%.1f", aiScore)
    }
    
    /// Extracts YouTube ID from a YouTube URL
    static func extractYouTubeId(from urlString: String?) -> String? {
        guard let urlString = urlString else { return nil }
        // Handle formats like: https://www.youtube.com/watch?v=VIDEO_ID
        if let range = urlString.range(of: "watch?v=") {
            let idStart = urlString.index(range.upperBound, offsetBy: 0)
            let id = String(urlString[idStart...])
            // Remove any query parameters after the ID
            if let ampersandIndex = id.firstIndex(of: "&") {
                return String(id[..<ampersandIndex])
            }
            return id
        }
        // Handle short format: https://youtu.be/VIDEO_ID
        if let range = urlString.range(of: "youtu.be/") {
            let idStart = urlString.index(range.upperBound, offsetBy: 0)
            let id = String(urlString[idStart...])
            if let questionIndex = id.firstIndex(of: "?") {
                return String(id[..<questionIndex])
            }
            return id
        }
        return nil
    }
}

// MARK: - Conversion to MovieDetail

extension Movie {
    func toMovieDetail() -> MovieDetail {
        let runtimeMinutes = parseRuntimeToMinutes(runtime ?? "")
        let genreObjects = createGenreObjects(from: genres)
        
        return MovieDetail(
            id: abs(self.hashValue),
            title: title,
            originalTitle: title,
            overview: overview ?? "",
            releaseDate: releaseDate ?? "",
            posterPath: posterImageURL,
            backdropPath: nil,
            runtime: runtimeMinutes,
            genres: genreObjects,
            director: director,
            rating: rating,
            tastyScore: tastyScore,
            aiScore: aiScore,
            criticsScore: nil,
            audienceScore: nil,
            trailerURL: trailerURL,
            trailerYoutubeId: Movie.extractYouTubeId(from: trailerURL), // Extract ID from URL if present
            trailerDuration: nil,
            cast: nil,
            crew: nil,
            budget: nil,
            revenue: nil,
            tagline: nil,
            status: "Released",
            voteAverage: aiScore,
            voteCount: nil,
            popularity: nil,
            streaming: nil
        )
    }
    
    private func parseRuntimeToMinutes(_ runtime: String) -> Int? {
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
    
    private func createGenreObjects(from genreNames: [String]) -> [Genre] {
        return genreNames.enumerated().map { index, name in
            Genre(id: index, name: name)
        }
    }
}

// MARK: - Mock Data for Previews

extension Movie {
    static func mock() -> Movie {
        return Movie(
            id: "inception",
            title: "Inception",
            year: 2010,
            trailerURL: "https://example.com/trailer/inception",
            trailerDuration: "2:24",
            posterImageURL: nil,
            tastyScore: 93.0,
            aiScore: 8.9,
            voteAverage: nil,
            genres: ["Sci-Fi", "Thriller"],
            rating: "PG-13",
            director: "Christopher Nolan",
            writer: nil,
            screenplay: nil,
            composer: nil,
            runtime: "2h 28m",
            releaseDate: "July 16, 2010",
            language: "English",
            overview: "A thief who steals secrets through dreams is given a chance to plant an idea instead."
        )
    }
    
    static func mockList() -> [Movie] {
        return [
            Movie(
                id: "inception",
                title: "Inception",
                year: 2010,
                trailerURL: nil,
                trailerDuration: "2:24",
                posterImageURL: nil,
                tastyScore: 93.0,
                aiScore: 8.9,
                voteAverage: nil,
                genres: ["Sci-Fi", "Thriller"],
                rating: "PG-13",
                director: "Christopher Nolan",
                writer: nil,
                screenplay: nil,
                composer: nil,
                runtime: "2h 28m",
                releaseDate: "July 16, 2010",
                language: "English",
                overview: "A thief who steals secrets through dreams is given a chance to plant an idea instead."
            ),
            Movie(
                id: "parasite",
                title: "Parasite",
                year: 2019,
                trailerURL: nil,
                trailerDuration: "2:11",
                posterImageURL: nil,
                tastyScore: 96.0,
                aiScore: 9.2,
                voteAverage: nil,
                genres: ["Thriller", "Drama"],
                rating: "R",
                director: "Bong Joon-ho",
                writer: nil,
                screenplay: nil,
                composer: nil,
                runtime: "2h 12m",
                releaseDate: "May 30, 2019",
                language: "Korean",
                overview: "A poor family schemes to enter the lives of a wealthy household."
            ),
            Movie(
                id: "barbie",
                title: "Barbie",
                year: 2023,
                trailerURL: nil,
                trailerDuration: "2:30",
                posterImageURL: nil,
                tastyScore: 88.0,
                aiScore: 7.4,
                voteAverage: nil,
                genres: ["Comedy", "Fantasy"],
                rating: "PG-13",
                director: "Greta Gerwig",
                writer: nil,
                screenplay: nil,
                composer: nil,
                runtime: "1h 54m",
                releaseDate: "July 21, 2023",
                language: "English",
                overview: "Barbie suffers a crisis that leads her to question her world."
            )
        ]
    }
}
