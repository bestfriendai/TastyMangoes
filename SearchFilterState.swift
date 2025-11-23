//  SearchFilterState.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 05:18 (America/Los_Angeles - Pacific Time)
//  Notes: Created centralized filter state management for search functionality with platform and genre filtering. Updated to use yearRange (ClosedRange<Int>) instead of yearFrom/yearTo strings, matching WatchlistFilterState pattern. Changed default sortBy to "List order".

import Foundation
import SwiftUI
import Combine

@MainActor
class SearchFilterState: ObservableObject {
    static let shared = SearchFilterState()
    
    // MARK: - Published Properties
    
    @Published var selectedPlatforms: Set<String> = []
    @Published var selectedGenres: Set<String> = []
    @Published var searchQuery: String = "" // Track search query for tab bar visibility
    @Published var sortBy: String = "List order"
    @Published var tastyScoreRange: ClosedRange<Double> = 0...100
    @Published var aiScoreRange: ClosedRange<Double> = 0...10
    @Published var watchedStatus: String = "Any"
    @Published var yearRange: ClosedRange<Int> = 1925...2025
    @Published var likedBy: String = "Any"
    @Published var actors: String = ""
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        !selectedPlatforms.isEmpty || !selectedGenres.isEmpty || 
        sortBy != "List order" || watchedStatus != "Any" ||
        yearRange != (1925...2025) || likedBy != "Any" || !actors.isEmpty ||
        tastyScoreRange != (0...100) || aiScoreRange != (0...10)
    }
    
    var platformFilterText: String {
        if selectedPlatforms.isEmpty {
            return "Platform: Any"
        } else if selectedPlatforms.count == 1 {
            return "Platform: \(selectedPlatforms.first ?? "")"
        } else {
            return "Platform: \(selectedPlatforms.count)+"
        }
    }
    
    var genreFilterText: String {
        if selectedGenres.isEmpty {
            return "Genres: Any"
        } else if selectedGenres.count == 1 {
            return "Genres: \(selectedGenres.first ?? "")"
        } else {
            return "Genres: \(selectedGenres.count)+"
        }
    }
    
    // MARK: - Methods
    
    func clearAllFilters() {
        selectedPlatforms = []
        selectedGenres = []
        sortBy = "List order"
        tastyScoreRange = 0...100
        aiScoreRange = 0...10
        watchedStatus = "Any"
        yearRange = 1925...2025
        likedBy = "Any"
        actors = ""
    }
    
    func clearPlatformFilters() {
        selectedPlatforms = []
    }
    
    func clearGenreFilters() {
        selectedGenres = []
    }
}

