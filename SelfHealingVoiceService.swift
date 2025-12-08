//  SelfHealingVoiceService.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 18:00 (America/Los_Angeles - Pacific Time)
//  Notes: Self-healing voice system that analyzes failed voice commands using OpenAI and logs pattern suggestions to Supabase

import Foundation
import Supabase

// MARK: - Pattern Suggestion Model

struct PatternSuggestion: Codable {
    let utterance: String
    let original_command_type: String?
    let suggested_intent: String?
    let suggested_pattern: String?  // Store first pattern, or comma-separated
    let confidence: Double?
    let source: String  // "llm"
    let status: String  // "pending"
    let voice_event_id: String?  // Link to original event if available (UUID as string)
    
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
    let intent: String  // "markWatched" | "markUnwatched" | "addToWatchlist" | "removeFromWatchlist" | "search" | "unknown"
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
            // Still log to Supabase with minimal data
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
    
    /// Calls OpenAI to analyze the failed utterance
    private func analyzeWithOpenAI(utterance: String, context: String) async throws -> SelfHealingResponse {
        guard OpenAIClient.isConfigured else {
            throw OpenAIError.notConfigured
        }
        
        guard let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        // Construct system prompt
        let systemPrompt = """
        You are analyzing a failed voice command in a movie recommendation app called "Mango".
        
        A user said: "\(utterance)"
        Context: \(context)
        
        This was not understood by the voice parser. What did the user likely mean?
        
        Respond with ONLY a single JSON object, no prose, using this exact format:
        {
          "intent": "markWatched" | "markUnwatched" | "addToWatchlist" | "removeFromWatchlist" | "search" | "unknown",
          "confidence": 0.0-1.0,
          "reasoning": "brief explanation",
          "suggested_patterns": ["pattern1", "pattern2", ...] // lowercase phrases that should trigger this intent
        }
        
        Intent rules:
        - "markWatched": User wants to mark a movie as watched (e.g., "mark as watched", "I watched this", "seen it")
        - "markUnwatched": User wants to mark a movie as unwatched (e.g., "mark as unwatched", "haven't seen", "not watched")
        - "addToWatchlist": User wants to add a movie to a watchlist (e.g., "add to list", "save this", "put in my list")
        - "removeFromWatchlist": User wants to remove a movie from a watchlist (e.g., "remove from list", "delete from list", "take out")
        - "search": User wants to search for a movie (e.g., "find", "look for", "search for")
        - "unknown": Cannot determine intent
        
        Suggested patterns should be lowercase phrases that would help the parser recognize this intent in the future.
        Examples:
        - For "markWatched": ["mark as watched", "mark watched", "i watched this", "seen it", "watched it"]
        - For "addToWatchlist": ["add to list", "save this", "put in list", "add to my list"]
        """
        
        let userMessage = "Analyze this failed command: \"\(utterance)\""
        
        // Use the same request structure as OpenAIClient
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
            // Combine patterns into a single string (comma-separated, or first pattern)
            let patternString: String?
            if suggestedPatterns.isEmpty {
                patternString = nil
            } else if suggestedPatterns.count == 1 {
                patternString = suggestedPatterns.first
            } else {
                // Store first pattern, or comma-separated if needed
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
            print("   Patterns: \(patternString ?? "none")")
            
        } catch {
            print("❌ [SelfHealing] Failed to log pattern suggestion: \(error.localizedDescription)")
        }
    }
}
