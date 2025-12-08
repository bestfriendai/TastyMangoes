//  MangoCommand.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 18:12 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-06 at 22:20 (America/Los_Angeles - Pacific Time)
//  Notes: Added markWatched command - detects "mark as watched/unwatched" patterns.
//         Requires currentMovieId context (Mango invoked from MoviePageView).

import Foundation

enum MangoCommand {
    case recommenderSearch(recommender: String, movie: String, raw: String)
    case movieSearch(query: String, raw: String)
    case createWatchlist(listName: String, raw: String)
    case markWatched(watched: Bool, raw: String)
    case unknown(raw: String)
    
    var raw: String {
        switch self {
        case .recommenderSearch(_, _, let raw),
             .movieSearch(_, let raw),
             .createWatchlist(_, let raw),
             .markWatched(_, let raw),
             .unknown(let raw):
            return raw
        }
    }
    
    var recommender: String? {
        switch self {
        case .recommenderSearch(let recommender, _, _):
            return recommender
        default:
            return nil
        }
    }
    
    var movieTitle: String? {
        switch self {
        case .recommenderSearch(_, let movie, _):
            return movie
        case .movieSearch(let query, _):
            return query
        case .createWatchlist, .markWatched, .unknown:
            return nil
        }
    }
    
    var isValid: Bool {
        switch self {
        case .recommenderSearch, .movieSearch, .createWatchlist, .markWatched:
            return true
        case .unknown:
            return false
        }
    }
}

final class MangoCommandParser {
    static let shared = MangoCommandParser()
    
    private init() {}

    func parse(_ text: String) -> MangoCommand {
        // Check for create watchlist command first (before other patterns)
        if let listName = extractWatchlistName(from: text) {
            return .createWatchlist(listName: listName, raw: text)
        }
        
        // Check for mark watched/unwatched command
        if let watched = extractWatchedStatus(from: text) {
            return .markWatched(watched: watched, raw: text)
        }
        
        // COMMON PATTERNS
        // "<name> recommends <movie>"
        // "<name> suggested <movie>"
        // "<name> said to watch <movie>"
        // "<name> likes/liked <movie>"
        // "The New York Times recommends <movie>"
        // "add <movie> to my watchlist"
        
        var recommender: String?
        var movieTitle: String?
        
        // Enhanced recommender extraction - handles:
        // - Simple names: "Sally recommends"
        // - Multi-word names: "The New York Times recommends"
        // - Patterns: "recommends", "suggested", "said to watch", "likes", "liked"
        // - Reverse order: "Movie recommended by Name"
        
        let recommenderPatterns = [
            (pattern: #"^(.+?)\s+recommends\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+recommend\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2), // Singular "recommend"
            (pattern: #"^(.+?)\s+suggested\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+said\s+to\s+watch\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+likes\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+liked\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            // Reverse order: "Movie recommended by Name"
            (pattern: #"^(.+?)\s+recommended\s+by\s+(.+)$"#, recommenderIndex: 2, movieIndex: 1)
        ]
        
        var recommenderPatternMatched = false
        for (pattern, recommenderIdx, movieIdx) in recommenderPatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                if let recommenderRange = Range(match.range(at: recommenderIdx), in: text),
                   let movieRange = Range(match.range(at: movieIdx), in: text) {
                    let rawRecommender = String(text[recommenderRange]).trimmingCharacters(in: .whitespaces)
                    // Normalize recommender name (e.g., "Kyo" -> "Keo", "hyatt" -> "Hayat")
                    recommender = RecommenderNormalizer.normalize(rawRecommender)
                    let extractedMovie = String(text[movieRange]).trimmingCharacters(in: .whitespaces)
                    
                    // Even if recommender is nil (unknown name), still extract movie title
                    // This handles cases like "Trying to recommend the movie China syndrome"
                    // where speech recognition misheard the recommender name
                    if !extractedMovie.isEmpty {
                        movieTitle = extractedMovie
                        recommenderPatternMatched = true
                    }
                    break
                }
            }
        }
        
        // If recommender pattern matched but recommender is nil, try to extract movie from "recommend/recommends [the movie] X" pattern
        if recommenderPatternMatched && recommender == nil && movieTitle != nil {
            // Try to extract just the movie title from patterns like:
            // "recommend the movie X" -> "X"
            // "recommends the movie X" -> "X"
            // "recommend X" -> "X"
            let recommendMoviePatterns = [
                #"recommends?\s+(?:the\s+)?movie\s+(.+)$"#,
                #"recommends?\s+(.+)$"#
            ]
            
            for pattern in recommendMoviePatterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                    if let movieRange = Range(match.range(at: 1), in: text) {
                        let extracted = String(text[movieRange]).trimmingCharacters(in: .whitespaces)
                        if !extracted.isEmpty {
                            movieTitle = extracted
                            print("🍋 [MangoCommand] Extracted movie title from recommend pattern (no valid recommender): '\(extracted)'")
                            break
                        }
                    }
                }
            }
        }
        
        // Clean up "the movie" prefix from movieTitle if it was extracted from a recommender pattern
        if recommenderPatternMatched, let movie = movieTitle {
            // Remove "the movie" or "movie" prefix if present
            let cleaned = movie.replacingOccurrences(
                of: #"^(the\s+)?movie\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            if !cleaned.isEmpty && cleaned != movie {
                movieTitle = cleaned.trimmingCharacters(in: .whitespaces)
                print("🍋 [MangoCommand] Cleaned 'the movie' prefix: '\(movie)' -> '\(movieTitle ?? "")'")
            }
        }
        
        // If no recommender pattern matched, try search command patterns
        if movieTitle == nil {
            let searchPatterns = [
                #"^find\s+(.+)$"#,
                #"^search\s+for\s+(.+)$"#,
                #"^look\s+up\s+(.+)$"#
            ]
            
            for pattern in searchPatterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                    if let movieRange = Range(match.range(at: 1), in: text) {
                        movieTitle = String(text[movieRange]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // Try "recommend/recommends the movie X" patterns (when no recommender was found)
        // This handles cases like "Trying to recommend the movie China syndrome"
        // where speech recognition misheard the recommender name
        if movieTitle == nil || (recommenderPatternMatched && recommender == nil) {
            let recommendMoviePatterns = [
                #".*?\s+recommends?\s+(?:the\s+)?movie\s+(.+)$"#, // "X recommends (the) movie Y"
                #".*?\s+recommends?\s+(.+)$"# // "X recommends Y" (fallback)
            ]
            
            for pattern in recommendMoviePatterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                    if let movieRange = Range(match.range(at: 1), in: text) {
                        let extracted = String(text[movieRange]).trimmingCharacters(in: .whitespaces)
                        if !extracted.isEmpty {
                            movieTitle = extracted
                            print("🍋 [MangoCommand] Extracted movie from recommend pattern: '\(extracted)'")
                            break
                        }
                    }
                }
            }
        }
        
        // Try "the movie X" or "movie X" patterns
        if movieTitle == nil {
            let moviePrefixPatterns = [
                #"^the\s+movie\s+(.+)$"#,
                #"^movie\s+(.+)$"#
            ]
            
            for pattern in moviePrefixPatterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                    if let movieRange = Range(match.range(at: 1), in: text) {
                        movieTitle = String(text[movieRange]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // Fallback: if no pattern matched, try simple "add" pattern
        if movieTitle == nil {
            if let range = text.range(of: "add", options: .caseInsensitive) {
                movieTitle = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Cleanup trailing filler words (only after extraction, don't strip legitimate title words)
        movieTitle = movieTitle?.replacingOccurrences(of: "to my watchlist", with: "", options: .caseInsensitive)
        movieTitle = movieTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return appropriate command type
        if let recommender = recommender, let movie = movieTitle, !movie.isEmpty {
            return .recommenderSearch(recommender: recommender, movie: movie, raw: text)
        } else if let movie = movieTitle, !movie.isEmpty {
            return .movieSearch(query: movie, raw: text)
        } else {
            // Bare movie title fallback: if utterance is 1-8 words and doesn't start with command words
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = trimmedText.split(separator: " ").map { String($0) }
            let wordCount = words.count
            
            // Command words that should NOT trigger bare title fallback
            let commandWords = ["create", "sort", "delete", "remove", "move", "add", "find", "search", "look", "mark", "watched", "unwatched"]
            let firstWord = words.first?.lowercased() ?? ""
            
            // If 1-8 words, doesn't start with command word, treat as movie search
            if wordCount >= 1 && wordCount <= 8 && !commandWords.contains(firstWord) {
                return .movieSearch(query: trimmedText, raw: text)
            }
            
            // No pattern matched - return unknown for LLM fallback
            return .unknown(raw: text)
        }
    }
    
    /// Extract watched status from mark watched/unwatched commands
    /// Returns true for "watched", false for "unwatched", nil if not a watched command
    private func extractWatchedStatus(from text: String) -> Bool? {
        let lower = text.lowercased()
        
        // Patterns for marking as WATCHED (returns true)
        let watchedPatterns = [
            "mark as watched",
            "mark this as watched",
            "mark it as watched",
            // Speech recognition mishearings: "as" → "has"
            "mark has watched",
            "marked has watched",
            "mark it has watched",
            "i watched this",
            "i've watched this",
            "already watched",
            "already seen this",
            "i've seen this",
            "i saw this",
            "seen it",
            "watched it",
            "mark watched"
        ]
        
        for pattern in watchedPatterns {
            if lower.contains(pattern) {
                return true
            }
        }
        
        // Patterns for marking as UNWATCHED (returns false)
        let unwatchedPatterns = [
            "mark as unwatched",
            "mark this as unwatched",
            "mark it as unwatched",
            "haven't watched",
            "havent watched",
            "not watched",
            "didn't watch",
            "didnt watch",
            "i did not watch this",
            "i did not watch this movie",
            "i didn't watch this",
            "i didn't watch this movie",
            "did not watch this",
            "didn't watch this",
            "haven't seen",
            "havent seen",
            "not seen",
            "mark unwatched",
            "unwatch"
        ]
        
        for pattern in unwatchedPatterns {
            if lower.contains(pattern) {
                return false
            }
        }
        
        return nil
    }
    
    /// Extract watchlist name from create list commands
    /// Supports patterns like:
    /// - "create a new list called X"
    /// - "create a list called X"
    /// - "make a new list called X"
    /// - "make a list called X"
    /// - "new list called X"
    /// - "create a new watchlist called X"
    /// - "make a list named X"
    private func extractWatchlistName(from text: String) -> String? {
        let lower = text.lowercased()
        
        // Patterns to match (in order of specificity)
        let patterns = [
            "create a new list called",
            "create a new watchlist called",
            "create a list called",
            "make a new list called",
            "make a list called",
            "new list called",
            "create a new list named",
            "create a list named",
            "make a new list named",
            "make a list named",
            "new list named"
        ]
        
        for pattern in patterns {
            if let range = lower.range(of: pattern) {
                // Extract everything after the pattern
                let afterPattern = String(text[range.upperBound...])
                let trimmed = afterPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove trailing punctuation
                let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
                
                // Return if we have a non-empty name
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }
        
        return nil
    }
}
