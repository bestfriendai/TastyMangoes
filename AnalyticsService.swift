//  AnalyticsService.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-14 at 07:50 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-14 at 08:00 (America/Los_Angeles - Pacific Time)
//  Purpose: General-purpose event logging for app analytics.
//           Logs to the 'events' table in Supabase.

import Foundation
import Supabase

@MainActor
class AnalyticsService {
    static let shared = AnalyticsService()
    
    /// Current session ID - generated on app launch, persists until app terminates
    private(set) var sessionId: UUID
    
    private var supabaseClient: SupabaseClient?
    
    private init() {
        self.sessionId = UUID()
        setupSupabaseClient()
        print("📊 [Analytics] Session started: \(sessionId)")
    }
    
    private func setupSupabaseClient() {
        guard let url = URL(string: SupabaseConfig.supabaseURL),
              !SupabaseConfig.supabaseAnonKey.isEmpty else {
            print("⚠️ [Analytics] Supabase not configured. Analytics logging disabled.")
            return
        }
        
        self.supabaseClient = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }
    
    // MARK: - Session Management
    
    /// Call this when the app comes to foreground after being terminated
    func startNewSession() {
        self.sessionId = UUID()
        print("📊 [Analytics] New session started: \(sessionId)")
    }
    
    // MARK: - Core Event Logging
    
    /// Log an event to the events table
    private func logEvent(_ eventType: String, properties: [String: Any]? = nil) async {
        guard let client = supabaseClient else {
            print("⚠️ [Analytics] Cannot log event - Supabase not configured")
            return
        }
        
        do {
            // Get current user ID if available
            var userId: UUID? = nil
            if let user = try? await SupabaseService.shared.getCurrentUser() {
                userId = user.id
            }
            
            // Convert properties dict to JSON string for JSONB column
            var propertiesJson: String = "{}"
            if let properties = properties {
                if let jsonData = try? JSONSerialization.data(withJSONObject: properties),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    propertiesJson = jsonString
                }
            }
            
            struct EventInsert: Codable {
                let user_id: String?
                let session_id: String
                let event_type: String
                let properties: String
            }
            
            let event = EventInsert(
                user_id: userId?.uuidString,
                session_id: sessionId.uuidString,
                event_type: eventType,
                properties: propertiesJson
            )
            
            try await client
                .from("events")
                .insert(event)
                .execute()
            
            print("📊 [Analytics] Logged: \(eventType)")
        } catch {
            // Don't crash the app for analytics failures
            print("⚠️ [Analytics] Failed to log \(eventType): \(error.localizedDescription)")
        }
    }
    
    // MARK: - App Lifecycle Events
    
    /// Log app open event
    func logAppOpen(source: String = "cold_start") async {
        await logEvent("app_open", properties: ["source": source])
    }
    
    /// Log app going to background
    func logAppBackground() async {
        await logEvent("app_background")
    }
    
    // MARK: - Screen Views
    
    /// Log screen view
    func logScreenView(_ screenName: String) async {
        await logEvent("screen_view", properties: ["screen": screenName])
    }
    
    // MARK: - Movie Events
    
    /// Log movie detail view
    func logMovieView(movieId: String, title: String, source: String) async {
        await logEvent("movie_view", properties: [
            "movie_id": movieId,
            "movie_title": title,
            "source": source
        ])
    }
    
    /// Log movie search
    func logMovieSearch(query: String, resultCount: Int) async {
        await logEvent("movie_search", properties: [
            "query": query,
            "result_count": resultCount
        ])
    }
    
    /// Log marking movie as watched
    func logMarkWatched(movieId: String, movieTitle: String) async {
        await logEvent("mark_watched", properties: [
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    /// Log unmarking movie as watched
    func logUnmarkWatched(movieId: String, movieTitle: String) async {
        await logEvent("unmark_watched", properties: [
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    /// Log rating a movie
    func logMovieRated(movieId: String, movieTitle: String, rating: Int) async {
        await logEvent("movie_rated", properties: [
            "movie_id": movieId,
            "movie_title": movieTitle,
            "rating": rating
        ])
    }
    
    // MARK: - List Events
    
    /// Log adding movie to list
    func logListAdd(listId: String, listName: String, movieId: String, movieTitle: String) async {
        await logEvent("list_add", properties: [
            "list_id": listId,
            "list_name": listName,
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    /// Log removing movie from list
    func logListRemove(listId: String, listName: String, movieId: String, movieTitle: String) async {
        await logEvent("list_remove", properties: [
            "list_id": listId,
            "list_name": listName,
            "movie_id": movieId,
            "movie_title": movieTitle
        ])
    }
    
    /// Log creating a new list
    func logListCreate(listId: String, listName: String) async {
        await logEvent("list_create", properties: [
            "list_id": listId,
            "list_name": listName
        ])
    }
    
    /// Log sharing a list
    func logListShare(listId: String, listName: String, method: String) async {
        await logEvent("list_share", properties: [
            "list_id": listId,
            "list_name": listName,
            "method": method
        ])
    }
    
    // MARK: - Voice Events
    
    /// Log voice command
    func logVoiceCommand(utterance: String, commandType: String, success: Bool) async {
        await logEvent("voice_command", properties: [
            "utterance": utterance,
            "command_type": commandType,
            "success": success
        ])
    }
    
    // MARK: - Auth Events
    
    /// Log user sign up
    func logSignUp(method: String = "email") async {
        await logEvent("sign_up", properties: ["method": method])
    }
    
    /// Log user sign in
    func logSignIn(method: String = "email") async {
        await logEvent("sign_in", properties: ["method": method])
    }
    
    /// Log user sign out
    func logSignOut() async {
        await logEvent("sign_out")
    }
}
