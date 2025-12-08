//  NotificationNames.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
//  Notes: Centralized notification names for Mango voice system

import Foundation

// MARK: - Notification Names for Mango Voice System

extension Notification.Name {
    /// Posted when Mango wants to navigate to the search tab
    static let mangoNavigateToSearch = Notification.Name("mangoNavigateToSearch")
    
    /// Posted when Mango wants to perform a movie search query
    static let mangoPerformMovieQuery = Notification.Name("mangoPerformMovieQuery")
    
    /// Posted when Mango wants to open a specific movie page
    static let mangoOpenMoviePage = Notification.Name("mangoOpenMoviePage")
    
    /// Posted when Mango marks a movie as watched (for UI updates)
    static let mangoMarkedWatched = Notification.Name("mangoMarkedWatched")
    
    /// Posted when Mango creates a watchlist (for UI updates)
    static let mangoCreatedWatchlist = Notification.Name("MangoCreatedWatchlist")
    
    /// Posted when a Mango action command completes (for dismissing listening view)
    static let mangoActionCommandCompleted = Notification.Name("mangoActionCommandCompleted")
}
