//  MovieCard+Extensions.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 21:15 (America/Los_Angeles - Pacific Time)
//  Notes: Extension to convert MovieCard to MovieDetail for compatibility

import Foundation

extension MovieCard {
    /// Converts MovieCard to MovieDetail for use with existing views
    func toMovieDetail() -> MovieDetail {
        // Convert genres from [String] to [Genre]
        let genreObjects = (genres ?? []).enumerated().map { index, name in
            Genre(id: index, name: name)
        }
        
        // Convert cast from MovieCardCastMember to CastMember
        // Note: profilePath in CastMember expects TMDB path format, but we have full URLs
        // We'll use the full URL directly - MovieDetail will handle it
        let castMembers = (cast ?? []).map { cardCast in
            CastMember(
                id: Int(cardCast.personId) ?? 0,
                name: cardCast.name,
                character: cardCast.character ?? "",
                profilePath: cardCast.photoUrlMedium, // Use full URL - MovieDetail handles both formats
                order: cardCast.order
            )
        }
        
        // Convert crew (we only have director in MovieCard, so create minimal crew)
        var crewMembers: [CrewMember] = []
        if let directorName = director {
            crewMembers.append(CrewMember(
                id: 0,
                name: directorName,
                job: "Director",
                department: "Directing",
                profilePath: nil
            ))
        }
        
        // Parse release date
        let releaseDateString = releaseDate ?? ""
        
        // Use runtimeMinutes if available, otherwise parse from runtimeDisplay
        let runtimeValue = runtimeMinutes ?? parseRuntimeFromDisplay(runtimeDisplay)
        
        // Process certification - filter out empty strings and whitespace-only strings
        let processedRating: String? = {
            guard let cert = certification, !cert.isEmpty else {
                print("⚠️ [MovieCard] No certification found (nil or empty)")
                return nil
            }
            let trimmed = cert.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                print("⚠️ [MovieCard] Certification is whitespace-only")
                return nil
            }
            print("✅ [MovieCard] Certification: '\(trimmed)'")
            return trimmed
        }()
        
        return MovieDetail(
            id: workId,
            title: title,
            originalTitle: originalTitle,
            overview: overview ?? "",
            releaseDate: releaseDateString,
            posterPath: poster?.medium,
            backdropPath: backdrop,
            runtime: runtimeValue,
            genres: genreObjects,
            director: director,
            rating: processedRating, // MPAA rating (R, PG-13, etc.)
            tastyScore: nil, // Not in MovieCard
            aiScore: aiScore,
            criticsScore: nil, // Not in MovieCard
            audienceScore: nil, // Not in MovieCard
            trailerURL: trailerYoutubeId != nil ? "https://www.youtube.com/watch?v=\(trailerYoutubeId!)" : nil,
            trailerYoutubeId: trailerYoutubeId, // Store raw ID for URL construction
            trailerDuration: nil,
            cast: castMembers.isEmpty ? nil : castMembers,
            crew: crewMembers.isEmpty ? nil : crewMembers,
            budget: nil,
            revenue: nil,
            tagline: tagline,
            status: "Released",
            voteAverage: aiScore,
            voteCount: sourceScores?.tmdb?.votes,
            popularity: nil
        )
    }
    
    /// Parses runtime display string (e.g., "2h 12m") to minutes
    private func parseRuntimeFromDisplay(_ display: String?) -> Int? {
        guard let display = display else { return nil }
        
        var totalMinutes = 0
        
        // Match hours: "2h" or "2 h"
        if let hourMatch = display.range(of: #"(\d+)\s*h"#, options: .regularExpression) {
            let hourString = String(display[hourMatch])
            if let hours = Int(hourString.replacingOccurrences(of: "h", with: "").trimmingCharacters(in: .whitespaces)) {
                totalMinutes += hours * 60
            }
        }
        
        // Match minutes: "12m" or "12 m"
        if let minuteMatch = display.range(of: #"(\d+)\s*m"#, options: .regularExpression) {
            let minuteString = String(display[minuteMatch])
            if let minutes = Int(minuteString.replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces)) {
                totalMinutes += minutes
            }
        }
        
        return totalMinutes > 0 ? totalMinutes : nil
    }
}

