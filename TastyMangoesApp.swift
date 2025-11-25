// Managed via Cursor

//
//  TastyMangoesApp.swift
//  TastyMangoes
//
//  Created by Tim Robinson on 10/9/25.
//  Updated on: 2025-01-15 at 16:30 (America/Los_Angeles - Pacific Time)
//  Notes: Updated to handle authentication state and wire up ProfileView

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
                // Check auth status on app launch
                await authManager.checkAuthStatus()
            }
        }
    }
}
