//  RecommenderNormalizer.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
//  Notes: Normalizes recommender names from speech recognition, handling common mishearings and variations

import Foundation

struct RecommenderNormalizer {
    
    /// Known recommenders and their variations/mishearings
    private static let recommenderMappings: [String: String] = [
        // Keo variations
        "keo": "Keo",
        "kio": "Keo",
        "geo": "Keo",
        "ceo": "Keo",
        "theo": "Keo",
        "leo": "Keo",
        "keyo": "Keo",
        "kyro": "Keo",
        "cairo": "Keo",
        "keyhole": "Keo",
        "kayo": "Keo",
        "ko": "Keo",
        "key oh": "Keo",
        "key-oh": "Keo",
        
        // Kailan variations
        "kailan": "Kailan",
        "kaylan": "Kailan",
        "kailyn": "Kailan",
        "cailin": "Kailan",
        "caitlin": "Kailan",
        "kalen": "Kailan",
        "kaylen": "Kailan",
        "kylan": "Kailan",
        "kaylon": "Kailan",
        "ki-lan": "Kailan",
        "kai-lan": "Kailan",
        "kai lan": "Kailan",
        "island": "Kailan",  // Apple sometimes hears "Kailan" as "island"
        "Highland": "Kailan",
        "kyle and": "Kailan",
        "kyle in": "Kailan",
        
        // Hayat variations
        "hayat": "Hayat",
        "hyatt": "Hayat",
        "high at": "Hayat",
        "hi at": "Hayat",
        "ayat": "Hayat",
        "hey yacht": "Hayat",
        "hi yacht": "Hayat",
    ]
    
    /// Attempts to normalize a recommender name from speech input
    /// - Parameter input: The raw speech recognition text
    /// - Returns: The normalized recommender name, or nil if no match found
    static func normalize(_ input: String) -> String? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Direct lookup
        if let match = recommenderMappings[lowercased] {
            return match
        }
        
        // Check if input contains any known variation
        for (variation, normalized) in recommenderMappings {
            if lowercased.contains(variation) {
                return normalized
            }
        }
        
        // No match found - return original with capitalization
        // This allows for new recommenders not in the mapping
        if !input.isEmpty {
            return input.capitalized
        }
        
        return nil
    }
    
    /// Checks if the input matches a known recommender
    static func isKnownRecommender(_ input: String) -> Bool {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespaces)
        return recommenderMappings[lowercased] != nil || 
               recommenderMappings.values.map({ $0.lowercased() }).contains(lowercased)
    }
    
    /// Returns all known recommender names (normalized)
    static var knownRecommenders: [String] {
        Array(Set(recommenderMappings.values)).sorted()
    }
}
