//  SemanticSearchViewModel.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: View model for semantic search feature

import SwiftUI
import Combine

@MainActor
class SemanticSearchViewModel: ObservableObject {
    @Published var movies: [SemanticMovie] = []
    @Published var refinementChips: [String] = []
    @Published var mangoText: String = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var interpretation: String = ""
    @Published var selectedChip: String? // Track active chip for loading feedback
    
    private let searchService = SemanticSearchService.shared
    private let voiceManager = MangoVoiceManager.shared
    private var currentSearchTask: Task<Void, Never>?  // Track current search to prevent duplicates
    private var originalQuery: String = ""  // Track original query for refinement context
    
    // History for back navigation
    private var searchHistory: [(query: String, movies: [SemanticMovie], chips: [String], mangoText: String)] = []
    
    func search(query: String) async {
        print("🔍 [SemanticSearchViewModel] Starting search for: '\(query)'")
        
        // Cancel any existing search
        currentSearchTask?.cancel()
        
        // Stop any current speech before starting new search
        voiceManager.stop()
        
        // Save current state to history before new search (if we have results)
        if !movies.isEmpty {
            searchHistory.append((
                query: originalQuery.isEmpty ? query : originalQuery,
                movies: movies,
                chips: refinementChips,
                mangoText: mangoText
            ))
            // Keep history manageable (last 5 searches)
            if searchHistory.count > 5 {
                searchHistory.removeFirst()
            }
        }
        
        // Store original query (unless this is already a refinement)
        if originalQuery.isEmpty {
            originalQuery = query
        }
        
        isLoading = true
        error = nil
        
        // Create new search task
        let searchTask = Task {
            do {
                print("🔍 [SemanticSearchViewModel] Calling searchService.newSearch...")
                let response = try await searchService.newSearch(query: query)
                
                print("✅ [SemanticSearchViewModel] Received response: \(response.movies.count) movies, \(response.refinementChips.count) chips")
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                movies = response.movies
                refinementChips = response.refinementChips
                mangoText = response.mangoVoice.text
                interpretation = response.meta.interpretation
                
                // Speak Mango's response (only if not cancelled)
                if !Task.isCancelled {
                    voiceManager.speak(response.mangoVoice.text)
                }
                
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.error = error.localizedDescription
                print("❌ [SemanticSearch] Error: \(error)")
                if let semanticError = error as? SemanticSearchError {
                    print("❌ [SemanticSearch] Error details: \(semanticError.localizedDescription)")
                }
                mangoText = "Hmm, I hit a snag. Let me try that again."
                // Don't speak error message - it's annoying
                // voiceManager.speak(mangoText)
            }
            
            isLoading = false
            selectedChip = nil // Clear selected chip when done
            currentSearchTask = nil
        }
        
        currentSearchTask = searchTask
        await searchTask.value
    }
    
    func refine(with chip: String) async {
        // Set selected chip immediately for visual feedback
        selectedChip = chip
        // Combine original query with refinement chip
        // If chip is a complete phrase, use it; otherwise combine with original
        let refinedQuery: String
        if chip.lowercased().contains(originalQuery.lowercased()) {
            // Chip already contains the original query (e.g., "war movies based on true stories")
            refinedQuery = chip
        } else {
            // Chip is a modifier (e.g., "based on true stories") - combine with original
            refinedQuery = "\(originalQuery) \(chip)"
        }
        
        print("🔍 [SemanticSearch] Refining: '\(originalQuery)' + '\(chip)' → '\(refinedQuery)'")
        
        // Save current state to history before refining
        if !movies.isEmpty {
            searchHistory.append((
                query: originalQuery.isEmpty ? refinedQuery : originalQuery,
                movies: movies,
                chips: refinementChips,
                mangoText: mangoText
            ))
            // Keep history manageable (last 5 searches)
            if searchHistory.count > 5 {
                searchHistory.removeFirst()
            }
        }
        
        await search(query: refinedQuery)
    }
    
    func goBack() {
        guard let previous = searchHistory.popLast() else { return }
        
        // Cancel any ongoing search
        currentSearchTask?.cancel()
        
        // Stop any current speech
        voiceManager.stop()
        
        // Restore previous state
        movies = previous.movies
        refinementChips = previous.chips
        mangoText = previous.mangoText
        originalQuery = previous.query
        selectedChip = nil // Clear selected chip on back navigation
        error = nil // Clear any error on back navigation
        
        print("🔙 [SemanticSearch] Went back to: '\(previous.query)' (history remaining: \(searchHistory.count))")
    }
    
    var canGoBack: Bool {
        !searchHistory.isEmpty
    }
    
    func clearResults() {
        movies = []
        refinementChips = []
        mangoText = ""
        interpretation = ""
        originalQuery = ""
        searchHistory = []
        searchService.clearSession()
    }
}

