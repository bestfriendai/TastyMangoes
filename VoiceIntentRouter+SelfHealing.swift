//  VoiceIntentRouter+SelfHealing.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-07 at 22:55 (America/Los_Angeles - Pacific Time)
//  Notes: Extension to VoiceIntentRouter that adds self-healing trigger logic.
//         Call checkAndTriggerSelfHealing() after voice commands complete.

import Foundation

// MARK: - VoiceIntentRouter Self-Healing Extension

extension VoiceIntentRouter {
    
    /// Check if self-healing should trigger and handle it
    /// Call this AFTER logging the voice event, when you have the handler result
    ///
    /// - Parameters:
    ///   - utterance: The original transcript text
    ///   - originalCommand: The MangoCommand that was parsed
    ///   - handlerResult: The result of handling the command (.success, .noResults, etc.)
    ///   - screen: Current screen name for context (default: "Unknown")
    ///   - movieContext: Movie title if user was viewing a movie
    ///   - voiceEventId: UUID of the voice event for linking
    static func checkAndTriggerSelfHealing(
        utterance: String,
        originalCommand: MangoCommand,
        handlerResult: VoiceHandlerResult?,
        screen: String = "Unknown",
        movieContext: String? = nil,
        voiceEventId: UUID? = nil
    ) {
        // Check trigger conditions
        guard SelfHealingVoiceService.shouldTriggerSelfHealing(
            utterance: utterance,
            commandType: originalCommand,
            handlerResult: handlerResult
        ) else {
            return
        }
        
        // Trigger self-healing in background
        Task { @MainActor in
            await SelfHealingVoiceService.shared.handleFailedCommand(
                utterance: utterance,
                originalCommand: originalCommand,
                handlerResult: handlerResult,
                screen: screen,
                movieContext: movieContext,
                voiceEventId: voiceEventId
            )
        }
    }
}


// ════════════════════════════════════════════════════════════════════════════
// INTEGRATION GUIDE
// ════════════════════════════════════════════════════════════════════════════
//
// Add this call after voice commands complete in VoiceIntentRouter.swift:
//
// 1. After movie search returns results (in the search completion handler):
//
//    VoiceIntentRouter.checkAndTriggerSelfHealing(
//        utterance: text,
//        originalCommand: mangoCommand,
//        handlerResult: handlerResult,
//        screen: "SearchView"
//    )
//
// 2. After unknown commands:
//
//    case .unknown:
//        handlerResult = .parseError
//        MangoSpeaker.shared.speak("I didn't understand that...")
//
//        VoiceIntentRouter.checkAndTriggerSelfHealing(
//            utterance: text,
//            originalCommand: mangoCommand,
//            handlerResult: handlerResult
//        )
//
// 3. If you have movie context (user was on MoviePageView):
//
//    VoiceIntentRouter.checkAndTriggerSelfHealing(
//        utterance: text,
//        originalCommand: mangoCommand,
//        handlerResult: handlerResult,
//        screen: "MoviePageView",
//        movieContext: currentMovieTitle
//    )
//
// ════════════════════════════════════════════════════════════════════════════


// ════════════════════════════════════════════════════════════════════════════
// CURSOR PROMPT
// ════════════════════════════════════════════════════════════════════════════
//
// Copy this to Cursor to integrate self-healing into VoiceIntentRouter:
//
// """
// Add self-healing trigger calls to VoiceIntentRouter.swift
//
// The SelfHealingVoiceService and VoiceIntentRouter+SelfHealing extension are
// already in the project.
//
// Find these locations in handleTalkToMangoTranscript() and add the trigger:
//
// 1. After movie search completes (where you call logSearchResult):
//    Add: VoiceIntentRouter.checkAndTriggerSelfHealing(
//        utterance: text,
//        originalCommand: mangoCommand,
//        handlerResult: handlerResult,
//        screen: "SearchView"
//    )
//
// 2. After handling .unknown commands:
//    Add: VoiceIntentRouter.checkAndTriggerSelfHealing(
//        utterance: text,
//        originalCommand: mangoCommand,
//        handlerResult: .parseError
//    )
//
// The trigger conditions are already handled by shouldTriggerSelfHealing():
// - handler_result is "no_results" AND utterance contains action words
// - OR command is "movie_search" but utterance has action words
// - OR command is "unknown" and utterance has action words
//
// Action words: watch, watched, add, mark, remove, delete, move, save, rate,
//               actually, didn't, haven't, unwatched, seen
// """
//
// ════════════════════════════════════════════════════════════════════════════
