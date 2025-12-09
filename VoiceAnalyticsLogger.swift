//  VoiceAnalyticsLogger.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-06 at 22:35 (America/Los_Angeles - Pacific Time)
//  Notes: Added failure reason tracking (handler_result, result_count, error_message)
//         Added markWatched case to mangoCommandTypeString
//         Added updateVoiceEventResult method and modified log to return UUID

import Foundation
import Supabase

/// Result of handling a voice command
enum VoiceHandlerResult: String {
    case success = "success"
    case noResults = "no_results"
    case ambiguous = "ambiguous"       // 10+ results
    case networkError = "network_error"
    case parseError = "parse_error"    // Both local parser and LLM failed
}

/// Logger for voice interaction analytics
class VoiceAnalyticsLogger {
    static let shared = VoiceAnalyticsLogger()
    
    var supabaseClient: SupabaseClient?
    
    private init() {
        setupSupabaseClient()
    }
    
    private func setupSupabaseClient() {
        guard let url = URL(string: SupabaseConfig.supabaseURL),
              !SupabaseConfig.supabaseAnonKey.isEmpty else {
            print("⚠️ [VoiceAnalytics] Supabase not configured. Voice event logging disabled.")
            return
        }
        
        self.supabaseClient = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }
    
    // Track if we've seen a 404 (function not deployed) to avoid spam
    private var hasSeen404 = false
    
    /// Log a voice interaction event (initial parse phase)
    /// Returns the UUID of the created event, or nil if logging failed
    @discardableResult
    func log(
        utterance: String,
        mangoCommand: MangoCommand,
        llmUsed: Bool,
        finalCommand: MangoCommand,
        llmIntent: LLMIntent?,
        llmError: Error?,
        handlerResult: VoiceHandlerResult? = nil,
        resultCount: Int? = nil,
        errorMessage: String? = nil
    ) async -> UUID? {
        guard let client = supabaseClient else {
            print("⚠️ [VoiceAnalytics] Supabase client not available, skipping log")
            return nil
        }
        
        let eventId = UUID()
        
        // Don't block UI - fire and forget
        Task {
            do {
                // Get current user ID if available
                var userId: UUID? = nil
                if let user = try? await SupabaseService.shared.getCurrentUser() {
                    userId = user.id
                }
                
                // Create a Codable struct for the insert
                struct VoiceEventInsert: Codable {
                    let id: String
                    let user_id: String?
                    let utterance: String
                    let mango_command_type: String
                    let mango_command_raw: String
                    let mango_command_movie_title: String?
                    let mango_command_recommender: String?
                    let llm_used: Bool
                    let final_command_type: String
                    let final_command_raw: String
                    let final_command_movie_title: String?
                    let final_command_recommender: String?
                    let llm_intent: String?
                    let llm_movie_title: String?
                    let llm_recommender: String?
                    let llm_error: String?
                    let handler_result: String?
                    let result_count: Int?
                    let error_message: String?
                }
                
                let eventData = VoiceEventInsert(
                    id: eventId.uuidString,
                    user_id: userId?.uuidString,
                    utterance: utterance,
                    mango_command_type: mangoCommandTypeString(mangoCommand),
                    mango_command_raw: mangoCommand.raw,
                    mango_command_movie_title: mangoCommand.movieTitle,
                    mango_command_recommender: mangoCommand.recommender,
                    llm_used: llmUsed,
                    final_command_type: mangoCommandTypeString(finalCommand),
                    final_command_raw: finalCommand.raw,
                    final_command_movie_title: finalCommand.movieTitle,
                    final_command_recommender: finalCommand.recommender,
                    llm_intent: llmIntent?.intent,
                    llm_movie_title: llmIntent?.movieTitle,
                    llm_recommender: llmIntent?.recommender,
                    llm_error: llmError?.localizedDescription,
                    handler_result: handlerResult?.rawValue,
                    result_count: resultCount,
                    error_message: errorMessage
                )
                
                try await client
                    .from("voice_utterance_events")
                    .insert(eventData)
                    .execute()
                
                print("📊 [VoiceAnalytics] Logged voice event \(eventId) to Supabase")
            } catch {
                print("⚠️ [VoiceAnalytics] Failed to log voice event: \(error.localizedDescription)")
            }
        }
        
        return eventId
    }
    
    // Note: logSearchResult method removed - use updateVoiceEventResult instead
    
    /// Updates a voice event with its handler result
    /// - Parameters:
    ///   - eventId: The UUID of the voice event to update
    ///   - result: One of: "success", "no_results", "ambiguous", "network_error", "parse_error"
    ///   - resultCount: Number of results (for searches)
    ///   - errorMessage: Optional error details
    static func updateVoiceEventResult(
        eventId: UUID,
        result: String,
        resultCount: Int? = nil,
        errorMessage: String? = nil
    ) async {
        guard let client = shared.supabaseClient else {
            print("⚠️ [VoiceAnalytics] Supabase client not available, skipping update")
            return
        }
        
        Task {
            do {
                // Create a Codable struct for the update
                struct VoiceEventUpdate: Codable {
                    let handler_result: String
                    let result_count: Int?
                    let error_message: String?
                }
                
                let updateData = VoiceEventUpdate(
                    handler_result: result,
                    result_count: resultCount,
                    error_message: errorMessage
                )
                
                try await client
                    .from("voice_utterance_events")
                    .update(updateData)
                    .eq("id", value: eventId.uuidString)
                    .execute()
                
                print("✅ [VoiceAnalytics] Updated event \(eventId) with result: \(result)")
            } catch {
                print("❌ [VoiceAnalytics] Failed to update event result: \(error)")
            }
        }
    }
    
    private func mangoCommandTypeString(_ command: MangoCommand) -> String {
        switch command {
        case .recommenderSearch:
            return "recommender_search"
        case .movieSearch:
            return "movie_search"
        case .createWatchlist:
            return "create_watchlist"
        case .markWatched(let watched, _):
            return watched ? "mark_watched" : "mark_unwatched"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - Voice Event Log Model

struct VoiceEventLog: Codable {
    let utterance: String
    let mangoCommandType: String
    let mangoCommandRaw: String
    let mangoCommandMovieTitle: String?
    let mangoCommandRecommender: String?
    let llmUsed: Bool
    let finalCommandType: String
    let finalCommandRaw: String
    let finalCommandMovieTitle: String?
    let finalCommandRecommender: String?
    let llmIntent: String?
    let llmMovieTitle: String?
    let llmRecommender: String?
    let llmError: String?
    
    // New fields for result tracking
    let handlerResult: String?
    let resultCount: Int?
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case utterance
        case mangoCommandType = "mango_command_type"
        case mangoCommandRaw = "mango_command_raw"
        case mangoCommandMovieTitle = "mango_command_movie_title"
        case mangoCommandRecommender = "mango_command_recommender"
        case llmUsed = "llm_used"
        case finalCommandType = "final_command_type"
        case finalCommandRaw = "final_command_raw"
        case finalCommandMovieTitle = "final_command_movie_title"
        case finalCommandRecommender = "final_command_recommender"
        case llmIntent = "llm_intent"
        case llmMovieTitle = "llm_movie_title"
        case llmRecommender = "llm_recommender"
        case llmError = "llm_error"
        case handlerResult = "handler_result"
        case resultCount = "result_count"
        case errorMessage = "error_message"
    }
}
