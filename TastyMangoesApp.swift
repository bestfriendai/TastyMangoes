// Managed via Cursor

//
//  TastyMangoesApp.swift
//  TastyMangoes
//
//  Created by Tim Robinson on 10/9/25.
//  Updated on: 2025-01-15 at 16:30 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 09:14 PST by Cursor Assistant
//  Notes: Updated to handle authentication state and wire up ProfileView. Removed syncFromSupabase call from task to debug persistence issues.

import SwiftUI

@main
struct TastyMangoesApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    TabBarView()
                        .environmentObject(WatchlistManager.shared)
                        .environmentObject(authManager)
                        .environmentObject(profileManager)
                } else {
                    SignInView()
                        .environmentObject(authManager)
                }
            }
            .task {
                // Log app open event
                await AnalyticsService.shared.logAppOpen()
                
                // Check auth status on app launch
                await authManager.checkAuthStatus()
                
                // Sync watchlists from Supabase if user is authenticated
                if authManager.isAuthenticated {
                    print("📋 [Watchlist] App launch - user authenticated, syncing watchlists from Supabase...")
                    await WatchlistManager.shared.syncFromSupabase()
                } else {
                    print("📋 [Watchlist] App launch - user not authenticated, skipping watchlist sync")
                }
            }
        }
    }
}
