//  SearchHistoryManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
//  Notes: Created search history and suggestions manager for search functionality

import Foundation

class SearchHistoryManager {
    static let shared = SearchHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "searchHistory"
    private let maxHistoryCount = 10
    
    // Mock suggestions for demo (in production, this would come from API)
    private let suggestions: [String] = [
        "Jurassic Park", "Juno", "Jumanji", "Jackie Brown", 
        "Jerry Maguire", "Judy", "Julie & Julia", "Joker",
        "John Wick", "Jaws", "Jungle Book", "Justice League"
    ]
    
    // MARK: - Search History
    
    func getSearchHistory() -> [String] {
        return userDefaults.stringArray(forKey: historyKey) ?? []
    }
    
    func addToHistory(_ query: String) {
        guard !query.isEmpty, query.count >= 2 else { return }
        
        var history = getSearchHistory()
        
        // Remove if already exists
        history.removeAll { $0.lowercased() == query.lowercased() }
        
        // Add to beginning
        history.insert(query, at: 0)
        
        // Limit to max count
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        userDefaults.set(history, forKey: historyKey)
    }
    
    func removeFromHistory(_ query: String) {
        var history = getSearchHistory()
        history.removeAll { $0.lowercased() == query.lowercased() }
        userDefaults.set(history, forKey: historyKey)
    }
    
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
    }
    
    // MARK: - Search Suggestions
    
    func getSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        
        // Filter suggestions that start with the query
        let matchingSuggestions = suggestions.filter { suggestion in
            suggestion.lowercased().hasPrefix(lowercasedQuery)
        }
        
        // Also check history
        let history = getSearchHistory()
        let matchingHistory = history.filter { item in
            item.lowercased().hasPrefix(lowercasedQuery) && 
            !matchingSuggestions.contains(item)
        }
        
        // Combine and limit
        let combined = matchingSuggestions + matchingHistory
        return Array(combined.prefix(8))
    }
}

