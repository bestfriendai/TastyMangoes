//  SearchIntentClassifier.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-15 at 08:45 (America/Los_Angeles - Pacific Time) / 16:45 UTC
//  Notes: Phase 2 - Classifies voice utterances into search intent categories
//         (direct, fuzzy, action_only, import) for analytics tracking.

import Foundation

/// Search intent categories for voice utterances
enum VoiceSearchIntent: String, Codable {
    case direct = "direct"           // User knows the movie title
    case fuzzy = "fuzzy"             // User describes a movie they can't name
    case importResult = "import"     // User is importing from external AI
    case actionOnly = "action_only"  // Command like "mark watched", no search needed
}

/// Classifies voice utterances into search intent categories
enum SearchIntentClassifier {
    
    // MARK: - Fuzzy Search Indicators
    
    /// Phrases that indicate the user is describing a movie they can't name
    private static let fuzzyPhrases: [String] = [
        "can't remember",
        "cant remember",
        "don't remember",
        "dont remember",
        "forgot the name",
        "forget the name",
        "what's that movie",
        "whats that movie",
        "what is that movie",
        "the one where",
        "the one with",
        "the movie where",
        "the movie with",
        "the film where",
        "the film with",
        "it's about",
        "its about",
        "something about",
        "a movie about",
        "a film about",
        "i think it's called",
        "i think its called",
        "might be called",
        "do you know the movie",
        "help me find",
        "trying to find",
        "looking for a movie"
    ]
    
    /// Words that suggest plot description (high density = fuzzy)
    private static let plotDescriptorWords: Set<String> = [
        "stranded", "trapped", "discovers", "finds", "escapes", "fights",
        "falls", "meets", "travels", "journey", "quest", "searches",
        "haunted", "possessed", "cursed", "infected", "transforms",
        "betrayed", "revenge", "kidnapped", "lost", "hidden", "secret",
        "alien", "monster", "killer", "ghost", "zombie", "vampire",
        "robot", "spaceship", "island", "jungle", "desert", "ocean",
        "war", "heist", "robbery", "murder", "mystery", "conspiracy"
    ]
    
    // MARK: - Action Indicators
    
    /// Phrases that indicate action-only commands (no search)
    private static let actionPhrases: [String] = [
        "mark as watched",
        "mark watched",
        "mark as unwatched",
        "mark unwatched",
        "i watched",
        "i've watched",
        "ive watched",
        "add to",
        "add this to",
        "add this movie to",
        "remove from",
        "create list",
        "create a list",
        "new list",
        "make a list",
        "sort by",
        "sort this"
    ]
    
    // MARK: - Import Indicators
    
    /// Phrases that indicate importing from external source
    private static let importPhrases: [String] = [
        "paste",
        "import",
        "from chatgpt",
        "from gpt",
        "copied",
        "clipboard"
    ]
    
    // MARK: - Direct Search Indicators
    
    /// Phrases that indicate explicit direct search
    private static let directSearchPhrases: [String] = [
        "find",
        "search for",
        "search",
        "look up",
        "the movie",
        "the film",
        "show me"
    ]
    
    // MARK: - Classification
    
    /// Classify an utterance into a search intent category
    static func classify(_ utterance: String) -> VoiceSearchIntent {
        let lower = utterance.lowercased()
        
        // Check for action commands first (highest priority)
        for phrase in actionPhrases {
            if lower.contains(phrase) {
                return .actionOnly
            }
        }
        
        // Check for import indicators
        for phrase in importPhrases {
            if lower.contains(phrase) {
                return .importResult
            }
        }
        
        // Check for explicit fuzzy indicators
        for phrase in fuzzyPhrases {
            if lower.contains(phrase) {
                return .fuzzy
            }
        }
        
        // Check plot descriptor density
        let words = Set(lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty })
        
        let plotWordCount = words.intersection(plotDescriptorWords).count
        let wordCount = words.count
        
        // If >20% of words are plot descriptors and utterance is long, likely fuzzy
        if wordCount > 5 && Double(plotWordCount) / Double(wordCount) > 0.2 {
            return .fuzzy
        }
        
        // Long utterances (>12 words) without clear title patterns are likely fuzzy
        if wordCount > 12 && !hasLikelyTitlePattern(lower) {
            return .fuzzy
        }
        
        // Default to direct search
        return .direct
    }
    
    /// Check if utterance has patterns suggesting a title is present
    private static func hasLikelyTitlePattern(_ lower: String) -> Bool {
        // Short utterances (1-5 words) are likely titles
        let wordCount = lower.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        if wordCount <= 5 {
            return true
        }
        
        // Check for direct search phrases followed by likely title
        for phrase in directSearchPhrases {
            if lower.contains(phrase) {
                return true
            }
        }
        
        // Check for year pattern (suggests specific movie)
        let yearPattern = try? NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b")
        if let range = yearPattern?.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            return range.range.length > 0
        }
        
        // Check for "with [Actor]" pattern
        if lower.contains(" with ") {
            return true
        }
        
        // Check for recommender pattern
        if lower.contains(" recommends ") || lower.contains(" recommended by ") {
            return true
        }
        
        return false
    }
    
    // MARK: - Confidence Estimation
    
    /// Estimate confidence in the classification (0.0 - 1.0)
    static func estimateConfidence(utterance: String, intent: VoiceSearchIntent) -> Double {
        let lower = utterance.lowercased()
        let wordCount = lower.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        
        switch intent {
        case .actionOnly:
            // High confidence if action phrase is clear
            for phrase in actionPhrases {
                if lower.contains(phrase) {
                    return 0.95
                }
            }
            return 0.70
            
        case .importResult:
            // High confidence if import phrase is clear
            for phrase in importPhrases {
                if lower.contains(phrase) {
                    return 0.90
                }
            }
            return 0.70
            
        case .fuzzy:
            // Confidence based on how many fuzzy indicators present
            var indicators = 0
            for phrase in fuzzyPhrases {
                if lower.contains(phrase) {
                    indicators += 1
                }
            }
            
            // Also count plot descriptors
            let words = Set(lower.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) })
            let plotWordCount = words.intersection(plotDescriptorWords).count
            
            if indicators >= 2 {
                return 0.90
            } else if indicators == 1 && plotWordCount >= 2 {
                return 0.85
            } else if indicators == 1 {
                return 0.75
            } else if plotWordCount >= 3 {
                return 0.70
            } else if wordCount > 12 {
                return 0.60 // Long but no clear indicators
            }
            return 0.50
            
        case .direct:
            // Confidence based on how "title-like" the utterance is
            if wordCount <= 3 {
                return 0.90 // Very short = likely a title
            } else if wordCount <= 5 {
                return 0.85
            } else if hasLikelyTitlePattern(lower) {
                return 0.80
            } else {
                return 0.65 // Could be direct but not certain
            }
        }
    }
}
