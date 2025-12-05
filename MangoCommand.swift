//  MangoCommand.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 18:12 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: Parser for TalkToMango voice commands - extracts recommender name and movie title from natural language input. Added unknown case for LLM fallback.

import Foundation

enum MangoCommand {
    case recommenderSearch(recommender: String, movie: String, raw: String)
    case movieSearch(query: String, raw: String)
    case unknown(raw: String)
    
    var raw: String {
        switch self {
        case .recommenderSearch(_, _, let raw), .movieSearch(_, let raw), .unknown(let raw):
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
        case .unknown:
            return nil
        }
    }
    
    var isValid: Bool {
        switch self {
        case .recommenderSearch, .movieSearch:
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
        let lower = text.lowercased()
        
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
}

