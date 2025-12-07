//  RecommenderNormalizer.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-06 at 17:38 (America/Los_Angeles - Pacific Time)
//  Notes: Normalizes recommender names from voice input using alias lookup table

import Foundation

struct RecommenderNormalizer {
    
    /// Maps lowercase aliases to canonical names
    private static let aliases: [String: String] = [
        // Keo
        "keo": "Keo",
        "kia": "Keo",
        "kio": "Keo",
        "keyo": "Keo",
        "key oh": "Keo",
        "kayo": "Keo",
        "kyo": "Keo",
        
        // Kailan
        "kailan": "Kailan",
        "kylan": "Kailan",
        "kaelyn": "Kailan",
        "kailyn": "Kailan",
        "cailin": "Kailan",
        "kaylen": "Kailan",
        "kay lan": "Kailan",
        
        // Hayat
        "hayat": "Hayat",
        "hyatt": "Hayat",
        "hi yat": "Hayat",
        "hayot": "Hayat",
        "hi-yat": "Hayat",
        
        // Publications
        "wsj": "The Wall Street Journal",
        "wall street journal": "The Wall Street Journal",
        "the wall street journal": "The Wall Street Journal",
        "nyt": "The New York Times",
        "nytimes": "The New York Times",
        "new york times": "The New York Times",
        "the new york times": "The New York Times"
    ]
    
    /// Normalize a recommender name from voice input
    /// - Parameter raw: The raw recommender name from speech-to-text
    /// - Returns: Canonical spelling if found in aliases, otherwise title-cased input
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        // Check alias table first
        if let canonical = aliases[lowercased] {
            return canonical
        }
        
        // Fallback: title-case each word
        return trimmed
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

