//  VoiceAnalyticsLogger.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-05 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Added createWatchlist case to switch statement for exhaustive matching.

import Foundation

/// Logger for voice interaction analytics
class VoiceAnalyticsLogger {
    static let shared = VoiceAnalyticsLogger()
    
    private init() {}
    
    // Track if we've seen a 404 (function not deployed) to avoid spam
    private var hasSeen404 = false
    
    /// Log a voice interaction event
    /// - Parameters:
    ///   - utterance: The original user utterance
    ///   - mangoCommand: The initial MangoCommand parser result
    ///   - llmUsed: Whether LLM fallback was used
    ///   - finalCommand: The final command after LLM processing (if any)
    ///   - llmIntent: The LLM intent response (if LLM was used)
    ///   - llmError: Any error from LLM call (if LLM was used and failed)
    func log(
        utterance: String,
        mangoCommand: MangoCommand,
        llmUsed: Bool,
        finalCommand: MangoCommand,
        llmIntent: LLMIntent?,
        llmError: Error?
    ) async {
        // Don't block UI - fire and forget
        Task {
            do {
                let event = VoiceEventLog(
                    utterance: utterance,
                    mangoCommandType: mangoCommandTypeString(mangoCommand),
                    mangoCommandRaw: mangoCommand.raw,
                    mangoCommandMovieTitle: mangoCommand.movieTitle,
                    mangoCommandRecommender: mangoCommand.recommender,
                    llmUsed: llmUsed,
                    finalCommandType: mangoCommandTypeString(finalCommand),
                    finalCommandRaw: finalCommand.raw,
                    finalCommandMovieTitle: finalCommand.movieTitle,
                    finalCommandRecommender: finalCommand.recommender,
                    llmIntent: llmIntent?.intent,
                    llmMovieTitle: llmIntent?.movieTitle,
                    llmRecommender: llmIntent?.recommender,
                    llmError: llmError?.localizedDescription
                )
                
                try await SupabaseService.shared.logVoiceEvent(event)
                print("📊 [VoiceAnalytics] Logged voice event to Supabase")
            } catch SupabaseError.functionNotFound {
                // Function not deployed - log once, then skip future attempts
                if !hasSeen404 {
                    print("⚠️ [VoiceAnalytics] log-voice-event function not found (404). Skipping analytics logging for this session.")
                    hasSeen404 = true
                }
                // Silently skip logging - don't spam logs
            } catch {
                // Don't fail the user flow if logging fails
                print("⚠️ [VoiceAnalytics] Failed to log voice event: \(error.localizedDescription)")
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
    }
}

