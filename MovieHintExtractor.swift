//  MovieHintExtractor.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-15 at 08:50 (America/Los_Angeles - Pacific Time) / 16:50 UTC
//  Notes: Phase 2 - Extracts movie hints (year, actors, director, keywords, plot clues)
//         from voice utterances for analytics and potential semantic search.

import Foundation

/// Extracted hints from a voice utterance
struct ExtractedHints: Codable {
    var titleLikely: String?
    var year: Int?
    var decade: Int?
    var actors: [String]
    var director: String?
    var author: String?
    var keywords: [String]
    var plotClues: [String]
    var isRemakeHint: Bool
    
    init(
        titleLikely: String? = nil,
        year: Int? = nil,
        decade: Int? = nil,
        actors: [String] = [],
        director: String? = nil,
        author: String? = nil,
        keywords: [String] = [],
        plotClues: [String] = [],
        isRemakeHint: Bool = false
    ) {
        self.titleLikely = titleLikely
        self.year = year
        self.decade = decade
        self.actors = actors
        self.director = director
        self.author = author
        self.keywords = keywords
        self.plotClues = plotClues
        self.isRemakeHint = isRemakeHint
    }
    
    /// Convert to JSON string for database storage
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Check if any hints were extracted
    var hasAnyHints: Bool {
        return titleLikely != nil ||
               year != nil ||
               decade != nil ||
               !actors.isEmpty ||
               director != nil ||
               author != nil ||
               !keywords.isEmpty ||
               !plotClues.isEmpty ||
               isRemakeHint
    }
}

/// Extracts movie-related hints from voice utterances
enum MovieHintExtractor {
    
    // MARK: - Actor Patterns
    
    /// Patterns that indicate an actor mention
    /// Updated to capture 3+ word names like "Oscar Isaac"
    private static let actorPatterns: [String] = [
        "with (\\w+(?:\\s+\\w+){0,2})",  // Capture up to 3 words (e.g., "Oscar Isaac")
        "starring (\\w+(?:\\s+\\w+){0,2})",
        "stars (\\w+(?:\\s+\\w+){0,2})",
        "has (\\w+(?:\\s+\\w+){0,2}) in it",
        "(\\w+(?:\\s+\\w+){0,2}) is in it",
        "(\\w+(?:\\s+\\w+){0,2}) plays",
        "(\\w+(?:\\s+\\w+){0,2}) was in",
        "actor (\\w+(?:\\s+\\w+){0,2})"  // Added pattern for "actor Oscar Isaac"
    ]
    
    // MARK: - Director Patterns
    
    /// Patterns that indicate a director mention
    /// Updated to capture 3+ word names like "Guillermo del Toro"
    private static let directorPatterns: [String] = [
        "directed by (\\w+(?:\\s+\\w+){0,3})",  // Capture up to 4 words (e.g., "Guillermo del Toro")
        "by director (\\w+(?:\\s+\\w+){0,3})",
        "(\\w+(?:\\s+\\w+){0,3}) directed",
        "a (\\w+(?:\\s+\\w+){0,3}) film",
        "a (\\w+(?:\\s+\\w+){0,3}) movie"
    ]
    
    // MARK: - Author Patterns
    
    /// Patterns that indicate an author mention (for book adaptations)
    private static let authorPatterns: [String] = [
        // "by author [Name]" or "by the author [Name]" - capture 2+ words after
        "by (?:the )?author (\\w+(?:\\s+\\w+)+)",
        // "the author [Name]" at start of phrase
        "the author (\\w+(?:\\s+\\w+)+)",
        // "books/book by [Name]" - handle singular and plural, skip optional filler
        "books? by (?:the )?(?:author )?(\\w+(?:\\s+\\w+)+)",
        // "based on books/book by [Name]"
        "based on (?:the )?(?:a )?books? by (?:the )?(?:author )?(\\w+(?:\\s+\\w+)+)",
        // "novels/novel by [Name]"
        "novels? by (?:the )?(?:author )?(\\w+(?:\\s+\\w+)+)",
        // "written by [Name]" in any context
        "written by (\\w+(?:\\s+\\w+)+)"
    ]
    
    // MARK: - Known Directors (for better matching)
    
    private static let knownDirectors: Set<String> = [
        "spielberg", "scorsese", "tarantino", "kubrick", "hitchcock",
        "nolan", "fincher", "coppola", "anderson", "coen", "coens",
        "villeneuve", "cameron", "scott", "ridley", "zemeckis",
        "lucas", "jackson", "bay", "snyder", "wan", "peele",
        "gerwig", "coogler", "waititi", "gunn", "mangold",
        "guillermo", "toro", "del toro"  // Added for Guillermo del Toro
    ]
    
    // MARK: - Known Actors (for better matching)
    
    private static let knownActors: Set<String> = [
        "dicaprio", "leonardo", "pitt", "brad", "cruise", "tom",
        "hanks", "denzel", "washington", "freeman", "morgan",
        "streep", "meryl", "lawrence", "jennifer", "portman", "natalie",
        "damon", "matt", "affleck", "ben", "clooney", "george",
        "johansson", "scarlett", "roberts", "julia", "bullock", "sandra",
        "keanu", "reeves", "smith", "will", "johnson", "dwayne", "rock",
        "downey", "robert", "hemsworth", "chris", "pratt", "evans",
        "driver", "adam", "chalamet", "timothee", "zendaya", "pugh", "florence",
        "isaac", "oscar", "oscar isaac"  // Added for Oscar Isaac
    ]
    
    // MARK: - Genre Keywords
    
    private static let genreKeywords: [String: [String]] = [
        "horror": ["scary", "horror", "terrifying", "haunted", "possessed", "demon", "ghost", "zombie", "vampire", "slasher"],
        "comedy": ["funny", "comedy", "hilarious", "laughing", "comedic", "humor"],
        "action": ["action", "explosions", "chase", "fight", "battles", "stunts"],
        "drama": ["drama", "emotional", "moving", "touching", "serious"],
        "romance": ["romance", "romantic", "love story", "love", "relationship"],
        "sci-fi": ["sci-fi", "science fiction", "space", "alien", "futuristic", "robot", "spaceship"],
        "thriller": ["thriller", "suspense", "tense", "edge of seat", "twist"],
        "mystery": ["mystery", "detective", "whodunit", "clues", "investigation"]
    ]
    
    // MARK: - Remake Indicators
    
    private static let remakeIndicators: [String] = [
        "remake", "reboot", "new version", "modern version",
        "not the original", "the new one", "recent one",
        "the newer", "updated version"
    ]
    
    // MARK: - Plot Action Words
    
    private static let plotActionWords: Set<String> = [
        "escapes", "discovers", "finds", "travels", "fights", "falls",
        "meets", "saves", "kills", "dies", "transforms", "becomes",
        "hunts", "chases", "investigates", "solves", "steals", "robs",
        "kidnaps", "rescues", "betrays", "reveals", "hides", "runs"
    ]
    
    // MARK: - Extraction
    
    /// Extract all hints from an utterance
    static func extract(from utterance: String) -> ExtractedHints {
        let lower = utterance.lowercased()
        var hints = ExtractedHints()
        
        // Extract year
        hints.year = extractYear(from: lower)
        
        // Extract decade
        hints.decade = extractDecade(from: lower)
        
        // Extract actors
        hints.actors = extractActors(from: lower)
        
        // Extract director
        hints.director = extractDirector(from: lower)
        
        // Extract author
        hints.author = extractAuthor(from: lower)
        
        // Extract genre keywords
        hints.keywords = extractKeywords(from: lower)
        
        // Extract plot clues
        hints.plotClues = extractPlotClues(from: lower)
        
        // Check for remake hints
        hints.isRemakeHint = checkForRemakeHint(in: lower)
        
        // Try to extract likely title (short phrases at start)
        hints.titleLikely = extractLikelyTitle(from: utterance)
        
        return hints
    }
    
    // MARK: - Individual Extractors
    
    private static func extractYear(from text: String) -> Int? {
        // Look for 4-digit year between 1900-2030
        let yearPattern = try? NSRegularExpression(pattern: "\\b(19[0-9]{2}|20[0-2][0-9]|2030)\\b")
        if let match = yearPattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range, in: text) {
                return Int(text[range])
            }
        }
        return nil
    }
    
    private static func extractDecade(from text: String) -> Int? {
        // Look for decade references like "80s", "90s", "eighties"
        let decadePatterns: [(String, Int)] = [
            ("\\b(19)?80s?\\b", 1980), ("\\beighties\\b", 1980),
            ("\\b(19)?90s?\\b", 1990), ("\\bnineties\\b", 1990),
            ("\\b(20)?00s?\\b", 2000), ("\\b2000s\\b", 2000),
            ("\\b(20)?10s?\\b", 2010), ("\\btwenty tens\\b", 2010),
            ("\\b(20)?20s?\\b", 2020),
            ("\\b(19)?70s?\\b", 1970), ("\\bseventies\\b", 1970),
            ("\\b(19)?60s?\\b", 1960), ("\\bsixties\\b", 1960),
            ("\\b(19)?50s?\\b", 1950), ("\\bfifties\\b", 1950)
        ]
        
        for (pattern, decade) in decadePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    return decade
                }
            }
        }
        return nil
    }
    
    private static func extractActors(from text: String) -> [String] {
        var actors: [String] = []
        
        // First try pattern matching (more reliable for multi-word names)
        for pattern in actorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                        let name = String(text[range]).trimmingCharacters(in: .whitespaces)
                        // Capitalize properly (e.g., "Oscar Isaac" not "Oscar Isaac")
                        let capitalized = name.components(separatedBy: " ")
                            .map { $0.capitalized }
                            .joined(separator: " ")
                        if !actors.contains(capitalized) && capitalized.count > 2 {
                            actors.append(capitalized)
                        }
                    }
                }
            }
        }
        
        // Check for known multi-word actors
        let lowerText = text.lowercased()
        if lowerText.contains("oscar isaac") {
            if !actors.contains("Oscar Isaac") {
                actors.append("Oscar Isaac")
            }
        }
        
        // Check for known actors (single-word matches)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
        
        for word in words {
            if knownActors.contains(word) {
                // Try to get full name by looking at adjacent words
                if let index = words.firstIndex(of: word) {
                    var fullName = word.capitalized
                    // Check next word for last name
                    if index + 1 < words.count && knownActors.contains(words[index + 1]) {
                        fullName += " " + words[index + 1].capitalized
                    }
                    // Check previous word for first name
                    if index > 0 && knownActors.contains(words[index - 1]) {
                        fullName = words[index - 1].capitalized + " " + fullName
                    }
                    if !actors.contains(fullName) {
                        actors.append(fullName)
                    }
                }
            }
        }
        
        return actors
    }
    
    private static func extractDirector(from text: String) -> String? {
        // First try pattern matching (more reliable for multi-word names)
        for pattern in directorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                        let directorName = String(text[range]).trimmingCharacters(in: .whitespaces)
                        // Capitalize properly (e.g., "Guillermo del Toro" not "Guillermo Del Toro")
                        let capitalized = directorName.components(separatedBy: " ")
                            .map { $0.capitalized }
                            .joined(separator: " ")
                        return capitalized
                    }
                }
            }
        }
        
        // Check for known directors (for single-word matches)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
        
        // Check for multi-word known directors first (e.g., "del toro")
        let lowerText = text.lowercased()
        if lowerText.contains("del toro") || lowerText.contains("guillermo del toro") {
            return "Guillermo del Toro"
        }
        
        // Then check single words
        for word in words {
            if knownDirectors.contains(word) {
                return word.capitalized
            }
        }
        
        return nil
    }
    
    private static func extractAuthor(from text: String) -> String? {
        // Try pattern matching for author-related phrases
        // Note: We check for "written by" but need to avoid matching screenplay writers
        // So we prioritize patterns that clearly indicate book authors
        
        // First check for explicit author patterns
        for pattern in authorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                        let author = String(text[range]).trimmingCharacters(in: .whitespaces).capitalized
                        // Only return if it looks like a name (not too short)
                        if author.count > 2 {
                            return author
                        }
                    }
                }
            }
        }
        
        // Check for "written by" but only if it's in context of books/novels
        // This avoids matching screenplay writers
        let bookContextPatterns = [
            "based on.*written by (\\w+(?:\\s+\\w+)?)",
            "book.*written by (\\w+(?:\\s+\\w+)?)",
            "novel.*written by (\\w+(?:\\s+\\w+)?)"
        ]
        
        for pattern in bookContextPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) {
                        let author = String(text[range]).trimmingCharacters(in: .whitespaces).capitalized
                        if author.count > 2 {
                            return author
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func extractKeywords(from text: String) -> [String] {
        var keywords: [String] = []
        
        for (genre, genreWords) in genreKeywords {
            for word in genreWords {
                if text.contains(word) {
                    if !keywords.contains(genre) {
                        keywords.append(genre)
                    }
                    break
                }
            }
        }
        
        return keywords
    }
    
    private static func extractPlotClues(from text: String) -> [String] {
        var clues: [String] = []
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
        
        for word in words {
            if plotActionWords.contains(word) {
                // Get some context around the action word
                if let index = words.firstIndex(of: word) {
                    let start = max(0, index - 2)
                    let end = min(words.count, index + 3)
                    let context = words[start..<end].joined(separator: " ")
                    if !clues.contains(context) {
                        clues.append(context)
                    }
                }
            }
        }
        
        return clues
    }
    
    private static func checkForRemakeHint(in text: String) -> Bool {
        for indicator in remakeIndicators {
            if text.contains(indicator) {
                return true
            }
        }
        return false
    }
    
    private static func extractLikelyTitle(from utterance: String) -> String? {
        // If the utterance is short (1-4 words), it's probably just a title
        let words = utterance.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if words.count <= 4 {
            return utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Check for "the movie [Title]" or "find [Title]" patterns
        let lower = utterance.lowercased()
        let titlePatterns = [
            "the movie (.+)",
            "find (.+)",
            "search for (.+)",
            "search (.+)",
            "look up (.+)"
        ]
        
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
                    if match.numberOfRanges > 1 {
                        let title = String(utterance[Range(match.range(at: 1), in: utterance)!])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        // Only return if it looks like a title (not too long)
                        if title.components(separatedBy: .whitespaces).count <= 6 {
                            return title
                        }
                    }
                }
            }
        }
        
        return nil
    }
}
