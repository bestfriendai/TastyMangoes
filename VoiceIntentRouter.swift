//  VoiceIntentRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 09:45 PST (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: Central router for handling voice utterances. Integrated OpenAI LLM fallback for unknown commands.

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
    
    // Dependency injection for OpenAI client (allows testing)
    static var openAIClient: OpenAIClient = .shared
    
    /// Handle a voice utterance from any source
    /// - Parameters:
    ///   - utterance: The transcribed text from the user
    ///   - source: Where the voice input came from
    static func handle(utterance: String, source: VoiceSource) {
        print("🎙 Voice utterance from \(source): \(utterance)")
        
        // Route TalkToMango utterances to specialized handler
        if source == .talkToMango {
            Task {
                await handleTalkToMangoTranscript(utterance)
            }
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
    
    /// Handle TalkToMango transcript - parse command and trigger search with LLM fallback
    static func handleTalkToMangoTranscript(_ text: String) async {
        // Step 1: Try MangoCommand parser first
        let mangoCommand = MangoCommandParser.shared.parse(text)
        var finalCommand: MangoCommand = mangoCommand
        var llmUsed = false
        var llmIntent: LLMIntent? = nil
        var llmError: Error? = nil
        
        // Step 2: If parser returned unknown, try LLM fallback
        if case .unknown = mangoCommand {
            print("🤖 [LLM] Mango parser returned unknown, trying OpenAI fallback...")
            
            do {
                let intent = try await openAIClient.classifyUtterance(text)
                llmUsed = true
                llmIntent = intent
                
                // Map LLM intent to MangoCommand
                switch intent.intent {
                case "recommender_search":
                    if let movie = intent.movieTitle, !movie.isEmpty,
                       let recommender = intent.recommender, !recommender.isEmpty {
                        finalCommand = .recommenderSearch(recommender: recommender, movie: movie, raw: text)
                        print("🤖 [LLM] Mapped to recommenderSearch: \(recommender) recommends \(movie)")
                    } else {
                        // Fallback to movie search if missing fields
                        finalCommand = .movieSearch(query: intent.movieTitle ?? text, raw: text)
                        print("🤖 [LLM] Missing fields, falling back to movieSearch")
                    }
                    
                case "movie_search":
                    finalCommand = .movieSearch(query: intent.movieTitle ?? text, raw: text)
                    print("🤖 [LLM] Mapped to movieSearch: \(intent.movieTitle ?? text)")
                    
                default: // "unknown"
                    // Last resort: treat as movie search
                    finalCommand = .movieSearch(query: text, raw: text)
                    print("🤖 [LLM] LLM returned unknown, falling back to movieSearch with raw text")
                }
            } catch {
                llmError = error
                print("❌ [LLM] OpenAI call failed: \(error.localizedDescription)")
                // Fallback to movie search on error
                finalCommand = .movieSearch(query: text, raw: text)
                print("🤖 [LLM] Falling back to movieSearch due to error")
            }
        }
        
        // Step 3: Execute the final command
        guard finalCommand.isValid, let moviePhrase = finalCommand.movieTitle else {
            print("❌ Final command invalid after LLM fallback: \(text)")
            await MainActor.run {
                MangoSpeaker.shared.speak("Sorry, I didn't quite catch that.")
            }
            
            // Log failed attempt
            await VoiceAnalyticsLogger.shared.log(
                utterance: text,
                mangoCommand: mangoCommand,
                llmUsed: llmUsed,
                finalCommand: finalCommand,
                llmIntent: llmIntent,
                llmError: llmError
            )
            return
        }
        
        print("🍋 Final command - movie search: \(moviePhrase)")
        if let recommender = finalCommand.recommender {
            print("🍋 Final command - recommender: \(recommender)")
        }
        
        // Store recommender in FilterState for AddToListView
        await MainActor.run {
            SearchFilterState.shared.detectedRecommender = finalCommand.recommender
            if let recommender = finalCommand.recommender {
                print("🍋 Stored recommender '\(recommender)' in SearchFilterState for AddToListView")
            }
            
            // Mango speaks acknowledgment
            MangoSpeaker.shared.speak("Let me check on that for you.")
            
            // Post notification to trigger search (SearchViewModel will handle it)
            NotificationCenter.default.post(
                name: .mangoPerformMovieQuery,
                object: moviePhrase
            )
        }
        
        // Step 4: Log the interaction
        await VoiceAnalyticsLogger.shared.log(
            utterance: text,
            mangoCommand: mangoCommand,
            llmUsed: llmUsed,
            finalCommand: finalCommand,
            llmIntent: llmIntent,
            llmError: llmError
        )
    }
}

extension Notification.Name {
    static let mangoNavigateToSearch = Notification.Name("mangoNavigateToSearch")
    static let mangoOpenMoviePage = Notification.Name("mangoOpenMoviePage")
    static let mangoPerformMovieQuery = Notification.Name("mangoPerformMovieQuery")
}


