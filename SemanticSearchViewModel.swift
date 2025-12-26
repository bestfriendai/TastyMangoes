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
    
    private let searchService = SemanticSearchService.shared
    private let voiceManager = MangoVoiceManager.shared
    
    func search(query: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await searchService.search(query: query)
            
            movies = response.movies
            refinementChips = response.refinementChips
            mangoText = response.mangoVoice.text
            interpretation = response.meta.interpretation
            
            // Speak Mango's response
            voiceManager.speak(response.mangoVoice.text)
            
        } catch {
            self.error = error.localizedDescription
            mangoText = "Hmm, I hit a snag. Let me try that again."
            voiceManager.speak(mangoText)
        }
        
        isLoading = false
    }
    
    func refine(with chip: String) async {
        await search(query: chip)
    }
    
    func clearResults() {
        movies = []
        refinementChips = []
        mangoText = ""
        interpretation = ""
        searchService.clearSession()
    }
}

