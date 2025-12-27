//  SearchRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:45 (America/Los_Angeles - Pacific Time)
//  Notes: Routes queries to direct search (search-movies) or semantic search (semantic-search) based on query analysis

import Foundation

enum SearchType {
    case direct      // Title lookup - use search-movies
    case semantic    // Natural language - use semantic-search
}

struct SearchRouter {
    static func route(_ query: String) -> SearchType {
        let lowercased = query.lowercased()
        let words = query.split(separator: " ")
        let wordCount = words.count
        
        print("🔍 [SearchRouter] Routing query: '\(query)' (wordCount: \(wordCount))")
        
        // 1. Check for clear semantic indicators
        let semanticIndicators = ["movies like", "films like", "similar to", "movies about", "films about", "movies with", "films with"]
        for indicator in semanticIndicators {
            if lowercased.contains(indicator) {
                print("🔍 [SearchRouter] Matched semantic indicator: '\(indicator)' → semantic")
                return .semantic
            }
        }
        
        // 2. Check for direct indicators
        let directIndicators = ["the movie", "called"]
        for indicator in directIndicators {
            if lowercased.contains(indicator) {
                print("🔍 [SearchRouter] Matched direct indicator: '\(indicator)' → direct")
                return .direct
            }
        }
        
        // 3. Word count: 1-4 words → direct, 5+ → semantic
        if wordCount <= 4 {
            print("🔍 [SearchRouter] \(wordCount) words (≤4) → direct")
            return .direct
        } else {
            print("🔍 [SearchRouter] \(wordCount) words (>4) → semantic")
            return .semantic
        }
    }
}

