//  SelfHealingVoiceService.swift
//  TastyMangoes
//
//  Created by Cursor Assistant on 2025-12-07 at 21:12 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-07 at 22:55 (America/Los_Angeles - Pacific Time)
//  Notes: Self-healing voice system that analyzes failed voice commands using OpenAI
//         and logs pattern suggestions to Supabase for review in the dashboard.
//         Merged Cursor's Supabase SDK usage with Claude's trigger detection logic.

import Foundation
import Supabase

// MARK: - Pattern Suggestion Model

struct PatternSuggestion: Codable {
    let utterance: String
    let original_command_type: String?
    let suggested_intent: String?
    let suggested_pattern: String?
    let confidence: Double?
    let source: String  // "llm"
    let status: String  // "pending"
    let voice_event_id: String?
    
    enum CodingKeys: String, CodingKey {
        case utterance
        case original_command_type
        case suggested_intent
        case suggested_pattern
        case confidence
        case source
        case status
        case voice_event_id
    }
}

// MARK: - LLM Self-Healing Response

private struct SelfHealingResponse: Codable {
    let intent: String
    let confidence: Double
    let reasoning: String
    let suggested_patterns: [String]
    
    enum CodingKeys: String, CodingKey {
        case intent
        case confidence
        case reasoning
        case suggested_patterns
    }
}

// MARK: - Self-Healing Voice Service

@MainActor
class SelfHealingVoiceService {
    static let shared = SelfHealingVoiceService()
    
    private var supabaseClient: SupabaseClient?
    private let openAIClient = OpenAIClient.shared
    
    private init() {
        setupSupabaseClient()
    }
    
    private func setupSupabaseClient() {
        guard let url = URL(string: SupabaseConfig.supabaseURL),
              !SupabaseConfig.supabaseAnonKey.isEmpty else {
            print("⚠️ [SelfHealing] Supabase not configured. Pattern suggestion logging disabled.")
            return
        }
        
        self.supabaseClient = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }
    
    // MARK: - Trigger Detection (Added by Claude)
    
    /// Action words that suggest the user wanted to perform an action, not search
    private static let actionWords: Set<String> = [
        "watch", "watched", "watching",
        "add", "added", "adding",
        "mark", "marked", "marking",
        "remove", "removed", "removing",
        "delete", "deleted", "deleting",
        "move", "moved", "moving",
        "save", "saved", "saving",
        "rate", "rated", "rating",
        "actually", "didn't", "did not", "haven't", "have not",
        "unwatched", "unwatch", "seen", "unseen"
    ]
    
    /// Check if utterance contains action words
    static func containsActionWords(_ utterance: String) -> Bool {
        let lowercased = utterance.lowercased()
        return actionWords.contains { lowercased.contains($0) }
    }
    
    /// Determine if self-healing should be triggered based on the command result
    /// Trigger conditions:
    /// 1. handler_result is "no_results" AND utterance contains action words
    /// 2. handler_result is "parse_error" AND utterance contains action words (parser understood it was an action but couldn't execute)
    /// 3. mango_command_type is "movie_search" but utterance has action words
    /// 4. Unknown command with action words
    static func shouldTriggerSelfHealing(
        utterance: String,
        commandType: MangoCommand,
        handlerResult: VoiceHandlerResult?
    ) -> Bool {
        let hasActionWords = containsActionWords(utterance)
        
        // Condition 1: No results but looks like an action
        if handlerResult == .noResults && hasActionWords {
            print("🔄 [SelfHealing] Trigger: no_results + action words detected")
            return true
        }
        
        // Condition 2: Parse error but looks like an action (parser understood it was an action command but couldn't execute it)
        if handlerResult == .parseError && hasActionWords {
            print("🔄 [SelfHealing] Trigger: parse_error + action words detected")
            return true
        }
        
        // Condition 3: Classified as movie_search but has action words
        if case .movieSearch = commandType, hasActionWords {
            print("🔄 [SelfHealing] Trigger: movie_search with action words detected")
            return true
        }
        
        // Condition 4: Unknown command with action words
        if case .unknown = commandType, hasActionWords {
            print("🔄 [SelfHealing] Trigger: unknown command with action words detected")
            return true
        }
        
        return false
    }
    
    // MARK: - Main Entry Point
    
    /// Analyzes a failed voice utterance and logs pattern suggestions to Supabase
    /// - Parameters:
    ///   - utterance: The original voice utterance that failed
    ///   - commandType: The command type that was attempted (e.g., "movie_search", "unknown")
    ///   - screen: The current screen context (e.g., "MoviePageView", "WatchlistView", "SearchView")
    ///   - movieContext: Optional movie title if user was on a movie page
    ///   - voiceEventId: Optional UUID of the original voice event for linking
    func analyzeAndLogPattern(
        utterance: String,
        commandType: String,
        screen: String,
        movieContext: String? = nil,
        voiceEventId: UUID? = nil
    ) async {
        print("🔧 [SelfHealing] Analyzing failed utterance: '\(utterance)'")
        print("🔧 [SelfHealing] Context - Screen: \(screen), Movie: \(movieContext ?? "none"), Command: \(commandType)")
        
        // Build context string
        var contextString = "They were on the \(screen) screen."
        if let movie = movieContext, !movie.isEmpty {
            contextString += " They were viewing the movie '\(movie)'."
        }
        
        // Call OpenAI to analyze the intent
        do {
            let analysis = try await analyzeWithOpenAI(
                utterance: utterance,
                context: contextString
            )
            
            print("🔧 [SelfHealing] OpenAI analysis - Intent: \(analysis.intent), Confidence: \(analysis.confidence)")
            print("🔧 [SelfHealing] Reasoning: \(analysis.reasoning)")
            print("🔧 [SelfHealing] Suggested patterns: \(analysis.suggested_patterns)")
            
            // Log to Supabase
            await logPatternSuggestion(
                utterance: utterance,
                originalCommandType: commandType,
                suggestedIntent: analysis.intent,
                suggestedPatterns: analysis.suggested_patterns,
                confidence: analysis.confidence,
                voiceEventId: voiceEventId
            )
            
        } catch {
            print("❌ [SelfHealing] Failed to analyze utterance: \(error.localizedDescription)")
            // Still log to Supabase with minimal data so we can see the failed utterance
            await logPatternSuggestion(
                utterance: utterance,
                originalCommandType: commandType,
                suggestedIntent: nil,
                suggestedPatterns: [],
                confidence: nil,
                voiceEventId: voiceEventId
            )
        }
    }
    
    /// Convenience method that takes MangoCommand directly
    /// Call this from VoiceIntentRouter when trigger conditions are met
    func handleFailedCommand(
        utterance: String,
        originalCommand: MangoCommand,
        handlerResult: VoiceHandlerResult?,
        screen: String = "Unknown",
        movieContext: String? = nil,
        voiceEventId: UUID? = nil
    ) async {
        let commandType = commandTypeString(originalCommand)
        
        await analyzeAndLogPattern(
            utterance: utterance,
            commandType: commandType,
            screen: screen,
            movieContext: movieContext,
            voiceEventId: voiceEventId
        )
    }
    
    // MARK: - OpenAI Analysis
    
    /// Calls OpenAI to analyze the failed utterance
    private func analyzeWithOpenAI(utterance: String, context: String) async throws -> SelfHealingResponse {
        guard OpenAIClient.isConfigured else {
            throw OpenAIError.notConfigured
        }
        
        guard let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        let systemPrompt = """
        You are analyzing a failed voice command in a movie recommendation app called "Mango".
        
        A user said: "\(utterance)"
        Context: \(context)
        
        This was not understood by the voice parser. What did the user likely mean?
        
        Respond with ONLY a single JSON object, no prose, using this exact format:
        {
          "intent": "markWatched" | "markUnwatched" | "addToWatchlist" | "removeFromWatchlist" | "movieSearch" | "recommenderSearch" | "createWatchlist" | "unknown",
          "confidence": 0.0-1.0,
          "reasoning": "brief explanation of why you think this is the intent",
          "suggested_patterns": ["pattern1", "pattern2", ...] // lowercase phrases that should trigger this intent
        }
        
        Intent definitions:
        - "markWatched": User wants to mark a movie as watched (e.g., "I watched this", "mark as watched", "seen it", "just saw this")
        - "markUnwatched": User wants to mark a movie as NOT watched (e.g., "I didn't watch this", "mark as unwatched", "haven't seen it", "actually I haven't watched this")
        - "addToWatchlist": User wants to add a movie to a watchlist (e.g., "add to my list", "save this", "put in my watchlist")
        - "removeFromWatchlist": User wants to remove a movie from a list (e.g., "remove from list", "delete this", "take off my list")
        - "movieSearch": User wants to search for a movie by title
        - "recommenderSearch": User wants to search with attribution (e.g., "Keo recommends X", "my friend said to watch X")
        - "createWatchlist": User wants to create a new list (e.g., "create a list called X", "make new watchlist")
        - "unknown": Cannot determine intent with reasonable confidence
        
        Suggested patterns should be:
        - Lowercase phrases that would help the local parser recognize this intent
        - Flexible enough to catch variations (e.g., "i watched" catches "I watched this", "I watched it", etc.)
        - Common speech recognition mishearings (e.g., "mark has watched" instead of "mark as watched")
        
        Examples of good patterns:
        - For "markWatched": ["i watched", "mark as watched", "mark watched", "seen it", "just saw"]
        - For "markUnwatched": ["i didn't watch", "haven't watched", "haven't seen", "mark as unwatched", "actually i didn't"]
        - For "addToWatchlist": ["add to", "save this", "put in my", "add this to"]
        """
        
        let userMessage = "Analyze this failed command: \"\(utterance)\""
        
        // Request structures
        struct ChatCompletionRequest: Codable {
            let model: String
            let messages: [ChatMessage]
            let responseFormat: ResponseFormat?
            let temperature: Double
            
            enum CodingKeys: String, CodingKey {
                case model
                case messages
                case responseFormat = "response_format"
                case temperature
            }
        }
        
        struct ChatMessage: Codable {
            let role: String
            let content: String
        }
        
        struct ResponseFormat: Codable {
            let type: String
        }
        
        struct ChatCompletionResponse: Codable {
            let choices: [Choice]
            
            struct Choice: Codable {
                let message: Message
                
                struct Message: Codable {
                    let content: String
                }
            }
        }
        
        let requestBody = ChatCompletionRequest(
            model: OpenAIConfig.defaultModel,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userMessage)
            ],
            responseFormat: ResponseFormat(type: "json_object"),
            temperature: 0.3
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = OpenAIConfig.requestTimeout
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        print("🤖 [SelfHealing] Calling OpenAI for analysis...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [SelfHealing] OpenAI API error: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            throw OpenAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let completionResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let content = completionResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        print("🤖 [SelfHealing] OpenAI response: \(content)")
        
        // Parse JSON from content
        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAIError.decodingError("Could not convert content to data")
        }
        
        let analysis = try decoder.decode(SelfHealingResponse.self, from: jsonData)
        
        return analysis
    }
    
    // MARK: - Supabase Logging
    
    /// Logs the pattern suggestion to Supabase
    private func logPatternSuggestion(
        utterance: String,
        originalCommandType: String,
        suggestedIntent: String?,
        suggestedPatterns: [String],
        confidence: Double?,
        voiceEventId: UUID?
    ) async {
        guard let client = supabaseClient else {
            print("⚠️ [SelfHealing] Supabase client not available, skipping log")
            return
        }
        
        do {
            // Combine patterns into a single string (comma-separated)
            let patternString: String?
            if suggestedPatterns.isEmpty {
                patternString = nil
            } else if suggestedPatterns.count == 1 {
                patternString = suggestedPatterns.first
            } else {
                patternString = suggestedPatterns.joined(separator: ", ")
            }
            
            let suggestion = PatternSuggestion(
                utterance: utterance,
                original_command_type: originalCommandType,
                suggested_intent: suggestedIntent,
                suggested_pattern: patternString,
                confidence: confidence,
                source: "llm",
                status: "pending",
                voice_event_id: voiceEventId?.uuidString
            )
            
            try await client
                .from("voice_pattern_suggestions")
                .insert(suggestion)
                .execute()
            
            print("✅ [SelfHealing] Logged pattern suggestion to Supabase")
            print("   Utterance: '\(utterance)'")
            print("   Suggested Intent: \(suggestedIntent ?? "none")")
            print("   Confidence: \(confidence.map { String(format: "%.2f", $0) } ?? "none")")
            print("   Patterns: \(patternString ?? "none")")
            
        } catch {
            print("❌ [SelfHealing] Failed to log pattern suggestion: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Misclassification Detection
    
    /// Check for potential misclassifications after successful command execution
    /// Triggers self-healing analysis if:
    /// 1. Command was markWatched but transcript contains negation words before "watched" or "seen"
    /// 2. Command was markUnwatched but transcript has NO negation words
    func checkForMisclassification(
        transcript: String,
        executedCommand: MangoCommand,
        voiceEventId: UUID? = nil
    ) async {
        guard case .markWatched(let watched, _) = executedCommand else {
            // Only check markWatched/markUnwatched commands
            return
        }
        
        let lower = transcript.lowercased()
        
        // Negation words that should invert the intent
        let negationWords: Set<String> = ["don't", "dont", "didn't", "didnt", "haven't", "havent", "never", "not"]
        
        // Keywords that indicate watched/seen status
        let watchedKeywords: Set<String> = ["watched", "seen", "saw"]
        
        // Check for negation words before watched keywords
        var hasNegation = false
        for keyword in watchedKeywords {
            if let keywordRange = lower.range(of: keyword, options: .caseInsensitive) {
                // Get text before the keyword (check last 10 words for negation)
                let beforeKeyword = String(lower[..<keywordRange.lowerBound])
                let wordsBefore = beforeKeyword.split(separator: " ").map { String($0).lowercased() }
                
                // Check last 10 words before the keyword for negation
                let recentWords = wordsBefore.suffix(10)
                hasNegation = recentWords.contains { word in
                    // Check if word contains any negation word (handles contractions like "don't")
                    negationWords.contains(word) || negationWords.contains { neg in word.contains(neg) }
                }
                
                if hasNegation {
                    break
                }
            }
        }
        
        // Case 1: Command was markWatched (watched=true) but transcript contains negation
        if watched && hasNegation {
            print("⚠️ [SelfHealing] Misclassification detected: markWatched but transcript has negation")
            await logMisclassificationSuggestion(
                transcript: transcript,
                executedCommand: executedCommand,
                suggestedIntent: "markUnwatched",
                reasoning: "Transcript contains negation words ('don't', 'didn't', 'haven't', 'never', 'not') before 'watched' or 'seen', suggesting user wanted to mark as unwatched",
                voiceEventId: voiceEventId
            )
            return
        }
        
        // Case 2: Command was markUnwatched (watched=false) but transcript has NO negation
        if !watched && !hasNegation {
            // Check if transcript actually contains watched keywords (if not, might be a different issue)
            let hasWatchedKeyword = watchedKeywords.contains { lower.contains($0) }
            if hasWatchedKeyword {
                print("⚠️ [SelfHealing] Misclassification detected: markUnwatched but transcript has no negation")
                await logMisclassificationSuggestion(
                    transcript: transcript,
                    executedCommand: executedCommand,
                    suggestedIntent: "markWatched",
                    reasoning: "Transcript contains 'watched' or 'seen' keywords but no negation words, suggesting user wanted to mark as watched",
                    voiceEventId: voiceEventId
                )
            }
        }
    }
    
    /// Log misclassification suggestion directly (without OpenAI analysis)
    private func logMisclassificationSuggestion(
        transcript: String,
        executedCommand: MangoCommand,
        suggestedIntent: String,
        reasoning: String,
        voiceEventId: UUID?
    ) async {
        guard let client = supabaseClient else {
            print("⚠️ [SelfHealing] Supabase client not available, skipping misclassification log")
            return
        }
        
        let commandType = commandTypeString(executedCommand)
        
        do {
            let suggestion = PatternSuggestion(
                utterance: transcript,
                original_command_type: commandType,
                suggested_intent: suggestedIntent,
                suggested_pattern: reasoning,
                confidence: 0.8, // High confidence for rule-based detection
                source: "misclassification_detector",
                status: "pending",
                voice_event_id: voiceEventId?.uuidString
            )
            
            try await client
                .from("voice_pattern_suggestions")
                .insert(suggestion)
                .execute()
            
            print("✅ [SelfHealing] Logged misclassification suggestion to Supabase")
            print("   Utterance: '\(transcript)'")
            print("   Executed Command: \(commandType)")
            print("   Suggested Intent: \(suggestedIntent)")
            print("   Reasoning: \(reasoning)")
            
        } catch {
            print("❌ [SelfHealing] Failed to log misclassification suggestion: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func commandTypeString(_ command: MangoCommand) -> String {
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
