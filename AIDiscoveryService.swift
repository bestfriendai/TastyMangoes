//  AIDiscoveryService.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-15 at 21:45 (America/Los_Angeles - Pacific Time) / 05:45 UTC
//  Notes: OpenAI-powered movie discovery service for hint-based searches.
//         Discovers movies by actor, director, year, or fuzzy descriptions.
//         Tracks usage against $10/day budget with rate limiting.
//  Updates: Wired up Supabase budget tracking - calls get_ai_budget_status(),
//           can_make_ai_request(), and logs to ai_discovery_requests table.

import Foundation

// MARK: - Discovery Models

/// A movie suggestion returned by AI discovery
struct AIMovieSuggestion: Codable, Identifiable {
    let title: String
    let year: Int?
    let tmdbId: Int?
    let confidence: String?  // "high", "medium", "low"
    let reason: String?      // Why this movie matches the query
    
    var id: String { "\(tmdbId ?? 0)-\(title)-\(year ?? 0)" }
    
    enum CodingKeys: String, CodingKey {
        case title
        case year
        case tmdbId = "tmdb_id"
        case confidence
        case reason
    }
}

/// Response from AI discovery
struct AIDiscoveryResponse: Codable {
    let movies: [AIMovieSuggestion]
    let queryInterpretation: String?  // How AI understood the query
    let totalFound: Int?
    
    enum CodingKeys: String, CodingKey {
        case movies
        case queryInterpretation = "query_interpretation"
        case totalFound = "total_found"
    }
}

/// Budget status returned from Supabase
struct AIBudgetStatus {
    let spentTodayDollars: Double
    let budgetDollars: Double
    let remainingDollars: Double
    let requestsToday: Int
    let tokensToday: Int
    let isOverBudget: Bool
    let spendRatePerHour: Double
    
    var projectedDailySpend: Double {
        spendRatePerHour * 24.0
    }
    
    var percentUsed: Double {
        (spentTodayDollars / budgetDollars) * 100.0
    }
}

/// Rate limit check result
struct AIRateLimitCheck {
    let allowed: Bool
    let reason: String
    let spentDollars: Double
    let remainingDollars: Double
}

// MARK: - OpenAI Response Models (Private)

private struct DiscoveryChatRequest: Codable {
    let model: String
    let messages: [DiscoveryChatMessage]
    let responseFormat: DiscoveryResponseFormat?
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct DiscoveryChatMessage: Codable {
    let role: String
    let content: String
}

private struct DiscoveryResponseFormat: Codable {
    let type: String
}

private struct DiscoveryChatResponse: Codable {
    let id: String
    let choices: [DiscoveryChoice]
    let usage: DiscoveryUsage
    
    struct DiscoveryChoice: Codable {
        let message: DiscoveryMessage
        
        struct DiscoveryMessage: Codable {
            let content: String
        }
    }
    
    struct DiscoveryUsage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - AI Discovery Service

class AIDiscoveryService {
    static let shared = AIDiscoveryService()
    
    // Cost per 1M tokens for gpt-4o (as of Dec 2025)
    // Input: $2.50 per 1M, Output: $10.00 per 1M
    private let inputCostPer1MTokens: Double = 2.50
    private let outputCostPer1MTokens: Double = 10.00
    
    private init() {
        #if DEBUG
        print("🎬 [AIDiscovery] Service initialized")
        #endif
    }
    
    // MARK: - Budget Checking
    
    /// Check current budget status from Supabase
    func checkBudgetStatus() async throws -> AIBudgetStatus {
        #if DEBUG
        print("🎬 [AIDiscovery] Checking budget status...")
        #endif
        
        do {
            let response = try await SupabaseService.shared.getAIBudgetStatus()
            
            return AIBudgetStatus(
                spentTodayDollars: response.spentTodayCents / 100.0,
                budgetDollars: response.budgetCents / 100.0,
                remainingDollars: response.remainingCents / 100.0,
                requestsToday: response.requestsToday,
                tokensToday: response.tokensToday,
                isOverBudget: response.isOverBudget,
                spendRatePerHour: response.spendRateCentsPerHour / 100.0
            )
        } catch {
            #if DEBUG
            print("⚠️ [AIDiscovery] Failed to get budget status: \(error)")
            #endif
            // Return safe defaults on error (don't block requests)
            return AIBudgetStatus(
                spentTodayDollars: 0,
                budgetDollars: 10.0,
                remainingDollars: 10.0,
                requestsToday: 0,
                tokensToday: 0,
                isOverBudget: false,
                spendRatePerHour: 0
            )
        }
    }
    
    /// Check if we can make a request (rate limiting + budget)
    func canMakeRequest() async throws -> AIRateLimitCheck {
        #if DEBUG
        print("🎬 [AIDiscovery] Checking rate limits...")
        #endif
        
        do {
            let response = try await SupabaseService.shared.canMakeAIRequest()
            
            return AIRateLimitCheck(
                allowed: response.allowed,
                reason: response.reason,
                spentDollars: response.spentCents / 100.0,
                remainingDollars: response.remainingCents / 100.0
            )
        } catch {
            #if DEBUG
            print("⚠️ [AIDiscovery] Failed to check rate limits: \(error)")
            #endif
            // Allow request on error (fail open for better UX)
            return AIRateLimitCheck(
                allowed: true,
                reason: "Rate limit check failed, allowing request",
                spentDollars: 0,
                remainingDollars: 10.0
            )
        }
    }
    
    // MARK: - Movie Discovery
    
    /// Discover movies matching a query with hints
    /// - Parameters:
    ///   - query: The original user utterance
    ///   - hints: Extracted hints (actor, director, year, etc.)
    /// - Returns: List of movie suggestions from AI
    func discoverMovies(
        query: String,
        hints: ExtractedMovieHints? = nil
    ) async throws -> AIDiscoveryResponse {
        
        // Check rate limits first
        let rateLimitCheck = try await canMakeRequest()
        guard rateLimitCheck.allowed else {
            throw AIDiscoveryError.rateLimited(rateLimitCheck.reason)
        }
        
        guard !OpenAIConfig.apiKey.isEmpty else {
            throw AIDiscoveryError.notConfigured
        }
        
        guard let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions") else {
            throw AIDiscoveryError.invalidURL
        }
        
        let startTime = Date()
        
        // Build the prompt based on hints
        let systemPrompt = buildDiscoveryPrompt()
        let userPrompt = buildUserPrompt(query: query, hints: hints)
        
        let requestBody = DiscoveryChatRequest(
            model: OpenAIConfig.defaultModel,
            messages: [
                DiscoveryChatMessage(role: "system", content: systemPrompt),
                DiscoveryChatMessage(role: "user", content: userPrompt)
            ],
            responseFormat: DiscoveryResponseFormat(type: "json_object"),
            temperature: 0.3,
            maxTokens: 2500  // Limit response size for cost control (increased for 25 movies)
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = OpenAIConfig.requestTimeout
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        #if DEBUG
        print("🎬 [AIDiscovery] Query: \"\(query)\"")
        if let hints = hints {
            print("🎬 [AIDiscovery] Hints: actor=\(hints.actors.isEmpty ? "nil" : hints.actors.joined(separator: ", ")), director=\(hints.director ?? "nil"), author=\(hints.author ?? "nil"), year=\(hints.year?.description ?? "nil")")
        }
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let responseTime = Int(Date().timeIntervalSince(startTime) * 1000)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIDiscoveryError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [AIDiscovery] API error: HTTP \(httpResponse.statusCode)")
            throw AIDiscoveryError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let completionResponse = try decoder.decode(DiscoveryChatResponse.self, from: data)
        
        // Calculate cost
        let usage = completionResponse.usage
        let costCents = calculateCost(
            promptTokens: usage.promptTokens,
            completionTokens: usage.completionTokens
        )
        
        #if DEBUG
        print("🎬 [AIDiscovery] Tokens: \(usage.promptTokens) in, \(usage.completionTokens) out, \(usage.totalTokens) total")
        print("🎬 [AIDiscovery] Cost: $\(String(format: "%.4f", costCents / 100.0))")
        print("🎬 [AIDiscovery] Response time: \(responseTime)ms")
        #endif
        
        guard let content = completionResponse.choices.first?.message.content else {
            throw AIDiscoveryError.invalidResponse
        }
        
        // Parse movie suggestions from JSON
        guard let jsonData = content.data(using: .utf8) else {
            throw AIDiscoveryError.decodingError("Could not convert content to data")
        }
        
        let discoveryResponse = try decoder.decode(AIDiscoveryResponse.self, from: jsonData)
        
        #if DEBUG
        print("🎬 [AIDiscovery] Found \(discoveryResponse.movies.count) movies")
        for movie in discoveryResponse.movies {
            print("   - \(movie.title) (\(movie.year ?? 0)) [TMDB: \(movie.tmdbId ?? 0)]")
        }
        #endif
        
        // Log to Supabase (async, don't wait)
        Task {
            await logDiscoveryRequest(
                query: query,
                hints: hints,
                response: discoveryResponse,
                promptTokens: usage.promptTokens,
                completionTokens: usage.completionTokens,
                costCents: costCents,
                responseTimeMs: responseTime
            )
        }
        
        return discoveryResponse
    }
    
    // MARK: - Private Helpers
    
    private func buildDiscoveryPrompt() -> String {
        """
        You are a movie database expert. Your job is to identify specific movies based on user queries that may include:
        - Actor names (e.g., "the Batman movie with Michael Keaton")
        - Director names (e.g., "movies by Christopher Nolan")
        - Years or decades (e.g., "that 80s horror movie")
        - Plot descriptions (e.g., "the one where they go into dreams")
        
        IMPORTANT RULES:
        1. Return ONLY real movies that actually exist
        2. Include the TMDB ID if you know it (this is critical for our database)
        3. Limit to 25 most relevant results
        4. For remake queries, return ALL versions (e.g., all Batman movies with the specified actor)
        5. Order by relevance to the query
        
        Respond with ONLY a JSON object in this exact format:
        {
          "query_interpretation": "How you understood the query",
          "total_found": <number>,
          "movies": [
            {
              "title": "Movie Title",
              "year": 1989,
              "tmdb_id": 268,
              "confidence": "high" | "medium" | "low",
              "reason": "Why this matches the query"
            }
          ]
        }
        
        If you're unsure about a TMDB ID, set it to null - we'll look it up.
        If no movies match, return an empty movies array.
        """
    }
    
    private func buildUserPrompt(query: String, hints: ExtractedMovieHints?) -> String {
        var prompt = "Find movies matching: \"\(query)\""
        
        if let hints = hints {
            var hintParts: [String] = []
            
            if !hints.actors.isEmpty {
                hintParts.append("Actor(s): \(hints.actors.joined(separator: ", "))")
            }
            if let director = hints.director {
                hintParts.append("Director: \(director)")
            }
            if let author = hints.author {
                hintParts.append("Author: \(author)")
            }
            if let year = hints.year {
                hintParts.append("Year: \(year)")
            }
            if let decade = hints.decade {
                hintParts.append("Decade: \(decade)s")
            }
            if !hints.keywords.isEmpty {
                hintParts.append("Keywords: \(hints.keywords.joined(separator: ", "))")
            }
            if let titleLikely = hints.titleLikely {
                hintParts.append("Likely title: \(titleLikely)")
            }
            
            if !hintParts.isEmpty {
                prompt += "\n\nExtracted hints:\n" + hintParts.joined(separator: "\n")
            }
        }
        
        return prompt
    }
    
    private func calculateCost(promptTokens: Int, completionTokens: Int) -> Double {
        let inputCost = (Double(promptTokens) / 1_000_000.0) * inputCostPer1MTokens * 100.0  // cents
        let outputCost = (Double(completionTokens) / 1_000_000.0) * outputCostPer1MTokens * 100.0
        return inputCost + outputCost
    }
    
    private func logDiscoveryRequest(
        query: String,
        hints: ExtractedMovieHints?,
        response: AIDiscoveryResponse,
        promptTokens: Int,
        completionTokens: Int,
        costCents: Double,
        responseTimeMs: Int
    ) async {
        await SupabaseService.shared.logAIDiscoveryRequest(
            query: query,
            hints: hints,
            moviesFound: response.movies.count,
            moviesIngested: 0,  // Will be updated by HintSearchCoordinator after ingestion
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            costCents: costCents,
            responseTimeMs: responseTimeMs,
            status: "success",
            errorMessage: nil
        )
    }
}

// MARK: - Errors

enum AIDiscoveryError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError(String)
    case rateLimited(String)
    case overBudget
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenAI API key not configured"
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .rateLimited(let reason):
            return "Rate limited: \(reason)"
        case .overBudget:
            return "Daily AI budget exceeded ($10/day)"
        }
    }
}

// MARK: - ExtractedMovieHints (bridges from MovieHintExtractor.ExtractedHints)

/// Hints extracted from user utterance - bridges from ExtractedHints
/// Note: Matches ExtractedHints struct in MovieHintExtractor.swift
struct ExtractedMovieHints: Codable {
    var titleLikely: String?
    var year: Int?
    var decade: Int?
    var actors: [String]
    var director: String?
    var author: String?
    var keywords: [String]
    var plotClues: [String]
    var isRemakeHint: Bool
    
    enum CodingKeys: String, CodingKey {
        case titleLikely = "title_likely"
        case year
        case decade
        case actors
        case director
        case author
        case keywords
        case plotClues = "plot_clues"
        case isRemakeHint = "is_remake_hint"
    }
    
    /// Default initializer
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
    
    /// Convert from MovieHintExtractor's ExtractedHints
    init(from extractorHints: ExtractedHints) {
        self.titleLikely = extractorHints.titleLikely
        self.year = extractorHints.year
        self.decade = extractorHints.decade
        self.actors = extractorHints.actors
        self.director = extractorHints.director
        self.author = extractorHints.author
        self.keywords = extractorHints.keywords
        self.plotClues = extractorHints.plotClues
        self.isRemakeHint = extractorHints.isRemakeHint
    }
    
    /// Check if any hints were extracted
    var hasHints: Bool {
        titleLikely != nil ||
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
