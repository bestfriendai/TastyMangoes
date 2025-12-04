//  VoiceIntentRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 09:45 PST (America/Los_Angeles - Pacific Time)
//  Notes: Central router for handling voice utterances. Ready for OpenAI/LLM integration in next phase.

import Foundation

/// Source of the voice input
enum VoiceSource: Equatable {
    case talkToMango
    case searchBar
    case other(String)
}

/// Result of processing a voice intent (placeholder for now)
enum VoiceIntentResult {
    case placeholder(text: String)
    // Future cases:
    // case searchMovie(query: String)
    // case addToWatchlist(movie: String, recommender: String?)
    // case showWatchlist(name: String)
    // etc.
}

/// Central router for all voice interactions
/// This is the single entry point for processing voice utterances
enum VoiceIntentRouter {
    
    /// Handle a voice utterance from any source
    /// - Parameters:
    ///   - utterance: The transcribed text from the user
    ///   - source: Where the voice input came from
    static func handle(utterance: String, source: VoiceSource) {
        print("🎙 Voice utterance from \(source): \(utterance)")
        
        // Route TalkToMango utterances to specialized handler
        if source == .talkToMango {
            handleTalkToMangoTranscript(utterance)
            return
        }
        
        // TODO: In next phase, this will:
        // 1. Send utterance to OpenAI/LLM for classification
        // 2. Route to appropriate handler based on intent
        // 3. Execute the action (search, add to watchlist, etc.)
        // 4. Return appropriate result
        
        // For now, just log and show placeholder
        let result = VoiceIntentResult.placeholder(text: utterance)
        
        // Post notification so UI can show toast/alert if needed
        NotificationCenter.default.post(
            name: NSNotification.Name("VoiceIntentProcessed"),
            object: nil,
            userInfo: [
                "utterance": utterance,
                "source": source,
                "result": result
            ]
        )
    }
    
    /// Handle TalkToMango transcript - parse command and trigger search
    static func handleTalkToMangoTranscript(_ text: String) {
        let command = MangoCommandParser.shared.parse(text)

        guard command.isValid, let moviePhrase = command.movieTitle else {
            print("❌ Mango command invalid: \(text)")
            return
        }
        
        print("🍋 Mango parsed movie search: \(moviePhrase)")
        if let recommender = command.recommender {
            print("   Recommender: \(recommender)")
        }
        
        // Trigger global search
        Task { @MainActor in
            SearchViewModel.shared.search(query: moviePhrase)

            // Tell UI to open Search tab
            NotificationCenter.default.post(
                name: .mangoNavigateToSearch,
                object: moviePhrase
            )
        }
    }
}

extension Notification.Name {
    static let mangoNavigateToSearch = Notification.Name("mangoNavigateToSearch")
    static let mangoOpenMoviePage = Notification.Name("mangoOpenMoviePage")
}


