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
    
    // Private initializer to ensure singleton pattern
    private init() {
        print("🔵 [FILTER STATE] SearchFilterState initialized (singleton)")
    }
    
    // MARK: - Applied Filters (what's actually used for search)
    
    @Published var appliedSelectedPlatforms: Set<String> = []
    @Published var appliedSelectedGenres: Set<String> = []
    @Published var appliedSortBy: String = "List order"
    @Published var appliedTastyScoreRange: ClosedRange<Double> = 0...100
    @Published var appliedAiScoreRange: ClosedRange<Double> = 0...10
    @Published var appliedWatchedStatus: String = "Any"
    @Published var appliedYearRange: ClosedRange<Int> = 1925...2025 {
        didSet {
            print("⚠️ [FILTER STATE] appliedYearRange CHANGED to: \(appliedYearRange.lowerBound)-\(appliedYearRange.upperBound)")
            // Print stack trace to see where it's being changed from
            if #available(iOS 15.0, *) {
                print("   Stack trace:", Thread.callStackSymbols.prefix(5).joined(separator: "\n   "))
            }
        }
    }
    @Published var appliedLikedBy: String = "Any"
    @Published var appliedActors: String = ""
    
    // MARK: - Staged Filters (what user is currently adjusting)
    
    @Published var stagedSelectedPlatforms: Set<String> = []
    @Published var stagedSelectedGenres: Set<String> = []
    @Published var stagedSortBy: String = "List order"
    @Published var stagedTastyScoreRange: ClosedRange<Double> = 0...100
    @Published var stagedAiScoreRange: ClosedRange<Double> = 0...10
    @Published var stagedWatchedStatus: String = "Any"
    @Published var stagedYearRange: ClosedRange<Int> = 1925...2025
    @Published var stagedLikedBy: String = "Any"
    @Published var stagedActors: String = ""
    
    // MARK: - Other Properties
    
    @Published var searchQuery: String = "" // Track search query for tab bar visibility
    
    // MARK: - Computed Properties (using applied filters)
    
    var hasActiveFilters: Bool {
        !appliedSelectedPlatforms.isEmpty || !appliedSelectedGenres.isEmpty || 
        appliedSortBy != "List order" || appliedWatchedStatus != "Any" ||
        appliedYearRange != (1925...2025) || appliedLikedBy != "Any" || !appliedActors.isEmpty ||
        appliedTastyScoreRange != (0...100) || appliedAiScoreRange != (0...10)
    }
    
    var platformFilterText: String {
        if appliedSelectedPlatforms.isEmpty {
            return "Platform: Any"
        } else if appliedSelectedPlatforms.count == 1 {
            return "Platform: \(appliedSelectedPlatforms.first ?? "")"
        } else {
            return "Platform: \(appliedSelectedPlatforms.count)+"
        }
    }
    
    var genreFilterText: String {
        if appliedSelectedGenres.isEmpty {
            return "Genres: Any"
        } else if appliedSelectedGenres.count == 1 {
            return "Genres: \(appliedSelectedGenres.first ?? "")"
        } else {
            return "Genres: \(appliedSelectedGenres.count)+"
        }
    }
    
    var yearFilterText: String {
        // Check if year range is the default (no filter applied)
        if appliedYearRange.lowerBound == 1925 && appliedYearRange.upperBound == 2025 {
            return "Year: Any"
        } else {
            // Format year range based on what's set
            if appliedYearRange.lowerBound == 1925 {
                // Only upper bound is set (e.g., "Before 1970")
                return "Year: Before \(appliedYearRange.upperBound)"
            } else if appliedYearRange.upperBound == 2025 {
                // Only lower bound is set (e.g., "After 1980")
                return "Year: After \(appliedYearRange.lowerBound)"
            } else {
                // Both bounds are set (e.g., "1970-1980")
                return "Year: \(appliedYearRange.lowerBound)-\(appliedYearRange.upperBound)"
            }
        }
    }
    
    // MARK: - Convenience Properties for Filter UI (use staged filters)
    
    // These are used by filter detail sheets - they work with staged filters
    var selectedPlatforms: Set<String> {
        get { stagedSelectedPlatforms }
        set { stagedSelectedPlatforms = newValue }
    }
    
    var selectedGenres: Set<String> {
        get { stagedSelectedGenres }
        set { stagedSelectedGenres = newValue }
    }
    
    var sortBy: String {
        get { stagedSortBy }
        set { stagedSortBy = newValue }
    }
    
    var tastyScoreRange: ClosedRange<Double> {
        get { stagedTastyScoreRange }
        set { stagedTastyScoreRange = newValue }
    }
    
    var aiScoreRange: ClosedRange<Double> {
        get { stagedAiScoreRange }
        set { stagedAiScoreRange = newValue }
    }
    
    var watchedStatus: String {
        get { stagedWatchedStatus }
        set { stagedWatchedStatus = newValue }
    }
    
    var yearRange: ClosedRange<Int> {
        get { stagedYearRange }
        set { stagedYearRange = newValue }
    }
    
    var likedBy: String {
        get { stagedLikedBy }
        set { stagedLikedBy = newValue }
    }
    
    var actors: String {
        get { stagedActors }
        set { stagedActors = newValue }
    }
    
    // MARK: - Methods
    
    /// Copy applied filters to staged filters (call when opening filter panel)
    func loadStagedFilters() {
        stagedSelectedPlatforms = appliedSelectedPlatforms
        stagedSelectedGenres = appliedSelectedGenres
        stagedSortBy = appliedSortBy
        stagedTastyScoreRange = appliedTastyScoreRange
        stagedAiScoreRange = appliedAiScoreRange
        stagedWatchedStatus = appliedWatchedStatus
        stagedYearRange = appliedYearRange
        stagedLikedBy = appliedLikedBy
        stagedActors = appliedActors
    }
    
    /// Apply staged filters to applied filters (call when user taps "Show Results")
    func applyStagedFilters() {
        print("🔄 [FILTER] Applying staged filters to applied filters")
        print("   Staged genres: \(Array(stagedSelectedGenres))")
        print("   Staged year range: \(stagedYearRange.lowerBound)-\(stagedYearRange.upperBound)")
        print("   Applied genres BEFORE: \(Array(appliedSelectedGenres))")
        print("   Applied year range BEFORE: \(appliedYearRange.lowerBound)-\(appliedYearRange.upperBound)")
        
        appliedSelectedPlatforms = stagedSelectedPlatforms
        appliedSelectedGenres = stagedSelectedGenres
        appliedSortBy = stagedSortBy
        appliedTastyScoreRange = stagedTastyScoreRange
        appliedAiScoreRange = stagedAiScoreRange
        appliedWatchedStatus = stagedWatchedStatus
        appliedYearRange = stagedYearRange  // This should trigger didSet
        appliedLikedBy = stagedLikedBy
        appliedActors = stagedActors
        
        print("   ✅ Applied genres AFTER: \(Array(appliedSelectedGenres))")
        print("   ✅ Applied year range AFTER: \(appliedYearRange.lowerBound)-\(appliedYearRange.upperBound)")
    }
    
    /// Reset staged filters to defaults (call when user taps "Reset")
    func resetStagedFilters() {
        stagedSelectedPlatforms = []
        stagedSelectedGenres = []
        stagedSortBy = "List order"
        stagedTastyScoreRange = 0...100
        stagedAiScoreRange = 0...10
        stagedWatchedStatus = "Any"
        stagedYearRange = 1925...2025
        stagedLikedBy = "Any"
        stagedActors = ""
    }
    
    /// Clear all applied filters (for filter chips)
    func clearAllAppliedFilters() {
        print("🗑️ [FILTER STATE] clearAllAppliedFilters() called - resetting all filters")
        appliedSelectedPlatforms = []
        appliedSelectedGenres = []
        appliedSortBy = "List order"
        appliedTastyScoreRange = 0...100
        appliedAiScoreRange = 0...10
        appliedWatchedStatus = "Any"
        appliedYearRange = 1925...2025  // This should trigger didSet
        appliedLikedBy = "Any"
        appliedActors = ""
    }
    
    func clearPlatformFilters() {
        appliedSelectedPlatforms = []
    }
    
    func clearGenreFilters() {
        appliedSelectedGenres = []
    }
}

