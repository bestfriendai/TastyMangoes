//  SupabaseService+ComprehensiveSearch.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 18:30 (America/Los_Angeles - Pacific Time)
//  Notes: Extension for comprehensive search caching to avoid redundant AI calls.
//         Caches director/actor searches for 7 days to reduce API costs.

import Foundation
import Supabase

// MARK: - Comprehensive Search Record

struct ComprehensiveSearchRecord: Codable {
    let id: String
    let last_searched: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case last_searched
    }
}

// MARK: - SupabaseService Extension

extension SupabaseService {
    
    // MARK: - Comprehensive Search Cache
    
    /// Check if we've done this comprehensive search recently (within 7 days)
    /// - Parameters:
    ///   - type: Search type ("director" or "actor")
    ///   - value: The search value (director name or actor name)
    /// - Returns: True if a recent search exists, false otherwise
    func hasRecentComprehensiveSearch(type: String, value: String) async throws -> Bool {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sevenDaysAgoString = dateFormatter.string(from: sevenDaysAgo)
        
        #if DEBUG
        print("🔍 [ComprehensiveSearch] Checking cache for \(type): \(value) (normalized: \(normalized))")
        #endif
        
        do {
            let response: [ComprehensiveSearchRecord] = try await client
                .from("comprehensive_searches")
                .select("id, last_searched")
                .eq("search_type", value: type)
                .eq("normalized_value", value: normalized)
                .gte("last_searched", value: sevenDaysAgoString)
                .limit(1)
                .execute()
                .value
            
            let hasRecent = !response.isEmpty
            
            #if DEBUG
            if hasRecent {
                print("✅ [ComprehensiveSearch] Cache HIT for \(type): \(value)")
            } else {
                print("❌ [ComprehensiveSearch] Cache MISS for \(type): \(value)")
            }
            #endif
            
            return hasRecent
        } catch {
            #if DEBUG
            print("⚠️ [ComprehensiveSearch] Error checking cache: \(error)")
            #endif
            throw error
        }
    }
    
    /// Save a comprehensive search after AI completes
    /// - Parameters:
    ///   - type: Search type ("director" or "actor")
    ///   - value: The search value (director name or actor name)
    ///   - tmdbIds: Array of TMDB IDs found by the search
    func saveComprehensiveSearch(type: String, value: String, tmdbIds: [String]) async throws {
        guard let client = client else {
            throw SupabaseError.notConfigured
        }
        
        let normalized = value.lowercased().trimmingCharacters(in: .whitespaces)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowString = dateFormatter.string(from: Date())
        
        #if DEBUG
        print("💾 [ComprehensiveSearch] Saving search: \(type)=\(value), \(tmdbIds.count) movies")
        #endif
        
        // Create insert/update struct
        struct ComprehensiveSearchInsert: Codable {
            let search_type: String
            let search_value: String
            let normalized_value: String
            let movies_found: Int
            let tmdb_ids: [String]
            let last_searched: String
        }
        
        let insertData = ComprehensiveSearchInsert(
            search_type: type,
            search_value: value,
            normalized_value: normalized,
            movies_found: tmdbIds.count,
            tmdb_ids: tmdbIds,
            last_searched: nowString
        )
        
        do {
            // Upsert with conflict resolution on (search_type, normalized_value)
            try await client
                .from("comprehensive_searches")
                .upsert(insertData, onConflict: "search_type,normalized_value")
                .execute()
            
            #if DEBUG
            print("✅ [ComprehensiveSearch] Saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [ComprehensiveSearch] Failed to save: \(error)")
            #endif
            throw error
        }
    }
}
