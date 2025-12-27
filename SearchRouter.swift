//  SearchRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:45 (America/Los_Angeles - Pacific Time)
//  Notes: Routes queries to direct search (search-movies) or semantic search (semantic-search) based on query analysis

import Foundation

enum SearchType {
    case direct      // Title lookup - use search-movies
    case semantic    // Natural language - use semantic-search
}

class SearchRouter {
    static let shared = SearchRouter()
    
    // Words that indicate semantic/natural language search
    private let semanticIndicators: Set<String> = [
        // Plural forms
        "movies", "films",
        // Similarity
        "like", "similar", "remind",
        // Audience
        "for kids", "for family", "for children", "family-friendly",
        "for date", "date night", "romantic",
        // Requests
        "recommend", "suggest", "find me", "show me", "give me",
        "looking for", "want to watch", "in the mood",
        // Superlatives
        "best", "top", "greatest", "favorite", "popular",
        // Genres with modifiers
        "funny", "scary", "sad", "happy", "feel-good", "feel good",
        "heartwarming", "thrilling", "exciting", "relaxing",
        // Time-based
        "classic", "recent", "new", "old", "80s", "90s", "2000s",
        // Questions
        "what should", "what can", "any good",
        // Based on
        "based on", "adapted from", "from the book"
    ]
    
    // Words/patterns that indicate direct title search
    private let directIndicators: Set<String> = [
        "the movie", "the film", "called", "named", "titled"
    ]
    
    func route(query: String) -> SearchType {
        let lowercased = query.lowercased().trimmingCharacters(in: .whitespaces)
        let words = lowercased.split(separator: " ")
        let wordCount = words.count
        
        // Debug logging
        print("🔍 [SearchRouter] Routing query: '\(query)' (wordCount: \(wordCount))")
        
        // Step 1: Check for semantic indicators first (these override everything)
        // This catches queries like "movies like", "for kids", "best action", etc.
        for indicator in semanticIndicators {
            if lowercased.contains(indicator) {
                print("🔍 [SearchRouter] Matched semantic indicator: '\(indicator)' → semantic")
                return .semantic
            }
        }
        
        // Step 2: Check for direct indicators (e.g., "the movie Arrived")
        for indicator in directIndicators {
            if lowercased.contains(indicator) {
                print("🔍 [SearchRouter] Matched direct indicator: '\(indicator)' → direct")
                return .direct
            }
        }
        
        // Step 3: Very short queries (1-2 words) are likely title searches
        // Examples: "Arrival", "Mulholland Drive", "The Matrix"
        if wordCount <= 2 {
            print("🔍 [SearchRouter] 1-2 word query → direct")
            return .direct
        }
        
        // Step 4: 4-word queries with no semantic indicators are likely movie titles
        // Examples: "Back to the future", "The Lord of the Rings" (if we had 4-word version)
        // Speech recognition returns lowercase, so we can't rely on Title Case
        if wordCount == 4 {
            return .direct
        }
        
        // Step 5: 3-word queries - check if it looks like a title (Title Case in typed queries)
        // For speech transcripts (lowercase), this won't match, but typed queries might
        if wordCount == 3 {
            if looksLikeTitle(query) {
                return .direct
            }
            // Default 3-word queries to semantic (unless they matched Title Case above)
            return .semantic
        }
        
        // Step 6: 5+ word queries default to semantic (likely natural language)
        return .semantic
    }
    
    private func looksLikeTitle(_ query: String) -> Bool {
        // Check if query appears to be a movie title
        // - Contains colons (subtitle pattern like "Movie: Subtitle")
        // - Contains numbers (sequel indicators like "2", "II", "Part 2")
        // - Title Case pattern (capitalized words like "Back to the Future")
        // - Common title words that suggest it's a title, not a query
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        
        // Check for subtitle pattern
        if trimmed.contains(":") { return true }
        
        // Check for numbers (sequels, years, etc.)
        if trimmed.range(of: "\\d", options: .regularExpression) != nil { return true }
        
        // Check for Title Case pattern (multiple capitalized words)
        // "Back to the Future" has capitalized words: "Back", "Future"
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            let capitalizedWords = words.filter { word in
                // Check if word starts with capital letter
                if let firstChar = word.first, firstChar.isUppercase {
                    return true
                }
                return false
            }
            // If 2+ words are capitalized, likely a title
            if capitalizedWords.count >= 2 {
                return true
            }
        }
        
        // Single word that's capitalized (likely a title)
        if trimmed.first?.isUppercase == true && !trimmed.contains(" ") {
            return true
        }
        
        return false
    }
}

