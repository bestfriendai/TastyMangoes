//  VoiceIntentRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 09:45 PST (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-05 at 20:26 (America/Los_Angeles - Pacific Time)
//  Notes: Added handleSortListCommand - processes "sort this list by X" commands when invoked from WatchlistView. Added list context tracking (masterlist/customList) and sort notification system.

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
    
    // Current movie context - set when Mango is invoked from MoviePageView
    private static var currentMovieId: String? = nil
    private static let currentMovieIdQueue = DispatchQueue(label: "com.tastymangoes.voiceintent.currentmovie")
    
    // Current list context - set when Mango is invoked from WatchlistView or IndividualListView
    enum ListType {
        case masterlist
        case customList
    }
    private static var currentListId: String? = nil
    private static var currentListType: ListType? = nil
    private static let currentListQueue = DispatchQueue(label: "com.tastymangoes.voiceintent.currentlist")
    
    /// Set the current movie ID when Mango is invoked from MoviePageView
    static func setCurrentMovieId(_ movieId: String?) {
        currentMovieIdQueue.sync {
            currentMovieId = movieId
            if let id = movieId {
                print("🎬 [VoiceIntentRouter] Set current movie context: \(id)")
            } else {
                print("🎬 [VoiceIntentRouter] Cleared current movie context")
            }
        }
    }
    
    /// Get the current movie ID (if any)
    private static func getCurrentMovieId() -> String? {
        return currentMovieIdQueue.sync {
            return currentMovieId
        }
    }
    
    /// Set the current list context when Mango is invoked from a list view
    static func setCurrentListContext(listId: String?, listType: ListType?) {
        currentListQueue.sync {
            currentListId = listId
            currentListType = listType
            if let id = listId, let type = listType {
                print("📋 [VoiceIntentRouter] Set current list context: \(id) (\(type))")
            } else {
                print("📋 [VoiceIntentRouter] Cleared current list context")
            }
        }
    }
    
    /// Get the current list context (if any)
    private static func getCurrentListContext() -> (listId: String, listType: ListType)? {
        return currentListQueue.sync {
            guard let id = currentListId, let type = currentListType else {
                return nil
            }
            return (id, type)
        }
    }
    
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
        
        // Step 1.6: Handle "add this movie to <ListName>" command locally (no LLM needed)
        // Only process if we have a current movie context (Mango invoked from MoviePageView)
        if let currentMovieId = getCurrentMovieId() {
            if await handleAddThisMovieToListCommand(transcript: text, currentMovieId: currentMovieId) {
                // Command was recognized and handled - clear context and return
                setCurrentMovieId(nil)
                return // Early return - no LLM call needed
            }
        }
        
        // Step 1.7: Handle "sort this list by X" command locally (no LLM needed)
        // Only process if we have a current list context (Mango invoked from WatchlistView)
        if let listContext = getCurrentListContext() {
            if await handleSortListCommand(transcript: text, listId: listContext.listId, listType: listContext.listType) {
                // Command was recognized and handled - return (don't clear context, user might sort again)
                return // Early return - no LLM call needed
            }
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
    
    /// Handle "add this movie to <ListName>" command locally
    /// Returns true if the command was recognized and handled, false otherwise
    private static func handleAddThisMovieToListCommand(transcript: String, currentMovieId: String) async -> Bool {
        let lower = transcript.lowercased()
        
        // Patterns to match (case-insensitive)
        let patterns = [
            "add this movie to",
            "add this to",
            "put this movie in",
            "put this in",
            "add this movie to my",
            "add this to my",
            "put this movie in my",
            "put this in my"
        ]
        
        var targetListName: String? = nil
        
        // Try to match each pattern
        for pattern in patterns {
            if let range = lower.range(of: pattern) {
                // Extract everything after the pattern
                let afterPattern = String(transcript[range.upperBound...])
                let trimmed = afterPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove trailing punctuation and filler words
                var cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
                cleaned = cleaned.replacingOccurrences(of: " list", with: "", options: .caseInsensitive)
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleaned.isEmpty {
                    targetListName = cleaned
                    break
                }
            }
        }
        
        guard let listName = targetListName else {
            // No pattern matched - not an "add this movie" command
            return false
        }
        
        print("🎬 [Mango] Detected 'add this movie' command - movie: \(currentMovieId), target list: '\(listName)'")
        
        await MainActor.run {
            let watchlistManager = WatchlistManager.shared
            
            // Find watchlist by name (case-insensitive)
            let allWatchlists = watchlistManager.getAllWatchlists()
            let matchingWatchlist = allWatchlists.first { watchlist in
                watchlist.name.localizedCaseInsensitiveCompare(listName) == .orderedSame
            }
            
            guard let watchlist = matchingWatchlist else {
                print("❌ [Mango] Could not find watchlist named '\(listName)'")
                MangoSpeaker.shared.speak("I couldn't find a list called \(listName).")
                return
            }
            
            // Add movie to the list using existing function
            let wasAdded = watchlistManager.addMovieToList(movieId: currentMovieId, listId: watchlist.id)
            
            if wasAdded {
                print("✅ [Mango] Added movie \(currentMovieId) to list '\(watchlist.name)' (ID: \(watchlist.id))")
                MangoSpeaker.shared.speak("Added this movie to \(watchlist.name).")
                
                // Post notification for UI confirmation/toast
                NotificationCenter.default.post(
                    name: NSNotification.Name("MangoAddedMovieToList"),
                    object: nil,
                    userInfo: [
                        "movieId": currentMovieId,
                        "listName": watchlist.name,
                        "listId": watchlist.id
                    ]
                )
            } else {
                print("ℹ️ [Mango] Movie \(currentMovieId) is already in list '\(watchlist.name)'")
                MangoSpeaker.shared.speak("This movie is already in \(watchlist.name).")
            }
        }
        
        return true // Command was recognized and handled
    }
    
    /// Handle "sort this list by X" command locally
    /// Returns true if the command was recognized and handled, false otherwise
    private static func handleSortListCommand(transcript: String, listId: String, listType: ListType) async -> Bool {
        let lower = transcript.lowercased()
        
        // Check if transcript contains "sort"
        guard lower.contains("sort") else {
            return false
        }
        
        // Patterns to match sort keys
        var sortKey: String? = nil
        var sortDirection: String? = nil
        
        // Detect sort key
        if lower.contains("by year") || lower.contains("year") {
            sortKey = "Year"
            // Check for direction
            if lower.contains("oldest") || lower.contains("earliest") {
                sortDirection = "Oldest First"
            } else if lower.contains("newest") || lower.contains("latest") {
                sortDirection = "Newest First"
            }
        } else if lower.contains("by genre") || lower.contains("genre") {
            sortKey = "Genre"
        } else if lower.contains("by title") || lower.contains("title") || lower.contains("alphabetical") {
            sortKey = "Title"
        } else if lower.contains("by rating") || lower.contains("rating") {
            // Check if it's Tasty Score or AI Score
            if lower.contains("tasty") {
                sortKey = "Tasty Score"
            } else if lower.contains("ai") {
                sortKey = "AI Score"
            } else {
                // Default to Tasty Score for "rating"
                sortKey = "Tasty Score"
            }
            // Check for direction
            if lower.contains("highest") || lower.contains("best") {
                sortDirection = "Highest"
            } else if lower.contains("lowest") || lower.contains("worst") {
                sortDirection = "Lowest"
            }
        } else if lower.contains("tasty score") || lower.contains("tasty") {
            sortKey = "Tasty Score"
            if lower.contains("highest") || lower.contains("best") {
                sortDirection = "Highest"
            }
        } else if lower.contains("ai score") || lower.contains("ai") {
            sortKey = "AI Score"
            if lower.contains("highest") || lower.contains("best") {
                sortDirection = "Highest"
            }
        } else if lower.contains("watched") {
            sortKey = "Watched"
        }
        
        guard let key = sortKey else {
            // No recognized sort key - not a sort command
            return false
        }
        
        // Build final sort string
        var finalSortBy = key
        if let direction = sortDirection {
            finalSortBy = "\(key) \(direction)"
        }
        
        print("🔀 [Mango] Detected sort command - list: \(listId) (\(listType)), sort: '\(finalSortBy)'")
        
        await MainActor.run {
            // Post notification to apply sort
            NotificationCenter.default.post(
                name: NSNotification.Name("MangoSortListCommand"),
                object: nil,
                userInfo: [
                    "listId": listId,
                    "listType": listType,
                    "sortBy": finalSortBy
                ]
            )
            
            // Speak confirmation
            let confirmationText = sortDirection != nil ? "Sorted by \(key.lowercased()), \(sortDirection!.lowercased())." : "Sorted by \(key.lowercased())."
            MangoSpeaker.shared.speak(confirmationText)
        }
        
        return true // Command was recognized and handled
    }
}

extension Notification.Name {
    static let mangoNavigateToSearch = Notification.Name("mangoNavigateToSearch")
    static let mangoOpenMoviePage = Notification.Name("mangoOpenMoviePage")
    static let mangoPerformMovieQuery = Notification.Name("mangoPerformMovieQuery")
    static let mangoCreatedWatchlist = Notification.Name("MangoCreatedWatchlist")
}


