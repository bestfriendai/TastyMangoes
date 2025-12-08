//  AuthManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:50 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-06 at 11:38 (America/Los_Angeles - Pacific Time)
//  Notes: Authentication manager for handling user sign up, sign in, and sign out. Added watchlist sync from Supabase after sign-in and sign-out notifications.

import Foundation
import SwiftUI
import Combine
import Auth

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
    private init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if try await supabaseService.getCurrentSession() != nil {
                isAuthenticated = true
                if let user = try await supabaseService.getCurrentUser() {
                    // Load user profile - user.id is already a UUID
                    currentUser = try await supabaseService.getProfile(userId: user.id)
                }
            } else {
                isAuthenticated = false
                currentUser = nil
            }
        } catch {
            print("Error checking auth status: \(error)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await supabaseService.signUp(email: email, password: password)
            
            // Check if email confirmation is required
            if response.session == nil {
                // Email confirmation is required - user needs to confirm email first
                // Store the username temporarily so we can update profile after confirmation
                // For now, we'll show an error message
                errorMessage = "Please check your email and confirm your account before signing in."
                throw NSError(domain: "AuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Email confirmation required"])
            }
            
            // Session exists, proceed with profile update
            // Update username in profile - response.user.id is already a UUID
            currentUser = try await supabaseService.updateProfile(
                userId: response.user.id,
                username: username,
                avatarURL: nil
            )
            
            isAuthenticated = true
        } catch {
            // Check if it's an email confirmation error
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("email") && errorDescription.contains("confirm") {
                errorMessage = "Please check your email and confirm your account. You can sign in after confirmation."
            } else {
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            _ = try await supabaseService.signIn(email: email, password: password)
            isAuthenticated = true
            
            // Load user profile - user.id is already a UUID
            if let user = try await supabaseService.getCurrentUser() {
                currentUser = try await supabaseService.getProfile(userId: user.id)
            }
            
            // Sync watchlists from Supabase after successful sign-in
            await WatchlistManager.shared.syncFromSupabase()
            
            // Post notification to refresh watchlist views
            NotificationCenter.default.post(
                name: Notification.Name("UserDidSignIn"),
                object: nil
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await supabaseService.signOut()
            isAuthenticated = false
            currentUser = nil
            
            // Clear watchlist data when signing out
            // The WatchlistManager will reload from cache or Supabase when user signs back in
            NotificationCenter.default.post(
                name: Notification.Name("UserDidSignOut"),
                object: nil
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

