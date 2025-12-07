//  VoiceAnalyticsLogger.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-06 at 22:35 (America/Los_Angeles - Pacific Time)
//  Notes: Added failure reason tracking (handler_result, result_count, error_message)
//         Added markWatched case to mangoCommandTypeString

import Foundation

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
    
    private init() {}
    
    // Track if we've seen a 404 (function not deployed) to avoid spam
    private var hasSeen404 = false
    
    /// Log a voice interaction event (initial parse phase)
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
                    llmError: llmError?.localizedDescription,
                    handlerResult: handlerResult?.rawValue,
                    resultCount: resultCount,
                    errorMessage: errorMessage
                )
                
                try await SupabaseService.shared.logVoiceEvent(event)
                print("📊 [VoiceAnalytics] Logged voice event to Supabase")
            } catch SupabaseError.functionNotFound {
                if !hasSeen404 {
                    print("⚠️ [VoiceAnalytics] log-voice-event function not found (404). Skipping analytics logging for this session.")
                    hasSeen404 = true
                }
            } catch {
                print("⚠️ [VoiceAnalytics] Failed to log voice event: \(error.localizedDescription)")
            }
        }
    }
    
    /// Log search result after search completes (called from SearchViewModel)
    func logSearchResult(
        query: String,
        resultCount: Int,
        error: Error? = nil
    ) async {
        // Determine handler result
        let handlerResult: VoiceHandlerResult
        let errorMessage: String?
        
        if let error = error {
            handlerResult = .networkError
            errorMessage = error.localizedDescription
        } else if resultCount == 0 {
            handlerResult = .noResults
            errorMessage = nil
        } else if resultCount >= 10 {
            handlerResult = .ambiguous
            errorMessage = nil
        } else {
            handlerResult = .success
            errorMessage = nil
        }
        
        print("📊 [VoiceAnalytics] Search result: \(handlerResult.rawValue) (\(resultCount) results)")
        
        Task {
            do {
                let event = VoiceEventLog(
                    utterance: query,
                    mangoCommandType: "movie_search",
                    mangoCommandRaw: query,
                    mangoCommandMovieTitle: query,
                    mangoCommandRecommender: nil,
                    llmUsed: false,
                    finalCommandType: "search_result",
                    finalCommandRaw: query,
                    finalCommandMovieTitle: query,
                    finalCommandRecommender: nil,
                    llmIntent: nil,
                    llmMovieTitle: nil,
                    llmRecommender: nil,
                    llmError: nil,
                    handlerResult: handlerResult.rawValue,
                    resultCount: resultCount,
                    errorMessage: errorMessage
                )
                
                try await SupabaseService.shared.logVoiceEvent(event)
                print("📊 [VoiceAnalytics] Logged search result to Supabase")
            } catch SupabaseError.functionNotFound {
                // Already logged warning, silently skip
            } catch {
                print("⚠️ [VoiceAnalytics] Failed to log search result: \(error.localizedDescription)")
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
        case .markWatched:
            return "mark_watched"
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
