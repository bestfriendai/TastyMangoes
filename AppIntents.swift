//  AppIntents.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-17 at 12:00 (America/Los_Angeles - Pacific Time)
//  Notes: Siri integration with App Intents for searching movies and adding recommendations via voice commands

import AppIntents
import SwiftUI

// MARK: - Search Movie Intent

struct SearchMovieIntent: AppIntent {
    static var title: LocalizedStringResource = "Search for a movie"
    static var description = IntentDescription("Search for a movie in TastyMangoes")
    
    @Parameter(title: "Movie name")
    var movieName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$movieName)")
    }
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            SearchFilterState.shared.pendingSiriSearch = movieName
        }
        return .result(dialog: "Searching for \(movieName)")
    }
}

// MARK: - Add Recommendation Intent

struct AddRecommendationIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a movie recommendation"
    static var description = IntentDescription("Add a movie recommendation to your watchlist")
    
    @Parameter(title: "Movie name")
    var movieName: String
    
    @Parameter(title: "Recommended by")
    var recommenderName: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$movieName) recommended by \(\.$recommenderName)")
    }
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            SearchFilterState.shared.pendingSiriSearch = movieName
            SearchFilterState.shared.detectedRecommender = recommenderName
        }
        if let recommender = recommenderName {
            return .result(dialog: "Adding \(movieName) recommended by \(recommender)")
        } else {
            return .result(dialog: "Adding \(movieName)")
        }
    }
}

// MARK: - App Shortcuts Provider

struct TastyMangoesShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchMovieIntent(),
            phrases: [
                "Search for a movie in \(.applicationName)",
                "Find a movie in \(.applicationName)",
                "\(.applicationName) search for a movie"
            ],
            shortTitle: "Search Movie",
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: AddRecommendationIntent(),
            phrases: [
                "Add a movie recommendation in \(.applicationName)",
                "Add recommendation in \(.applicationName)"
            ],
            shortTitle: "Add Recommendation",
            systemImageName: "star.fill"
        )
    }
}

