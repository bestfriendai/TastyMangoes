//
//  AnalyticsService.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-14 at 00:15 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-14 at 09:55 (America/Los_Angeles - Pacific Time)
//

import Foundation
import Supabase
import Auth

// Encodable struct for inserting events
private struct AnalyticsEventInsert: Encodable {
    let user_id: String
    let session_id: String
    let event_type: String
    let properties: String
}

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let sessionId: UUID
    private var supabaseClient: SupabaseClient?
    
    private init() {
        self.sessionId = UUID()
        setupSupabaseClient()
        print("📊 [Analytics] Session started: \(sessionId)")
    }
    
    private func setupSupabaseClient() {
        guard let url = URL(string: SupabaseConfig.supabaseURL),
              !SupabaseConfig.supabaseAnonKey.isEmpty else {
            print("📊 [Analytics] Supabase not configured")
            return
        }
        
        self.supabaseClient = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
    
    // MARK: - Core Logging
    
    func logEvent(type: String, properties: [String: Any] = [:]) {
        guard let client = supabaseClient else {
            print("📊 [Analytics] Client not configured")
            return
        }
        
        Task {
            do {
                let userId = try await client.auth.session.user.id.uuidString
                
                let propertiesData = try JSONSerialization.data(withJSONObject: properties)
                let propertiesString = String(data: propertiesData, encoding: .utf8) ?? "{}"
                
                let event = AnalyticsEventInsert(
                    user_id: userId,
                    session_id: sessionId.uuidString,
                    event_type: type,
                    properties: propertiesString
                )
                
                try await client
                    .from("events")
                    .insert(event)
                    .execute()
                
                print("📊 [Analytics] Logged: \(type)")
            } catch {
                print("📊 [Analytics] Error logging \(type): \(error)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    func logAppOpen(source: String = "cold_start") {
        logEvent(type: "app_open", properties: ["source": source])
    }
    
    func logScreenView(screenName: String) {
        logEvent(type: "screen_view", properties: ["screen_name": screenName])
    }
    
    func logMovieView(movieId: String, movieTitle: String, source: String) {
        logEvent(type: "movie_view", properties: [
            "movie_id": movieId,
            "movie_title": movieTitle,
            "source": source
        ])
    }
    
    func logMovieSearch(query: String, resultCount: Int, source: String = "keyboard") {
        logEvent(type: "movie_search", properties: [
            "query": query,
            "result_count": resultCount,
            "source": source
        ])
    }
    
    func logMarkWatched(movieId: String, movieTitle: String) {
        logEvent(type: "mark_watched", properties: [
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    func logUnmarkWatched(movieId: String, movieTitle: String) {
        logEvent(type: "unmark_watched", properties: [
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    func logListAdd(listId: String, listName: String, movieId: String, movieTitle: String) {
        logEvent(type: "list_add", properties: [
            "list_id": listId,
            "list_name": listName,
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    func logSignUp(method: String = "email") {
        logEvent(type: "sign_up", properties: ["method": method])
    }
    
    func logSignIn(method: String = "email") {
        logEvent(type: "sign_in", properties: ["method": method])
    }
}
