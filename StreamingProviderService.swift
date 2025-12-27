//  StreamingProviderService.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-27 at 15:21 (America/Los_Angeles - Pacific Time)
//  Notes: Manages user streaming subscriptions and provider matching for v1Prime feature

import Foundation
import Combine
import Auth

@MainActor
class StreamingProviderService: ObservableObject {
    static let shared = StreamingProviderService()
    
    @Published private(set) var userProviderIds: Set<Int> = []
    @Published private(set) var isLoaded = false
    
    // TMDB Provider ID mapping
    // Maps user-friendly platform names to TMDB provider IDs
    private let providerMapping: [String: [Int]] = [
        // Amazon Prime variants
        "Prime Video": [9, 2100, 613],           // Prime, Prime w/Ads, Free w/Ads
        "Amazon Prime Video": [9, 2100, 613],
        
        // Netflix
        "Netflix": [8],
        
        // Apple
        "Apple TV+": [350, 2],                   // Apple TV+, Apple TV
        "Apple TV": [350, 2],
        
        // Paramount
        "Paramount+": [531, 1853],               // Paramount+, Paramount+ with Showtime
        "Paramount Plus": [531, 1853],
        
        // Max (formerly HBO Max)
        "Max": [1899, 384],                      // Max, HBO Max
        "HBO Max": [1899, 384],
        
        // Hulu
        "Hulu": [15],
        
        // Disney
        "Disney+": [337],
        "Disney Plus": [337],
        
        // Criterion
        "Criterion": [258],
        "Criterion Channel": [258],
        
        // Peacock
        "Peacock": [386, 387],                   // Peacock, Peacock Premium
        
        // Others
        "Tubi": [73],
        "Pluto TV": [300],
        "The Roku Channel": [207],
    ]
    
    private init() {}
    
    /// Load user's streaming subscriptions from Supabase
    func loadUserSubscriptions() async {
        do {
            guard let user = try await SupabaseService.shared.getCurrentUser() else {
                print("🎬 [StreamingProvider] No user logged in")
                return
            }
            
            // getUserSubscriptions returns [String] of platform names
            let platforms = try await SupabaseService.shared.getUserSubscriptions(userId: user.id)
            
            var providerIds: Set<Int> = []
            for platform in platforms {
                if let ids = providerMapping[platform] {
                    providerIds.formUnion(ids)
                } else {
                    print("⚠️ [StreamingProvider] Unknown platform: \(platform)")
                }
            }
            
            self.userProviderIds = providerIds
            self.isLoaded = true
            
            print("🎬 [StreamingProvider] Loaded \(platforms.count) subscriptions → \(providerIds.count) provider IDs")
            print("🎬 [StreamingProvider] Platforms: \(platforms.joined(separator: ", "))")
            
        } catch {
            print("❌ [StreamingProvider] Error loading subscriptions: \(error)")
        }
    }
    
    /// Check if a movie is available on user's streaming services
    /// - Parameter providers: Array of StreamingProvider objects from TMDB streaming data
    /// - Returns: true if movie is on at least one of user's services
    func isMovieOnUserService(providers: [StreamingProvider]?) -> Bool {
        guard let providers = providers, !userProviderIds.isEmpty else {
            return false
        }
        
        for provider in providers {
            if userProviderIds.contains(provider.providerId) {
                return true
            }
        }
        
        return false
    }
    
    /// Get the names of user's services that have this movie
    func matchingServiceNames(providers: [StreamingProvider]?) -> [String] {
        guard let providers = providers else { return [] }
        
        var names: [String] = []
        for provider in providers {
            if userProviderIds.contains(provider.providerId) {
                names.append(provider.providerName)
            }
        }
        
        return names
    }
}

