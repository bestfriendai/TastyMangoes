//  UserProfileManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:50 (America/Los_Angeles - Pacific Time)
//  Notes: User profile manager for handling username and subscription management

import Foundation
import SwiftUI
import Combine

@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var username: String = ""
    @Published var subscriptions: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private let authManager = AuthManager.shared
    
    private init() {
        Task {
            await loadProfile()
        }
    }
    
    // MARK: - Load Profile
    
    func loadProfile() async {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load profile
            let profile = try await supabaseService.getProfile(userId: userId)
            username = profile.username
            
            // Load subscriptions
            subscriptions = try await supabaseService.getUserSubscriptions(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading profile: \(error)")
        }
    }
    
    // MARK: - Update Username
    
    func updateUsername(_ newUsername: String) async throws {
        guard let userId = authManager.currentUser?.id else {
            throw ProfileError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let profile = try await supabaseService.updateProfile(
                userId: userId,
                username: newUsername,
                avatarURL: nil
            )
            
            username = profile.username
            authManager.currentUser = profile
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update Subscriptions
    
    func updateSubscriptions(_ platforms: [String]) async throws {
        guard let userId = authManager.currentUser?.id else {
            throw ProfileError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await supabaseService.setUserSubscriptions(userId: userId, platforms: platforms)
            subscriptions = platforms
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Toggle Subscription
    
    func toggleSubscription(_ platform: String) async throws {
        var updated = subscriptions
        
        if updated.contains(platform) {
            updated.removeAll { $0 == platform }
        } else {
            updated.append(platform)
        }
        
        try await updateSubscriptions(updated)
    }
    
    // MARK: - Check if Platform is Subscribed
    
    func isSubscribed(to platform: String) -> Bool {
        return subscriptions.contains(platform)
    }
}

enum ProfileError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}

