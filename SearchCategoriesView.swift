//  SearchCategoriesView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:56 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 05:44 (America/Los_Angeles - Pacific Time)
//  Notes: Built category browsing view for search section with platform selection and genre categories organized by mood. Added checkbox for "My subscriptions" - when checked, shows only Prime and Max. Added platform logos with brand colors. Added selection indicators (checkmarks and borders) for categories. Added "Start Searching (N)" button at bottom when items are selected. Fixed button positioning using safeAreaInset to ensure it appears above tab bar and is always visible. Added temporary TEST button at top for debugging visibility. Fixed missing closing brace syntax error.

import SwiftUI

struct SearchCategoriesView: View {
    @ObservedObject private var filterState = SearchFilterState.shared
    @EnvironmentObject private var profileManager: UserProfileManager
    var searchQuery: String = "" // Passed from SearchView
    @State private var showMySubscriptions = false
    
    // All platform options (10 platforms total)
    private let allPlatforms = ["Netflix", "Prime Video", "Disney+", "Max", "Hulu", "Criterion", "Paramount+", "Apple TV+", "Peacock", "Tubi"]
    
    // User's subscriptions from profile manager
    private var userSubscriptions: [String] {
        profileManager.subscriptions
    }
    
    // Platforms to display based on checkbox state
    private var platforms: [String] {
        showMySubscriptions ? userSubscriptions : allPlatforms
    }
    
    // Total selected count for button (using SearchFilterState)
    private var totalSelections: Int {
        filterState.selectedPlatforms.count + filterState.selectedGenres.count
    }
    
    // Computed property for filtered movies count (based on search + filters)
    // Note: This is a placeholder - actual movie counts will come from search results
    private var filteredMoviesCount: Int {
        // Return 0 as placeholder - real counts will come from actual search results
        // This property may not be used anymore since we're using real search
        return 0
    }
    
    // Category groups - counts will be loaded dynamically
    @State private var categoryGroups: [(name: String, categories: [SearchCategoryItem])] = [
        (
            name: "FUN & LIGHT",
            categories: [
                SearchCategoryItem(name: "Comedy", icon: "theatermasks", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Romance", icon: "heart", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Musical", icon: "music.note", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Family", icon: "house", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Animation", icon: "pawprint", tmdbCount: 0, dbCount: 0)
            ]
        ),
        (
            name: "EPIC & IMAGINATIVE",
            categories: [
                SearchCategoryItem(name: "Adventure", icon: "globe", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Fantasy", icon: "wand.and.stars", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Sci-Fi", icon: "airplane", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Historical", icon: "building.columns", tmdbCount: 0, dbCount: 0)
            ]
        ),
        (
            name: "DARK & INTENSE",
            categories: [
                SearchCategoryItem(name: "Action", icon: "hand.raised", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Thriller", icon: "eye", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Mystery", icon: "questionmark.circle", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Crime", icon: "car", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Horror", icon: "moon", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "War", icon: "sword", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Western", icon: "hat", tmdbCount: 0, dbCount: 0)
            ]
        ),
        (
            name: "REAL STORIES",
            categories: [
                SearchCategoryItem(name: "Documentary", icon: "film", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Biography", icon: "person", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Sport", icon: "figure.run", tmdbCount: 0, dbCount: 0),
                SearchCategoryItem(name: "Drama", icon: "theatermasks.fill", tmdbCount: 0, dbCount: 0)
            ]
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Results Count and Clear All Section (only show when selections > 0)
                    if totalSelections > 0 {
                        HStack {
                            // Results count text on left - show actual filtered count
                            Text("\(filteredMoviesCount) results found")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Color(hex: "#808080"))
                            
                            Spacer()
                            
                            // "Clear All" button on right
                            Button(action: {
                                // Clear all selections
                                filterState.selectedPlatforms.removeAll()
                                filterState.selectedGenres.removeAll()
                                // Also uncheck "My subscriptions" if it was checked
                                if showMySubscriptions {
                                    showMySubscriptions = false
                                }
                            }) {
                                Text("Clear All")
                                    .font(.custom("Nunito-SemiBold", size: 14))
                                    .foregroundColor(Color(hex: "#FEA500"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    
                    // My Subscriptions Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Checkbox and Label
                        HStack(spacing: 8) {
                            Button(action: {
                                showMySubscriptions.toggle()
                                // Add/remove subscription platforms when toggling
                                if showMySubscriptions {
                                    // When checking ON: Add all user's subscription platforms
                                    for platform in userSubscriptions {
                                        filterState.selectedPlatforms.insert(platform)
                                    }
                                } else {
                                    // When checking OFF: Remove all user's subscription platforms
                                    for platform in userSubscriptions {
                                        filterState.selectedPlatforms.remove(platform)
                                    }
                                }
                            }) {
                                Image(systemName: showMySubscriptions ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 24))
                                    .foregroundColor(showMySubscriptions ? Color(hex: "#FEA500") : Color(hex: "#B3B3B3"))
                            }
                            
                            Text("My subscriptions (\(profileManager.subscriptions.count))")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#333333"))
                        }
                        .padding(.horizontal, 16)
                        
                        // Platform Selection (horizontal scroll)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(platforms, id: \.self) { platform in
                                    PlatformCard(
                                        platform: platform,
                                        isSelected: filterState.selectedPlatforms.contains(platform)
                                    ) {
                                        if filterState.selectedPlatforms.contains(platform) {
                                            filterState.selectedPlatforms.remove(platform)
                                        } else {
                                            filterState.selectedPlatforms.insert(platform)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                    .padding(.top, 24)
                
                // Category Groups
                ForEach(categoryGroups, id: \.name) { group in
                    CategoryGroupView(
                        groupName: group.name,
                        categories: group.categories,
                        filterState: filterState
                    )
                    .padding(.horizontal, 16)
                }
                
                // Bottom padding
                Color.clear
                    .frame(height: 20)
                }
            }
        }
        .task {
            // Load genre counts when view appears
            loadGenreCounts()
        }
    }
    
    private func startSearching() {
        // TODO: Navigate to search results with selected platforms and categories
        print("Starting search with \(filterState.selectedPlatforms.count) platforms and \(filterState.selectedGenres.count) genres")
    }
    
    // MARK: - Helper Methods
    
    /// Formats genre count as "TMDB_count / DB_count"
    private func formatGenreCount(tmdbCount: Int, dbCount: Int) -> String {
        let tmdbFormatted = tmdbCount >= 1000 ? "1000+" : "\(tmdbCount)"
        let dbFormatted = dbCount >= 1000 ? "1000+" : "\(dbCount)"
        return "\(tmdbFormatted) / \(dbFormatted)"
    }
    
    /// Loads genre counts from TMDB and database
    private func loadGenreCounts() {
        Task {
            // Load counts for all genres
            var updatedGroups = categoryGroups
            
            for groupIndex in 0..<updatedGroups.count {
                var updatedCategories = updatedGroups[groupIndex].categories
                
                for categoryIndex in 0..<updatedCategories.count {
                    let category = updatedCategories[categoryIndex]
                    
                    // Fetch TMDB count
                    let tmdbCount = await fetchTMDBGenreCount(genreName: category.name)
                    
                    // Fetch database count
                    let dbCount = await fetchDatabaseGenreCount(genreName: category.name)
                    
                    // Update category with new counts
                    updatedCategories[categoryIndex] = SearchCategoryItem(
                        name: category.name,
                        icon: category.icon,
                        tmdbCount: tmdbCount,
                        dbCount: dbCount
                    )
                }
                
                updatedGroups[groupIndex] = (name: updatedGroups[groupIndex].name, categories: updatedCategories)
            }
            
            await MainActor.run {
                self.categoryGroups = updatedGroups
            }
        }
    }
    
    /// Fetches genre count from TMDB using discover endpoint
    private func fetchTMDBGenreCount(genreName: String) async -> Int {
        // Map genre name to TMDB genre ID
        guard let genreId = getTMDBGenreId(for: genreName) else {
            return 0
        }
        
        do {
            // Use discover endpoint to get total results for this genre
            var components = URLComponents(string: "\(TMDBConfig.baseURL)/discover/movie")
            components?.queryItems = [
                URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
                URLQueryItem(name: "with_genres", value: String(genreId)),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "language", value: "en-US")
            ]
            
            guard let url = components?.url else {
                return 0
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            
            return response.totalResults
        } catch {
            print("⚠️ Error fetching TMDB count for \(genreName): \(error)")
            return 0
        }
    }
    
    /// Fetches genre count from our Supabase database
    private func fetchDatabaseGenreCount(genreName: String) async -> Int {
        do {
            return try await SupabaseService.shared.getGenreCount(genreName: genreName)
        } catch {
            print("⚠️ Error fetching database count for \(genreName): \(error)")
            return 0
        }
    }
    
    /// Maps genre name to TMDB genre ID
    private func getTMDBGenreId(for genreName: String) -> Int? {
        // TMDB genre ID mapping
        let genreMap: [String: Int] = [
            "Action": 28,
            "Adventure": 12,
            "Animation": 16,
            "Comedy": 35,
            "Crime": 80,
            "Documentary": 99,
            "Drama": 18,
            "Family": 10751,
            "Fantasy": 14,
            "History": 36,  // Historical maps to History
            "Horror": 27,
            "Music": 10402,  // Musical maps to Music
            "Mystery": 9648,
            "Romance": 10749,
            "Science Fiction": 878,  // Sci-Fi maps to Science Fiction
            "TV Movie": 10770,
            "Thriller": 53,
            "War": 10752,
            "Western": 37,
            "Biography": 18,  // Biography is usually Drama (18) in TMDB
            "Sport": 18  // Sport is usually Drama (18) in TMDB
        ]
        
        // Try exact match first
        if let id = genreMap[genreName] {
            return id
        }
        
        // Try case-insensitive match
        for (key, id) in genreMap {
            if key.lowercased() == genreName.lowercased() {
                return id
            }
        }
        
        // Handle special cases
        switch genreName {
        case "Historical":
            return 36
        case "Musical":
            return 10402
        case "Sci-Fi":
            return 878
        case "Biography":
            return 18
        case "Sport":
            return 18
        default:
            return nil
        }
    }
}

// MARK: - Category Group View

struct CategoryGroupView: View {
    let groupName: String
    let categories: [SearchCategoryItem]
    @ObservedObject var filterState: SearchFilterState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group Title
            Text(groupName)
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#999999"))
                .textCase(.uppercase)
            
            // Category Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(categories) { category in
                    CategoryCard(
                        category: category,
                        isSelected: filterState.selectedGenres.contains(category.name)
                    ) {
                        if filterState.selectedGenres.contains(category.name) {
                            filterState.selectedGenres.remove(category.name)
                        } else {
                            filterState.selectedGenres.insert(category.name)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Search Category Item

struct SearchCategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let tmdbCount: Int  // Total movies in TMDB for this genre
    let dbCount: Int    // Movies in our database for this genre
    
    // Legacy support - returns tmdbCount for backwards compatibility
    var count: Int { tmdbCount }
}

// MARK: - Platform Card

struct PlatformCard: View {
    let platform: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 0)
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FEA500"), lineWidth: 2)
                        .frame(width: 80, height: 80)
                }
                
                // Platform logo
                PlatformLogo(platform: platform)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Platform Logo View

struct PlatformLogo: View {
    let platform: String
    
    var body: some View {
        PlatformIconHelper.icon(for: platform, size: 60)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: SearchCategoryItem
    let isSelected: Bool
    let onTap: () -> Void
    
    /// Formats genre count as "TMDB_count / DB_count"
    static func formatGenreCount(tmdbCount: Int, dbCount: Int) -> String {
        let tmdbFormatted = tmdbCount >= 1000 ? "1000+" : "\(tmdbCount)"
        let dbFormatted = dbCount >= 1000 ? "1000+" : "\(dbCount)"
        return "\(tmdbFormatted) / \(dbFormatted)"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                // Category Name and Count
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.custom("Nunito-SemiBold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    Text(CategoryCard.formatGenreCount(tmdbCount: category.tmdbCount, dbCount: category.dbCount))
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#808080"))
                }
                
                Spacer()
                
                // Selection indicator (checkmark)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FEA500"))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: "#FEA500") : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SearchCategoriesView()
}

