//  VoiceIntentRouter.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 09:45 PST (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-15 at 20:45 (America/Los_Angeles - Pacific Time) / 04:45 UTC
//  Notes: Phase 3 - Added hint-based search path using HintSearchCoordinator.
//         When actor/director/year hints are present, uses AI discovery + batch ingestion
//         instead of simple TMDB search. Shows local results instantly, then AI results.

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
        
        // ═══════════════════════════════════════════════════════════════════════
        // Phase 2: Intent Classification and Hint Extraction
        // ═══════════════════════════════════════════════════════════════════════
        let searchIntent = SearchIntentClassifier.classify(text)
        let extractedHints = MovieHintExtractor.extract(from: text)
        let intentConfidence = SearchIntentClassifier.estimateConfidence(utterance: text, intent: searchIntent)
        
        print("🔍 [Phase2] Intent: \(searchIntent.rawValue), Confidence: \(String(format: "%.0f%%", intentConfidence * 100))")
        if let year = extractedHints.year {
            print("🔍 [Phase2] Extracted year: \(year)")
        }
        if !extractedHints.actors.isEmpty {
            print("🔍 [Phase2] Extracted actors: \(extractedHints.actors.joined(separator: ", "))")
        }
        if let director = extractedHints.director {
            print("🔍 [Phase2] Extracted director: \(director)")
        }
        if let title = extractedHints.titleLikely {
            print("🔍 [Phase2] Likely title: \(title)")
        }
        // ═══════════════════════════════════════════════════════════════════════
        
        // Step 1.5: Handle create watchlist command locally (no LLM needed)
        if case .createWatchlist(let listName, _) = mangoCommand {
            await handleCreateWatchlistCommand(listName: listName, rawText: text, searchIntent: searchIntent, confidence: intentConfidence, hints: extractedHints)
            return // Early return - no LLM call needed
        }
        
        // Step 1.6: Handle mark watched/unwatched command locally (no LLM needed)
        // Only process if we have a current movie context (Mango invoked from MoviePageView)
        if case .markWatched(let watched, _) = mangoCommand {
            if let currentMovieId = getCurrentMovieId() {
                await handleMarkWatchedCommand(watched: watched, movieId: currentMovieId, transcript: text, searchIntent: searchIntent, confidence: intentConfidence, hints: extractedHints)
                // Don't clear movie context - user might want to do more actions
                return // Early return - no LLM call needed
            } else {
                // No movie context - log parse error
                let eventId = await VoiceAnalyticsLogger.shared.log(
                    utterance: text,
                    mangoCommand: mangoCommand,
                    llmUsed: false,
                    finalCommand: mangoCommand,
                    llmIntent: nil,
                    llmError: nil,
                    searchIntent: searchIntent,
                    confidenceScore: intentConfidence,
                    extractedHints: extractedHints
                )
                
                // Update event with parse error
                if let eventId = eventId {
                    Task {
                        await VoiceAnalyticsLogger.updateVoiceEventResult(
                            eventId: eventId,
                            result: "parse_error",
                            errorMessage: "No movie context - user not on movie page"
                        )
                        
                        // Trigger self-healing for parse errors
                        VoiceIntentRouter.checkAndTriggerSelfHealing(
                            utterance: text,
                            originalCommand: .markWatched(watched: true, raw: text),
                            handlerResult: .parseError,
                            screen: "MoviePageView",
                            movieContext: nil,
                            voiceEventId: eventId
                        )
                    }
                }
                
                await MainActor.run {
                    MangoSpeaker.shared.speak("Please open a movie first, then tell me to mark it as watched.")
                }
                return
            }
        }
        
        // Step 1.7: Handle "add this movie to <ListName>" command locally (no LLM needed)
        // Only process if we have a current movie context (Mango invoked from MoviePageView)
        if let currentMovieId = getCurrentMovieId() {
            if await handleAddThisMovieToListCommand(transcript: text, currentMovieId: currentMovieId, searchIntent: searchIntent, confidence: intentConfidence, hints: extractedHints) {
                // Command was recognized and handled - clear context and return
                setCurrentMovieId(nil)
                return // Early return - no LLM call needed
            }
        }
        
        // Step 1.8: Handle "sort this list by X" command locally (no LLM needed)
        // Only process if we have a current list context (Mango invoked from WatchlistView)
        if let listContext = getCurrentListContext() {
            if await handleSortListCommand(transcript: text, listId: listContext.listId, listType: listContext.listType, searchIntent: searchIntent, confidence: intentConfidence, hints: extractedHints) {
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
                           let rawRecommender = intent.recommender, !rawRecommender.isEmpty {
                            // Normalize recommender name (e.g., "Kyo" -> "Keo", "hyatt" -> "Hayat")
                            let recommender = RecommenderNormalizer.normalize(rawRecommender) ?? rawRecommender.capitalized
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
            
            // Log failed attempt with Phase 2 data
            await VoiceAnalyticsLogger.shared.log(
                utterance: text,
                mangoCommand: mangoCommand,
                llmUsed: llmUsed,
                finalCommand: finalCommand,
                llmIntent: llmIntent,
                llmError: llmError,
                searchIntent: searchIntent,
                confidenceScore: intentConfidence,
                extractedHints: extractedHints
            )
            return
        }
        
        print("🍋 Final command - movie search: \(moviePhrase)")
        if let recommender = finalCommand.recommender {
            print("🍋 Final command - recommender: \(recommender)")
        }
        
        // ═══════════════════════════════════════════════════════════════════════
        // Phase 3: Hint-Based Search Path
        // If hints are present (actor, director, year), use HintSearchCoordinator
        // for local-first + AI discovery + batch ingestion
        // ═══════════════════════════════════════════════════════════════════════
        if extractedHints.hasAnyHints {
            print("🎬 [Phase3] Hints detected - using HintSearchCoordinator path")
            await handleHintBasedSearch(
                query: text,
                moviePhrase: moviePhrase,
                extractedHints: extractedHints,
                searchIntent: searchIntent,
                confidence: intentConfidence,
                finalCommand: finalCommand,
                mangoCommand: mangoCommand,
                llmUsed: llmUsed,
                llmIntent: llmIntent,
                llmError: llmError
            )
            return
        }
        // ═══════════════════════════════════════════════════════════════════════
        
        // Standard path: No hints - use existing notification-based search
        await handleStandardSearch(
            text: text,
            moviePhrase: moviePhrase,
            finalCommand: finalCommand,
            mangoCommand: mangoCommand,
            llmUsed: llmUsed,
            llmIntent: llmIntent,
            llmError: llmError,
            searchIntent: searchIntent,
            confidence: intentConfidence,
            extractedHints: extractedHints
        )
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Phase 3: Hint-Based Search
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Handle search with extracted hints using HintSearchCoordinator
    /// This path provides: local results instantly → AI discovery → batch ingestion
    private static func handleHintBasedSearch(
        query: String,
        moviePhrase: String,
        extractedHints: ExtractedHints,
        searchIntent: VoiceSearchIntent,
        confidence: Double,
        finalCommand: MangoCommand,
        mangoCommand: MangoCommand,
        llmUsed: Bool,
        llmIntent: LLMIntent?,
        llmError: Error?
    ) async {
        print("🎬 [Phase3] Starting hint-based search for: '\(query)'")
        print("🎬 [Phase3] Hints: actors=\(extractedHints.actors), director=\(extractedHints.director ?? "nil"), year=\(extractedHints.year?.description ?? "nil")")
        
        // Store recommender in FilterState for AddToListView
        await MainActor.run {
            SearchFilterState.shared.detectedRecommender = finalCommand.recommender
            if let recommender = finalCommand.recommender {
                print("🍋 Stored recommender '\(recommender)' in SearchFilterState for AddToListView")
            }
            
            // Navigate to Search tab first
            print("🍋 [Phase3] Posting mangoNavigateToSearch notification")
            NotificationCenter.default.post(
                name: .mangoNavigateToSearch,
                object: nil
            )
            
            // Speak initial acknowledgment
            MangoSpeaker.shared.speak("Let me search for that.")
        }
        
        // Log the interaction with Phase 2 data
        let eventId = await VoiceAnalyticsLogger.shared.log(
            utterance: query,
            mangoCommand: mangoCommand,
            llmUsed: llmUsed,
            finalCommand: finalCommand,
            llmIntent: llmIntent,
            llmError: llmError,
            searchIntent: searchIntent,
            confidenceScore: confidence,
            extractedHints: extractedHints
        )
        
        // Convert ExtractedHints to ExtractedMovieHints for coordinator
        let hints = ExtractedMovieHints(from: extractedHints)
        
        do {
            // Call HintSearchCoordinator for local + AI search
            // Swift automatically handles MainActor hop for async method calls
            let response = try await HintSearchCoordinator.shared.search(query: query, hints: hints, enableAI: true)
            
            let localCount = response.localResults.count
            let totalCount = response.allResults.count
            let newlyIngested = response.newlyIngested
            
            print("🎬 [Phase3] Search complete: \(localCount) local, \(totalCount) total, \(newlyIngested) newly ingested")
            
            // Convert HintSearchResults to Movies for SearchViewModel
            let movies = response.allResults.map { result in
                Movie(
                    id: String(result.tmdbId),
                    title: result.title,
                    year: result.year ?? 0,
                    trailerURL: nil,
                    trailerDuration: nil,
                    posterImageURL: result.posterURL,
                    tastyScore: nil,
                    aiScore: nil,
                    genres: [],
                    rating: nil,
                    director: nil,
                    writer: nil,
                    screenplay: nil,
                    composer: nil,
                    runtime: nil,
                    releaseDate: result.year != nil ? String(result.year!) : nil,
                    language: nil,
                    overview: result.matchReason
                )
            }
            
            // Update SearchViewModel with results
            await MainActor.run {
                let viewModel = SearchViewModel.shared
                viewModel.searchQuery = moviePhrase
                viewModel.searchResults = movies
                viewModel.hasSearched = true
                viewModel.isSearching = false
                viewModel.isMangoInitiatedSearch = true
                
                // Store voice event ID for selection tracking
                SearchFilterState.shared.pendingVoiceEventId = eventId
                SearchFilterState.shared.pendingVoiceUtterance = query
                SearchFilterState.shared.pendingVoiceCommand = finalCommand
                
                // Speak results summary
                if totalCount == 0 {
                    MangoSpeaker.shared.speak("I couldn't find any movies matching that.")
                } else if totalCount == 1 {
                    let movie = response.allResults.first!
                    MangoSpeaker.shared.speak("I found \(movie.title).")
                } else if newlyIngested > 0 {
                    MangoSpeaker.shared.speak("Found \(totalCount) movies. I added \(newlyIngested) new ones to our database.")
                } else {
                    MangoSpeaker.shared.speak("Found \(totalCount) movies.")
                }
            }
            
            // Update voice event with success
            if let eventId = eventId {
                let result: String
                if totalCount == 0 {
                    result = "no_results"
                } else if totalCount >= 10 {
                    result = "ambiguous"
                } else {
                    result = "success"
                }
                
                await VoiceAnalyticsLogger.updateVoiceEventResult(
                    eventId: eventId,
                    result: result,
                    resultCount: totalCount
                )
            }
            
        } catch {
            print("❌ [Phase3] HintSearchCoordinator error: \(error)")
            
            // Fall back to standard search on error
            await MainActor.run {
                MangoSpeaker.shared.speak("Let me try a different approach.")
            }
            
            // Use standard search as fallback
            await handleStandardSearch(
                text: query,
                moviePhrase: moviePhrase,
                finalCommand: finalCommand,
                mangoCommand: mangoCommand,
                llmUsed: llmUsed,
                llmIntent: llmIntent,
                llmError: error,
                searchIntent: searchIntent,
                confidence: confidence,
                extractedHints: extractedHints
            )
        }
    }
    
    /// Standard search path using notification-based flow (existing behavior)
    private static func handleStandardSearch(
        text: String,
        moviePhrase: String,
        finalCommand: MangoCommand,
        mangoCommand: MangoCommand,
        llmUsed: Bool,
        llmIntent: LLMIntent?,
        llmError: Error?,
        searchIntent: VoiceSearchIntent,
        confidence: Double,
        extractedHints: ExtractedHints
    ) async {
        // Store recommender in FilterState for AddToListView
        await MainActor.run {
            SearchFilterState.shared.detectedRecommender = finalCommand.recommender
            if let recommender = finalCommand.recommender {
                print("🍋 Stored recommender '\(recommender)' in SearchFilterState for AddToListView")
            }
            
            // Store pending query in SearchFilterState (reliable path for race condition fix)
            SearchFilterState.shared.pendingMangoQuery = moviePhrase
            print("🍋 Stored pending Mango query '\(moviePhrase)' in SearchFilterState")
            
            // Mango speaks acknowledgment
            MangoSpeaker.shared.speak("Let me check on that for you.")
            
            // Step 1: Navigate to Search tab first
            print("🍋 Posting mangoNavigateToSearch notification to switch to Search tab")
            NotificationCenter.default.post(
                name: .mangoNavigateToSearch,
                object: nil
            )
            
            // Step 2: Post notification to trigger search (SearchViewModel will handle it)
            // Keep notification for backward compatibility, but pendingMangoQuery is the reliable path
            print("🍋 Posting mangoPerformMovieQuery notification with query: '\(moviePhrase)'")
            NotificationCenter.default.post(
                name: .mangoPerformMovieQuery,
                object: moviePhrase
            )
        }
        
        // Step 4: Log the interaction with Phase 2 data and store eventId for result tracking
        let eventId = await VoiceAnalyticsLogger.shared.log(
            utterance: text,
            mangoCommand: mangoCommand,
            llmUsed: llmUsed,
            finalCommand: finalCommand,
            llmIntent: llmIntent,
            llmError: llmError,
            searchIntent: searchIntent,
            confidenceScore: confidence,
            extractedHints: extractedHints
        )
        
        // Store eventId, original utterance, and command in SearchFilterState so SearchViewModel can update it after search completes
        if let eventId = eventId {
            await MainActor.run {
                SearchFilterState.shared.pendingVoiceEventId = eventId
                SearchFilterState.shared.pendingVoiceUtterance = text // Store original utterance for self-healing
                SearchFilterState.shared.pendingVoiceCommand = finalCommand // Store original command for self-healing
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Command Handlers (existing)
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// Handle create watchlist command locally
    private static func handleCreateWatchlistCommand(listName: String, rawText: String, searchIntent: VoiceSearchIntent, confidence: Double, hints: ExtractedHints) async {
        print("📋 [Mango] Creating watchlist: '\(listName)'")
        
        // Log the command with Phase 2 data
        let eventId = await VoiceAnalyticsLogger.shared.log(
            utterance: rawText,
            mangoCommand: .createWatchlist(listName: listName, raw: rawText),
            llmUsed: false,
            finalCommand: .createWatchlist(listName: listName, raw: rawText),
            llmIntent: nil,
            llmError: nil,
            searchIntent: searchIntent,
            confidenceScore: confidence,
            extractedHints: hints
        )
        
        let watchlistManager = WatchlistManager.shared
        
        // Create watchlist in Supabase
        do {
            let newWatchlist = try await watchlistManager.createWatchlistAsync(name: listName)
            print("✅ [Mango] Created watchlist: '\(newWatchlist.name)' (ID: \(newWatchlist.id))")
            
            // Update voice event with success
            if let eventId = eventId {
                Task {
                    await VoiceAnalyticsLogger.updateVoiceEventResult(
                        eventId: eventId,
                        result: "success",
                        resultCount: 1
                    )
                }
            }
            
            await MainActor.run {
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
        } catch {
            print("❌ [Mango] Error creating watchlist: \(error)")
            // Fallback to local-only creation
            await MainActor.run {
                let newWatchlist = watchlistManager.createWatchlist(name: listName)
                print("⚠️ [Mango] Created watchlist locally only (Supabase sync failed): '\(newWatchlist.name)'")
                
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
            
            // Update voice event with success (local creation worked)
            if let eventId = eventId {
                Task {
                    await VoiceAnalyticsLogger.updateVoiceEventResult(
                        eventId: eventId,
                        result: "success",
                        resultCount: 1
                    )
                }
            }
        }
    }
    
    /// Handle mark watched/unwatched command locally
    private static func handleMarkWatchedCommand(watched: Bool, movieId: String, transcript: String, searchIntent: VoiceSearchIntent, confidence: Double, hints: ExtractedHints) async {
        let action = watched ? "watched" : "unwatched"
        print("👁 [Mango] Marking movie \(movieId) as \(action)")
        
        // Log the command with Phase 2 data
        let eventId = await VoiceAnalyticsLogger.shared.log(
            utterance: transcript,
            mangoCommand: .markWatched(watched: watched, raw: transcript),
            llmUsed: false,
            finalCommand: .markWatched(watched: watched, raw: transcript),
            llmIntent: nil,
            llmError: nil,
            searchIntent: searchIntent,
            confidenceScore: confidence,
            extractedHints: hints
        )
        
        await MainActor.run {
            let watchlistManager = WatchlistManager.shared
            
            if watched {
                watchlistManager.markAsWatched(movieId: movieId)
            } else {
                watchlistManager.markAsNotWatched(movieId: movieId)            }
            
            print("✅ [Mango] Marked movie \(movieId) as \(action)")
            
            // Speak confirmation
            let confirmationText = watched ? "Marked as watched." : "Marked as unwatched."
            MangoSpeaker.shared.speak(confirmationText)
            
            // Post notification for UI update
            NotificationCenter.default.post(
                name: NSNotification.Name("MangoMarkedWatched"),
                object: nil,
                userInfo: [
                    "movieId": movieId,
                    "watched": watched
                ]
            )
        }
        
        // Update voice event with success result
        if let eventId = eventId {
            Task {
                await VoiceAnalyticsLogger.updateVoiceEventResult(
                    eventId: eventId,
                    result: "success",
                    resultCount: 1
                )
                
                // Check for potential misclassification after successful execution
                await SelfHealingVoiceService.shared.checkForMisclassification(
                    transcript: transcript,
                    executedCommand: .markWatched(watched: watched, raw: transcript),
                    voiceEventId: eventId
                )
            }
        }
    }
    
    /// Handle "add this movie to <ListName>" command locally
    /// Returns true if the command was recognized and handled, false otherwise
    private static func handleAddThisMovieToListCommand(transcript: String, currentMovieId: String, searchIntent: VoiceSearchIntent, confidence: Double, hints: ExtractedHints) async -> Bool {
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
        
        // Log the command with Phase 2 data
        let eventId = await VoiceAnalyticsLogger.shared.log(
            utterance: transcript,
            mangoCommand: .unknown(raw: transcript), // No specific MangoCommand for this yet
            llmUsed: false,
            finalCommand: .unknown(raw: transcript),
            llmIntent: nil,
            llmError: nil,
            searchIntent: searchIntent,
            confidenceScore: confidence,
            extractedHints: hints
        )
        
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
                
                // Update voice event with no_results
                if let eventId = eventId {
                    Task {
                        await VoiceAnalyticsLogger.updateVoiceEventResult(
                            eventId: eventId,
                            result: "no_results",
                            errorMessage: "Watchlist not found: \(listName)"
                        )
                    }
                }
                return
            }
            
            // Add movie to the list using existing function
            let wasAdded = watchlistManager.addMovieToList(movieId: currentMovieId, listId: watchlist.id)
            
            if wasAdded {
                print("✅ [Mango] Added movie \(currentMovieId) to list '\(watchlist.name)' (ID: \(watchlist.id))")
                MangoSpeaker.shared.speak("Added this movie to \(watchlist.name).")
                
                // Update voice event with success
                if let eventId = eventId {
                    Task {
                        await VoiceAnalyticsLogger.updateVoiceEventResult(
                            eventId: eventId,
                            result: "success",
                            resultCount: 1
                        )
                    }
                }
                
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
                
                // Update voice event with success (duplicate is not an error)
                if let eventId = eventId {
                    Task {
                        await VoiceAnalyticsLogger.updateVoiceEventResult(
                            eventId: eventId,
                            result: "success",
                            resultCount: 0 // 0 indicates already existed
                        )
                    }
                }
            }
        }
        
        return true // Command was recognized and handled
    }
    
    /// Handle "sort this list by X" command locally
    /// Returns true if the command was recognized and handled, false otherwise
    private static func handleSortListCommand(transcript: String, listId: String, listType: ListType, searchIntent: VoiceSearchIntent, confidence: Double, hints: ExtractedHints) async -> Bool {
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
        
        // Log the command with Phase 2 data
        let eventId = await VoiceAnalyticsLogger.shared.log(
            utterance: transcript,
            mangoCommand: .unknown(raw: transcript), // No specific MangoCommand for sort yet
            llmUsed: false,
            finalCommand: .unknown(raw: transcript),
            llmIntent: nil,
            llmError: nil,
            searchIntent: searchIntent,
            confidenceScore: confidence,
            extractedHints: hints
        )
        
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
        
        // Update voice event with success
        if let eventId = eventId {
            Task {
                await VoiceAnalyticsLogger.updateVoiceEventResult(
                    eventId: eventId,
                    result: "success",
                    resultCount: 1
                )
            }
        }
        
        return true // Command was recognized and handled
    }
    
    // MARK: - Self-Healing Voice System
    
    /// Checks if self-healing should trigger based on utterance, command type, and result
    private static func shouldTriggerSelfHealing(utterance: String, result: String?, commandType: String) -> Bool {
        let actionWords = ["watch", "watched", "add", "remove", "mark", "list", "delete", "save"]
        let lowerUtterance = utterance.lowercased()
        let hasActionWord = actionWords.contains { lowerUtterance.contains($0) }
        
        // Trigger if: no_results + has action word, OR classified as search but has action word
        return (result == "no_results" && hasActionWord) ||
               (commandType == "movie_search" && hasActionWord)
    }
    
    /// Checks if self-healing should trigger and calls the service if needed
    /// This is called from VoiceIntentRouter for non-search commands
    private static func checkAndTriggerSelfHealing(
        utterance: String,
        commandType: String,
        result: String?,
        voiceEventId: UUID?
    ) async {
        await checkAndTriggerSelfHealingForSearch(
            utterance: utterance,
            commandType: commandType,
            result: result,
            voiceEventId: voiceEventId
        )
    }
    
    /// Checks if self-healing should trigger and calls the service if needed
    /// This is called from SearchViewModel for search commands
    static func checkAndTriggerSelfHealingForSearch(
        utterance: String,
        commandType: String,
        result: String?,
        voiceEventId: UUID?
    ) async {
        guard shouldTriggerSelfHealing(utterance: utterance, result: result, commandType: commandType) else {
            return
        }
        
        // Infer screen context from current state
        let screen: String
        let movieContext: String?
        
        if let _ = getCurrentMovieId() {
            screen = "MoviePageView"
            // We don't have the movie title here, so leave it nil
            // In a real implementation, you might want to fetch it or pass it through
            movieContext = nil
        } else if let _ = getCurrentListContext() {
            screen = "WatchlistView"
            movieContext = nil
        } else {
            screen = "SearchView" // Default assumption for search commands
            movieContext = nil
        }
        
        print("🔧 [VoiceIntentRouter] Triggering self-healing for utterance: '\(utterance)'")
        
        await SelfHealingVoiceService.shared.analyzeAndLogPattern(
            utterance: utterance,
            commandType: commandType,
            screen: screen,
            movieContext: movieContext,
            voiceEventId: voiceEventId
        )
    }
}

// Notification names are now defined in NotificationNames.swift
