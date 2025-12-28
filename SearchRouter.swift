// SearchRouter.swift
// TastyMangoes

import Foundation

enum SearchType {
    case direct
    case semantic
}

struct SearchRouter {
    static func route(_ query: String) -> SearchType {
        let lowercased = query.lowercased()
        let words = query.split(separator: " ")
        let wordCount = words.count
        
        print("🔍 [SearchRouter] Routing query: '\(query)' (wordCount: \(wordCount))")
        
        // 1. Semantic indicators
        let semanticIndicators = [
            "movies like", "films like", "similar to",
            "movies about", "films about",
            "movies for", "films for",      // "movies for kids", "films for family"
            "for kids", "for family",       // audience indicators
            "for children", "for date",     // more audience
            "best movies", "top movies",    // superlatives
            "good movies", "great movies",  // quality indicators
            "funny movies", "scary movies"  // mood indicators
        ]
        for indicator in semanticIndicators {
            if lowercased.contains(indicator) {
                print("🔍 [SearchRouter] Matched semantic indicator: '\(indicator)' → semantic")
                return .semantic
            }
        }
        
        // 2. Direct indicators
        let directIndicators = ["the movie", "the film", "called"]
        for indicator in directIndicators {
            if lowercased.contains(indicator) {
                print("🔍 [SearchRouter] Matched direct indicator: '\(indicator)' → direct")
                return .direct
            }
        }
        
        // 3. Word count fallback
        if wordCount <= 4 {
            print("🔍 [SearchRouter] \(wordCount) words (≤4) → direct")
            return .direct
        } else {
            print("🔍 [SearchRouter] \(wordCount) words (>4) → semantic")
            return .semantic
        }
    }
}
