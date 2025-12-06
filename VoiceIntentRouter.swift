//  VoiceIntentRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 09:45 PST (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-05 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Added duplicate transcript prevention to avoid processing same command multiple times. Added handleCreateWatchlistCommand for local list creation.

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
    
    // Track if we've already logged the "not configured" message this session
    private static var hasLoggedNotConfigured = false
    
    // Track processed transcripts to prevent duplicate handling
    private static var processedTranscripts: Set<String> = []
    private static let processedTranscriptsQueue = DispatchQueue(label: "com.tastymangoes.voiceintent.processed")
    
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
        // Prevent duplicate processing of the same transcript
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let alreadyProcessed = processedTranscriptsQueue.sync {
            if processedTranscripts.contains(normalizedText) {
                return true
            }
            processedTranscripts.insert(normalizedText)
            // Clean up old entries after 10 seconds to prevent memory growth
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                processedTranscriptsQueue.async {
                    processedTranscripts.remove(normalizedText)
                }
            }
            return false
        }
        
        if alreadyProcessed {
            print("⚠️ [VoiceIntentRouter] Skipping duplicate transcript: '\(text)'")
            return
        }
        
        print("🎙 [VoiceIntentRouter] Processing transcript: '\(text)'")
        
        // Step 1: Try MangoCommand parser first
        let mangoCommand = MangoCommandParser.shared.parse(text)
        var finalCommand: MangoCommand = mangoCommand
        var llmUsed = false
        var llmIntent: LLMIntent? = nil
        var llmError: Error? = nil
        
        // Step 1.5: Handle create watchlist command locally (no LLM needed)
        if case .createWatchlist(let listName, _) = mangoCommand {
            await handleCreateWatchlistCommand(listName: listName, rawText: text)
            return // Early return - no LLM call needed
        }
        
        // Step 2: If parser returned unknown, try LLM fallback
        if case .unknown = mangoCommand {
            // Check if OpenAI is configured before attempting call
            if !OpenAIClient.isConfigured {
                // Log once per session, then silently fall back
                if !hasLoggedNotConfigured {
                    print("🤖 [LLM] OpenAI not configured, skipping LLM classification")
                    hasLoggedNotConfigured = true
                }
                // Fall back to movie search
                finalCommand = .movieSearch(query: text, raw: text)
            } else {
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
                } catch OpenAIError.notConfigured {
                    // Handle notConfigured error quietly (shouldn't happen if isConfigured check passed, but defensive)
                    if !hasLoggedNotConfigured {
                        print("🤖 [LLM] OpenAI not configured, skipping LLM classification")
                        hasLoggedNotConfigured = true
                    }
                    llmError = OpenAIError.notConfigured
                    // Fallback to movie search
                    finalCommand = .movieSearch(query: text, raw: text)
                } catch {
                    llmError = error
                    print("❌ [LLM] OpenAI call failed: \(error.localizedDescription)")
                    // Fallback to movie search on error
                    finalCommand = .movieSearch(query: text, raw: text)
                    print("🤖 [LLM] Falling back to movieSearch due to error")
                }
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
    
    /// Handle create watchlist command locally
    private static func handleCreateWatchlistCommand(listName: String, rawText: String) async {
        print("📋 [Mango] Creating watchlist: '\(listName)'")
        
        await MainActor.run {
            // Create watchlist using existing WatchlistManager
            let watchlistManager = WatchlistManager.shared
            let newWatchlist = watchlistManager.createWatchlist(name: listName)
            
            print("✅ [Mango] Created watchlist: '\(newWatchlist.name)' (ID: \(newWatchlist.id))")
            
            // Speak confirmation
            MangoSpeaker.shared.speak("Created a new list called \(listName).")
            
            // Post notification for UI confirmation/toast
            NotificationCenter.default.post(
                name: NSNotification.Name("MangoCreatedWatchlist"),
                object: nil,
                userInfo: [
                    "listName": listName,
                    "listId": newWatchlist.id
                ]
            )
        }
    }
}

extension Notification.Name {
    static let mangoNavigateToSearch = Notification.Name("mangoNavigateToSearch")
    static let mangoOpenMoviePage = Notification.Name("mangoOpenMoviePage")
    static let mangoPerformMovieQuery = Notification.Name("mangoPerformMovieQuery")
    static let mangoCreatedWatchlist = Notification.Name("MangoCreatedWatchlist")
}


