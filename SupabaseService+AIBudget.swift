//  SupabaseService+AIBudget.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-15 at 21:30 (America/Los_Angeles - Pacific Time)
//  Notes: Extension for AI discovery budget tracking methods.
//         Calls RPC functions and inserts into ai_discovery_requests table.

import Foundation
import Supabase

// MARK: - AI Budget Response Models

/// Response from get_ai_budget_status() RPC
struct AIBudgetStatusResponse: Codable {
    let spentTodayCents: Double
    let budgetCents: Double
    let remainingCents: Double
    let requestsToday: Int
    let tokensToday: Int
    let isOverBudget: Bool
    let spendRateCentsPerHour: Double
    let percentUsed: Double
    
    enum CodingKeys: String, CodingKey {
        case spentTodayCents = "spent_today_cents"
        case budgetCents = "budget_cents"
        case remainingCents = "remaining_cents"
        case requestsToday = "requests_today"
        case tokensToday = "tokens_today"
        case isOverBudget = "is_over_budget"
        case spendRateCentsPerHour = "spend_rate_cents_per_hour"
        case percentUsed = "percent_used"
    }
}

/// Response from can_make_ai_request() RPC
struct AIRateLimitResponse: Codable {
    let allowed: Bool
    let reason: String
    let spentCents: Double
    let remainingCents: Double
    let requestsLastMinute: Int?
    
    enum CodingKeys: String, CodingKey {
        case allowed
        case reason
        case spentCents = "spent_cents"
        case remainingCents = "remaining_cents"
        case requestsLastMinute = "requests_last_minute"
    }
}

/// Hints structure for JSONB storage
struct AIDiscoveryHints: Codable {
    let titleLikely: String?
    let year: Int?
    let decade: Int?
    let actors: [String]?
    let director: String?
    let keywords: [String]?
    let plotClues: [String]?
    let isRemakeHint: Bool?
    
    enum CodingKeys: String, CodingKey {
        case titleLikely = "title_likely"
        case year
        case decade
        case actors
        case director
        case keywords
        case plotClues = "plot_clues"
        case isRemakeHint = "is_remake_hint"
    }
}

// MARK: - SupabaseService Extension

extension SupabaseService {
    
    // MARK: - Budget Status
    
    /// Get current AI budget status for the day
    /// - Returns: Budget status including spent, remaining, and rate info
    func getAIBudgetStatus() async throws -> AIBudgetStatusResponse {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        #if DEBUG
        print("💰 [SupabaseService] Fetching AI budget status...")
        #endif
        
        // RPC functions returning JSON need to be decoded from the JSON response
        let response: AIBudgetStatusResponse = try await client
            .rpc("get_ai_budget_status")
            .execute()
            .value
        
        #if DEBUG
        print("💰 [SupabaseService] Budget: $\(String(format: "%.2f", response.spentTodayCents / 100)) / $\(String(format: "%.2f", response.budgetCents / 100)) (\(String(format: "%.1f", response.percentUsed))%)")
        #endif
        
        return response
    }
    
    // MARK: - Rate Limiting
    
    /// Check if an AI request is allowed (budget + rate limits)
    /// - Returns: Whether request is allowed and reason if not
    func canMakeAIRequest() async throws -> AIRateLimitResponse {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        #if DEBUG
        print("🚦 [SupabaseService] Checking AI rate limits...")
        #endif
        
        // RPC functions returning JSON need to be decoded from the JSON response
        let response: AIRateLimitResponse = try await client
            .rpc("can_make_ai_request")
            .execute()
            .value
        
        #if DEBUG
        if response.allowed {
            print("🚦 [SupabaseService] AI request allowed")
        } else {
            print("🚦 [SupabaseService] AI request blocked: \(response.reason)")
        }
        #endif
        
        return response
    }
    
    // MARK: - Request Logging
    
    /// Log an AI discovery request to the database
    /// - Parameters:
    ///   - query: The user's search query
    ///   - hints: Extracted hints (optional)
    ///   - moviesFound: Number of movies returned by AI
    ///   - moviesIngested: Number of new movies ingested
    ///   - promptTokens: Input tokens used
    ///   - completionTokens: Output tokens used
    ///   - costCents: Cost in cents
    ///   - responseTimeMs: Response time in milliseconds
    ///   - status: Status of the request (success, error, rate_limited, over_budget)
    ///   - errorMessage: Error message if status is not success
    func logAIDiscoveryRequest(
        query: String,
        hints: ExtractedMovieHints?,
        moviesFound: Int,
        moviesIngested: Int,
        promptTokens: Int,
        completionTokens: Int,
        costCents: Double,
        responseTimeMs: Int,
        status: String = "success",
        errorMessage: String? = nil
    ) async {
        guard let client = client else {
            #if DEBUG
            print("⚠️ [SupabaseService] Client not configured, skipping AI discovery request log")
            #endif
            return
        }
        
        #if DEBUG
        print("📝 [SupabaseService] Logging AI discovery request...")
        #endif
        
        // Convert hints to Codable struct for JSONB
        var hintsStruct: AIDiscoveryHints? = nil
        if let hints = hints {
            hintsStruct = AIDiscoveryHints(
                titleLikely: hints.titleLikely,
                year: hints.year,
                decade: hints.decade,
                actors: hints.actors.isEmpty ? nil : hints.actors,
                director: hints.director,
                keywords: hints.keywords.isEmpty ? nil : hints.keywords,
                plotClues: hints.plotClues.isEmpty ? nil : hints.plotClues,
                isRemakeHint: hints.isRemakeHint ? true : nil
            )
        }
        
        // Get current user ID if available
        var userId: UUID? = nil
        if let user = try? await SupabaseService.shared.getCurrentUser() {
            userId = user.id
        }
        
        // Create insert struct - Supabase Swift SDK handles JSONB automatically
        struct AIDiscoveryRequestInsert: Codable {
            let userId: String?  // Will be set by RLS if null
            let query: String
            let hints: AIDiscoveryHints?  // JSONB - SDK handles encoding
            let moviesFound: Int
            let moviesIngested: Int
            let promptTokens: Int
            let completionTokens: Int
            let costCents: Double
            let responseTimeMs: Int
            let status: String
            let errorMessage: String?
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case query
                case hints
                case moviesFound = "movies_found"
                case moviesIngested = "movies_ingested"
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case costCents = "cost_cents"
                case responseTimeMs = "response_time_ms"
                case status
                case errorMessage = "error_message"
            }
        }
        
        let insertData = AIDiscoveryRequestInsert(
            userId: userId?.uuidString,
            query: query,
            hints: hintsStruct,
            moviesFound: moviesFound,
            moviesIngested: moviesIngested,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            costCents: costCents,
            responseTimeMs: responseTimeMs,
            status: status,
            errorMessage: errorMessage
        )
        
        do {
            try await client
                .from("ai_discovery_requests")
                .insert(insertData)
                .execute()
            
            #if DEBUG
            print("📝 [SupabaseService] AI discovery request logged successfully")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [SupabaseService] Failed to log AI discovery request: \(error)")
            #endif
            // Don't throw - logging should not break the main flow
        }
    }
}
