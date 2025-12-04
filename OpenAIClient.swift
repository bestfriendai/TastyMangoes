//  OpenAIClient.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: OpenAI client for LLM fallback when MangoCommand parser fails

import Foundation

// MARK: - LLM Intent Response

struct LLMIntent: Codable {
    let intent: String  // "recommender_search", "movie_search", "unknown"
    let movieTitle: String?
    let recommender: String?
    
    enum CodingKeys: String, CodingKey {
        case intent
        case movieTitle = "movie_title"
        case recommender
    }
}

// MARK: - OpenAI Chat Response Models

private struct ChatCompletionRequest: Codable {
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

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ResponseFormat: Codable {
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case type
    }
}

private struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - OpenAI Client

class OpenAIClient {
    static let shared = OpenAIClient()
    
    private init() {}
    
    /// Classify a voice utterance using OpenAI
    /// Returns an LLMIntent with parsed intent, movie title, and recommender
    func classifyUtterance(_ utterance: String) async throws -> LLMIntent {
        guard !OpenAIConfig.apiKey.isEmpty else {
            throw OpenAIError.apiKeyMissing
        }
        
        guard let url = URL(string: "\(OpenAIConfig.baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        // Construct system prompt
        let systemPrompt = """
        You are an intent classifier for a movie recommendation app called "Mango".
        
        Your job is to analyze user voice utterances and extract:
        1. The movie title (if mentioned)
        2. The recommender name/publication (if mentioned)
        3. The intent type
        
        Respond with ONLY a single JSON object, no prose, using this exact format:
        {
          "intent": "recommender_search" | "movie_search" | "unknown",
          "movie_title": "<movie title or null>",
          "recommender": "<name of person or publication or null>"
        }
        
        Intent rules:
        - "recommender_search": User mentions both a recommender AND a movie (e.g., "Sabrina recommends Baby Girl", "The Wall Street Journal recommends Baby Girl")
        - "movie_search": User mentions only a movie title (e.g., "The Devil Wears Prada", "the movie The Devil Wears Prada")
        - "unknown": Cannot determine intent or movie title
        
        Examples:
        - "Sabrina recommends Baby Girl" → {"intent": "recommender_search", "movie_title": "Baby Girl", "recommender": "Sabrina"}
        - "The Wall Street Journal recommends Baby Girl" → {"intent": "recommender_search", "movie_title": "Baby Girl", "recommender": "The Wall Street Journal"}
        - "The Devil Wears Prada" → {"intent": "movie_search", "movie_title": "The Devil Wears Prada", "recommender": null}
        - "the movie The Devil Wears Prada" → {"intent": "movie_search", "movie_title": "The Devil Wears Prada", "recommender": null}
        """
        
        let userMessage = "User utterance: \"\(utterance)\""
        
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
        
        #if DEBUG
        print("🔵 [OpenAI] Utterance: \"\(utterance)\"")
        print("🔵 [OpenAI] Request messages:")
        for (index, message) in requestBody.messages.enumerated() {
            print("   [\(index)] \(message.role): \(message.content.prefix(200))\(message.content.count > 200 ? "..." : "")")
        }
        #endif
        
        print("🤖 [OpenAI] Classifying utterance: \"\(utterance)\"")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [OpenAI] API error: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            throw OpenAIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("🟢 [OpenAI] Raw response JSON: \(responseString)")
        } else {
            print("🟢 [OpenAI] Raw response: <non-utf8 data, \(data.count) bytes>")
        }
        #endif
        
        // Parse response
        let decoder = JSONDecoder()
        let completionResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let content = completionResponse.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        print("🤖 [OpenAI] Parsed content: \(content)")
        
        // Parse JSON from content
        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAIError.decodingError("Could not convert content to data")
        }
        
        let intent = try decoder.decode(LLMIntent.self, from: jsonData)
        print("🤖 [OpenAI] Parsed intent: \(intent.intent), movieTitle: \(intent.movieTitle ?? "nil"), recommender: \(intent.recommender ?? "nil")")
        
        return intent
    }
}

// MARK: - OpenAI Errors

enum OpenAIError: LocalizedError {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key not configured"
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .decodingError(let message):
            return "Failed to decode OpenAI response: \(message)"
        }
    }
}

