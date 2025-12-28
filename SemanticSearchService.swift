//  SemanticSearchService.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: API client for semantic search Edge Function

import Foundation
import Combine
import Auth

@MainActor
class SemanticSearchService: ObservableObject {
    static let shared = SemanticSearchService()
    
    private var baseURL: String {
        "\(SupabaseConfig.supabaseURL)/functions/v1"
    }
    private var anonKey: String {
        SupabaseConfig.supabaseAnonKey
    }
    
    // Session state
    @Published var sessionContext = SessionContext()
    @Published var isLoading = false
    @Published var lastResponse: SemanticSearchResponse?
    @Published var error: String?
    
    private var sessionId = UUID().uuidString
    private var isRefinement = false
    
    /// Call this for NEW searches (typed or spoken)
    func newSearch(query: String, limit: Int = 8) async throws -> SemanticSearchResponse {
        // Clear session for new searches
        sessionContext = SessionContext()
        isRefinement = false
        sessionId = UUID().uuidString // New session ID
        
        return try await search(query: query, limit: limit)
    }
    
    /// Call this for REFINEMENT searches (tapping chips)
    func refineSearch(query: String, limit: Int = 8) async throws -> SemanticSearchResponse {
        // Keep session context for refinements
        isRefinement = true
        
        return try await search(query: query, limit: limit)
    }
    
    private func search(query: String, limit: Int = 8) async throws -> SemanticSearchResponse {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Get current user ID
        let userId: String?
        if let user = try? await SupabaseService.shared.getCurrentUser() {
            userId = user.id.uuidString
        } else {
            userId = nil
        }
        
        let request = SemanticSearchRequest(
            query: query,
            sessionId: sessionId,
            sessionContext: isRefinement ? sessionContext : nil, // Only send context for refinements
            limit: limit,
            userId: userId
        )
        
        guard let url = URL(string: "\(baseURL)/semantic-search") else {
            throw SemanticSearchError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30 // OpenAI can be slow
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SemanticSearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SemanticSearchError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        let searchResponse = try JSONDecoder().decode(SemanticSearchResponse.self, from: data)
        
        // Update session context
        updateSession(query: query, response: searchResponse)
        
        lastResponse = searchResponse
        return searchResponse
    }
    
    private func updateSession(query: String, response: SemanticSearchResponse) {
        // Add this query to history
        sessionContext.queries.append(QueryHistoryItem(text: query))
        
        // Add shown movie IDs
        sessionContext.shownMovieIds.append(contentsOf: response.sessionUpdate.addToShown)
        
        // Merge detected preferences
        for (key, value) in response.sessionUpdate.detectedPreferences {
            sessionContext.preferences[key] = value
        }
        
        // Keep history manageable (last 10 queries)
        if sessionContext.queries.count > 10 {
            sessionContext.queries = Array(sessionContext.queries.suffix(10))
        }
        
        // Keep shown IDs manageable (last 50)
        if sessionContext.shownMovieIds.count > 50 {
            sessionContext.shownMovieIds = Array(sessionContext.shownMovieIds.suffix(50))
        }
    }
    
    func clearSession() {
        sessionContext = SessionContext()
        isRefinement = false
        sessionId = UUID().uuidString
        lastResponse = nil
    }
}

enum SemanticSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

