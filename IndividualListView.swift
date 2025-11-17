//  IndividualListView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-16 at 23:57 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:22 (America/Los_Angeles - Pacific Time)
//  Notes: Built individual list view (Manage List) with movie selection, drag handles, and management actions. Updated to match Figma design with hero section, search, filters, and Product Card format. Added filter state tracking and active filter badges. Added "Add movies to list" functionality for empty lists.

import SwiftUI

struct IndividualListView: View {
    let listId: String
    let listName: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    @State private var selectedMovieIds: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var searchText: String = ""
    @State private var showFilterSheet = false
    @State private var showManageMenu = false
    @State private var showAddMoviesSheet = false
    @State private var movies: [MasterlistMovie] = []
    @StateObject private var filterState = WatchlistFilterState.shared
    
    var body: some View {
        ZStack {
            Color(hex: "#fdfdfd")
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Section
                    heroSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    // Search and Filter
                    searchAndFilterSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // Applied Filters Badge
                    if hasActiveFilters {
                        appliedFiltersSection
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                    
                    // Movie List (Product Cards)
                    VStack(spacing: 12) {
                        // Create New Watchlist Card (if empty)
                        if movies.isEmpty {
                            Button(action: {
                                showAddMoviesSheet = true
                            }) {
                                CreateNewWatchlistCard()
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Movie Cards
                        ForEach(movies) { movie in
                            NavigationLink(destination: MoviePageView(movieId: Int(movie.id) ?? 0)) {
                                WatchlistProductCard(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFilterSheet) {
            WatchlistFiltersBottomSheet(isPresented: $showFilterSheet)
        }
        .sheet(isPresented: $showManageMenu) {
            ManageListBottomSheet(isPresented: $showManageMenu, listId: listId, listName: listName)
        }
        .fullScreenCover(isPresented: $showAddMoviesSheet) {
            AddMoviesToListView(listId: listId, listName: listName)
                .environmentObject(watchlistManager)
                .onDisappear {
                    // Reload movies after adding
                    loadMovies()
                }
        }
        .onAppear {
            loadMovies()
        }
    }
    
    private var hasActiveFilters: Bool {
        return filterState.hasActiveFilters
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 0) {
            // Top Navigation
            HStack(alignment: .center) {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .frame(width: 28, height: 28)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        showFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                            .frame(width: 28, height: 28)
                    }
                    
                    Button(action: {
                        showManageMenu = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                            .frame(width: 28, height: 28)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            // List Info
            HStack(alignment: .top, spacing: 16) {
                // List Thumbnail/Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#f3f3f3"))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#999999"))
                }
                
                // List Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(listName)
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Text("\(movies.count) films")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    Text("Your personalized collection of must-watch films.")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        HStack(spacing: 8) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
                
                TextField("Searching film by name...", text: $searchText)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#666666"))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(hex: "#f3f3f3"))
            .cornerRadius(8)
            
            // Filter Button
            Button(action: {
                showFilterSheet = true
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "#f3f3f3"))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Applied Filters Section
    
    private var appliedFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterState.activeFilterBadges) { badge in
                    HStack(spacing: 4) {
                        Text(badge.title)
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        Button(action: {
                            filterState.removeFilter(badge)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#333333"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#ffedcc"))
                    .cornerRadius(18)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
    
    // MARK: - Helper Methods
    
    private func loadMovies() {
        // Load movies for this list from watchlist manager
        let movieIds = watchlistManager.getMoviesInList(listId: listId)
        
        // For now, use mock data but filter by what's in the list
        // In a real app, this would fetch movie details from an API
        let allMovies = [
            MasterlistMovie(
                id: "1",
                title: "Jurassic World: Reborn",
                year: "2025",
                genres: ["Action", "Sci-Fi"],
                runtime: "2h 13m",
                posterURL: nil,
                tastyScore: 0.88,
                aiScore: 5.5,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "2",
                title: "Jurassic Park",
                year: "1993",
                genres: ["Action", "Sci-Fi"],
                runtime: "2h 5m",
                posterURL: nil,
                tastyScore: 0.99,
                aiScore: 7.2,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "3",
                title: "Juror #2",
                year: "2024",
                genres: ["Thriller", "Drama"],
                runtime: "1h 54min",
                posterURL: nil,
                tastyScore: 0.50,
                aiScore: 3.4,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "4",
                title: "Jurassic World: Dominion",
                year: "2022",
                genres: ["Action", "Sci-Fi"],
                runtime: "1h 50m",
                posterURL: nil,
                tastyScore: 0.67,
                aiScore: 6.8,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "5",
                title: "Jurassic World",
                year: "2015",
                genres: ["Action", "Sci-Fi"],
                runtime: "2h 20m",
                posterURL: nil,
                tastyScore: 0.95,
                aiScore: 9.1,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "6",
                title: "Jury Duty",
                year: "2023",
                genres: ["Comedy", "Thriller"],
                runtime: "1h 40m",
                posterURL: nil,
                tastyScore: 0.75,
                aiScore: 2.5,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "7",
                title: "Jurassic Park III",
                year: "2001",
                genres: ["Action", "Sci-Fi"],
                runtime: "1h 40m",
                posterURL: nil,
                tastyScore: 0.33,
                aiScore: 0.8,
                friendsCount: 3,
                isWatched: false
            ),
            MasterlistMovie(
                id: "8",
                title: "Jurassic World: Fallen Kingdom",
                year: "2018",
                genres: ["Action", "Sci-Fi"],
                runtime: "2h 8m",
                posterURL: nil,
                tastyScore: 0.24,
                aiScore: 4.7,
                friendsCount: 3,
                isWatched: false
            )
        ]
        
        // Filter to only show movies in this list, and update watched status
        movies = allMovies.filter { movieIds.contains($0.id) }.map { movie in
            // Update watched status from watchlist manager
            return MasterlistMovie(
                id: movie.id,
                title: movie.title,
                year: movie.year,
                genres: movie.genres,
                runtime: movie.runtime,
                posterURL: movie.posterURL,
                tastyScore: movie.tastyScore,
                aiScore: movie.aiScore,
                friendsCount: movie.friendsCount,
                isWatched: watchlistManager.isWatched(movieId: movie.id)
            )
        }
    }
    
    private func toggleSelection(_ movieId: String) {
        if selectedMovieIds.contains(movieId) {
            selectedMovieIds.remove(movieId)
        } else {
            selectedMovieIds.insert(movieId)
            if !isSelectionMode {
                isSelectionMode = true
            }
        }
        
        // Exit selection mode if nothing is selected
        if selectedMovieIds.isEmpty {
            isSelectionMode = false
        }
    }
    
    private func deleteSelectedMovies() {
        // Remove movies from the list
        for movieId in selectedMovieIds {
            watchlistManager.removeMovieFromList(movieId: movieId, listId: listId)
        }
        movies.removeAll { selectedMovieIds.contains($0.id) }
        selectedMovieIds.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Watchlist Product Card

struct WatchlistProductCard: View {
    let movie: MasterlistMovie
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster
            MoviePosterImage(
                posterURL: movie.posterURL,
                width: 80,
                height: 120,
                cornerRadius: 8
            )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(movie.title)
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .lineLimit(2)
                
                // Year, Genres, Runtime
                HStack(spacing: 4) {
                    Text(movie.year)
                    Text("·")
                    Text(movie.genres.prefix(2).joined(separator: "/"))
                    Text("·")
                    Text(movie.runtime)
                }
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
                
                // Scores
                HStack(spacing: 12) {
                    // Tasty Score
                    if let tastyScore = movie.tastyScore {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#FEA500"))
                            
                            Text("\(Int(tastyScore * 100))%")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                        }
                    }
                    
                    // AI Score
                    if let aiScore = movie.aiScore {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#FFD60A"))
                            
                            Text(String(format: "%.1f", aiScore))
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                        }
                    }
                }
                
                // Watch on and Liked by (placeholder avatars)
                HStack(spacing: 16) {
                    // Watch on
                    HStack(spacing: 4) {
                        Text("Watch on:")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        HStack(spacing: -4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color(hex: "#E0E0E0"))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    
                    // Liked by
                    HStack(spacing: 4) {
                        Text("Liked by:")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        HStack(spacing: -4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color(hex: "#E0E0E0"))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    IndividualListView(listId: "1", listName: "Masterlist")
}

