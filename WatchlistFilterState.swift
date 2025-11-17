//  WatchlistFilterState.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:55 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 04:02 (America/Los_Angeles - Pacific Time)
//  Notes: Created centralized filter state management for watchlist filtering with platform, genres, scores, year, liked by, and actors filters. Renamed FilterBadge to WatchlistFilterBadge to avoid naming conflict. Changed year filter from text fields to range slider (1925-2025).

import Foundation
import SwiftUI
import Combine

@MainActor
class WatchlistFilterState: ObservableObject {
    static let shared = WatchlistFilterState()
    
    // MARK: - Published Properties
    
    @Published var sortBy: String = "List order"
    @Published var selectedPlatforms: Set<String> = []
    @Published var tastyScoreRange: ClosedRange<Double> = 0...100
    @Published var aiScoreRange: ClosedRange<Double> = 0...10
    @Published var selectedGenres: Set<String> = []
    @Published var yearRange: ClosedRange<Int> = 1925...2025
    @Published var likedBy: String = "Any"
    @Published var actors: String = ""
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        !selectedPlatforms.isEmpty || !selectedGenres.isEmpty ||
        sortBy != "List order" || yearRange != (1925...2025) ||
        likedBy != "Any" || !actors.isEmpty ||
        tastyScoreRange != (0...100) || aiScoreRange != (0...10)
    }
    
    var activeFilterBadges: [WatchlistFilterBadge] {
        var badges: [WatchlistFilterBadge] = []
        
        if !selectedPlatforms.isEmpty {
            if selectedPlatforms.count == 1 {
                badges.append(WatchlistFilterBadge(title: "Platform: \(selectedPlatforms.first ?? "")", type: .platform))
            } else {
                badges.append(WatchlistFilterBadge(title: "Platform: \(selectedPlatforms.count)+", type: .platform))
            }
        }
        
        if !selectedGenres.isEmpty {
            if selectedGenres.count == 1 {
                badges.append(WatchlistFilterBadge(title: "Genres: \(selectedGenres.first ?? "")", type: .genre))
            } else {
                badges.append(WatchlistFilterBadge(title: "Genres: \(selectedGenres.count)+", type: .genre))
            }
        }
        
        if sortBy != "List order" {
            badges.append(WatchlistFilterBadge(title: "Sort: \(sortBy)", type: .sort))
        }
        
        if yearRange != (1925...2025) {
            let yearText = yearRange.lowerBound == 1925 ? "Before \(yearRange.upperBound)" : yearRange.upperBound == 2025 ? "After \(yearRange.lowerBound)" : "\(yearRange.lowerBound)-\(yearRange.upperBound)"
            badges.append(WatchlistFilterBadge(title: "Year: \(yearText)", type: .year))
        }
        
        if likedBy != "Any" {
            badges.append(WatchlistFilterBadge(title: "Liked by: \(likedBy)", type: .likedBy))
        }
        
        if !actors.isEmpty {
            badges.append(WatchlistFilterBadge(title: "Actors: \(actors)", type: .actor))
        }
        
        return badges
    }
    
    // MARK: - Methods
    
    func clearAllFilters() {
        sortBy = "List order"
        selectedPlatforms = []
        selectedGenres = []
        tastyScoreRange = 0...100
        aiScoreRange = 0...10
        yearRange = 1925...2025
        likedBy = "Any"
        actors = ""
    }
    
    func removeFilter(_ badge: WatchlistFilterBadge) {
        switch badge.type {
        case .platform:
            selectedPlatforms.removeAll()
        case .genre:
            selectedGenres.removeAll()
        case .sort:
            sortBy = "List order"
        case .year:
            yearRange = 1925...2025
        case .likedBy:
            likedBy = "Any"
        case .actor:
            actors = ""
        }
    }
}

// MARK: - Watchlist Filter Badge

struct WatchlistFilterBadge: Identifiable {
    let id = UUID()
    let title: String
    let type: FilterType
    
    enum FilterType {
        case platform
        case genre
        case sort
        case year
        case likedBy
        case actor
    }
}

