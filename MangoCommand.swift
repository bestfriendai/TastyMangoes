//  MangoCommand.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 18:12 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-05 at 19:26 (America/Los_Angeles - Pacific Time)
//  Notes: Added createWatchlist command parsing - detects "create a new list called X" patterns. Extracts list name and handles locally without LLM.

import Foundation

enum MangoCommand {
    case recommenderSearch(recommender: String, movie: String, raw: String)
    case movieSearch(query: String, raw: String)
    case createWatchlist(listName: String, raw: String)
    case unknown(raw: String)
    
    var raw: String {
        switch self {
        case .recommenderSearch(_, _, let raw), .movieSearch(_, let raw), .createWatchlist(_, let raw), .unknown(let raw):
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
        case .createWatchlist, .unknown:
            return nil
        }
    }
    
    var isValid: Bool {
        switch self {
        case .recommenderSearch, .movieSearch, .createWatchlist:
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
        
        let patterns = [
            (pattern: #"^(.+?)\s+recommends\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+suggested\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+said\s+to\s+watch\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+likes\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2),
            (pattern: #"^(.+?)\s+liked\s+(.+)$"#, recommenderIndex: 1, movieIndex: 2)
        ]
        
        for (pattern, recommenderIdx, movieIdx) in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                if let recommenderRange = Range(match.range(at: recommenderIdx), in: text),
                   let movieRange = Range(match.range(at: movieIdx), in: text) {
                    recommender = String(text[recommenderRange]).trimmingCharacters(in: .whitespaces)
                    movieTitle = String(text[movieRange]).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
        
        // Fallback: if no recommender pattern matched, try simple "add" pattern
        if movieTitle == nil {
            if let range = text.range(of: "add", options: .caseInsensitive) {
                movieTitle = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Cleanup trailing filler words
        movieTitle = movieTitle?.replacingOccurrences(of: "the movie", with: "", options: .caseInsensitive)
        movieTitle = movieTitle?.replacingOccurrences(of: "to my watchlist", with: "", options: .caseInsensitive)
        movieTitle = movieTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return appropriate command type
        if let recommender = recommender, let movie = movieTitle, !movie.isEmpty {
            return .recommenderSearch(recommender: recommender, movie: movie, raw: text)
        } else if let movie = movieTitle, !movie.isEmpty {
            return .movieSearch(query: movie, raw: text)
        } else {
            // No pattern matched - return unknown for LLM fallback
            return .unknown(raw: text)
        }
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

