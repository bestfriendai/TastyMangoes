//  MangoCommand.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 18:12 (America/Los_Angeles - Pacific Time)
//  Notes: Parser for TalkToMango voice commands - extracts recommender name and movie title from natural language input

import Foundation

struct MangoCommand {
    let raw: String
    let recommender: String?
    let movieTitle: String?
    
    var isValid: Bool {
        movieTitle != nil
    }
}

final class MangoCommandParser {
    static let shared = MangoCommandParser()
    
    private init() {}

    func parse(_ text: String) -> MangoCommand {
        let lower = text.lowercased()
        
        // COMMON PATTERNS
        // "<name> recommends <movie>"
        // "<name> liked <movie>"
        // "add <movie> to my watchlist"
        
        let recommenderRegex = try! NSRegularExpression(
            pattern: #"^([A-Z][a-z]+)\s+(recommends|likes|liked)\b"#,
            options: []
        )
        
        var recommender: String?
        var movieTitle: String?
        
        // Extract recommender
        if let match = recommenderRegex.firstMatch(
            in: text,
            options: [],
            range: NSRange(location: 0, length: text.count)
        ) {
            if let r = Range(match.range(at: 1), in: text) {
                recommender = String(text[r])
            }
        }
        
        // Movie title extraction:
        if let range = text.range(of: "recommends") {
            movieTitle = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = text.range(of: "likes") {
            movieTitle = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = text.range(of: "liked") {
            movieTitle = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = text.range(of: "add") {
            movieTitle = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Cleanup trailing filler words
        movieTitle = movieTitle?.replacingOccurrences(of: "the movie", with: "", options: .caseInsensitive)
        movieTitle = movieTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return MangoCommand(raw: text, recommender: recommender, movieTitle: movieTitle)
    }
}

