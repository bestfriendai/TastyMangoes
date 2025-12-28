//  CategoryResultsView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 21:30 (America/Los_Angeles - Pacific Time)
//  Notes: Updated to use real search results from Supabase instead of dummy data

import SwiftUI

struct CategoryResultsView: View {
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    // Use @ObservedObject for singleton to avoid recreating state
    @ObservedObject private var filterState = SearchFilterState.shared
    
    // Real search results from Supabase
    @State private var movies: [Movie] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showFilters = false
    
    // Get search query from filterState or use empty string
    private var searchQuery: String {
        filterState.searchQuery.isEmpty ? "" : filterState.searchQuery
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Top Nav Bar
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Search Input
                        HStack(spacing: 8) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(Color(hex: "#333333"))
                                    .frame(width: 20, height: 20)
                            }
                            
                            TextField("Searching film by name...", text: $searchText)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                                .onSubmit {
                                    filterState.searchQuery = searchText
                                    loadMovies()
                                }
                            
                            Spacer()
                            
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(hex: "#333333"))
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "mic.fill")
                                .foregroundColor(.black)
                                .frame(width: 20, height: 20)
                        }
                        .padding(12)
                        .background(Color(hex: "#f3f3f3"))
                        .cornerRadius(8)
                        
                        // Filter Button placeholder - will be added as overlay
                        Spacer()
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 16)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 2)
                
                // Results List
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Searching movies...")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                        Text("Error loading movies")
                            .font(.custom("Nunito-Bold", size: 20))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        Text(error.localizedDescription)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button(action: {
                            loadMovies()
                        }) {
                            Text("Try Again")
                                .font(.custom("Inter-SemiBold", size: 16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#8B5CF6"))
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if movies.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 64))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                        Text("No movies found")
                            .font(.custom("Nunito-Bold", size: 24))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        Text("Try adjusting your search or filters")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Filter Badges (show applied filters)
                            HStack(spacing: 4) {
                                if !filterState.appliedSelectedPlatforms.isEmpty {
                                    FilterBadge(
                                        title: "Platform:",
                                        count: filterState.appliedSelectedPlatforms.count,
                                        showAvatars: true
                                    )
                                }
                                
                                if !filterState.appliedSelectedGenres.isEmpty {
                                    FilterBadge(
                                        title: "Genres:",
                                        count: filterState.appliedSelectedGenres.count,
                                        showAvatars: false
                                    )
                                }
                                
                                // Sort Badge (always show if not default)
                                if filterState.appliedSortBy != "List order" {
                                    Button(action: {
                                        // Open filter sheet to sort section
                                        showFilters = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(filterState.sortFilterText)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#332100"))
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundColor(.black)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .cornerRadius(999)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .stroke(Color(hex: "#ececec"), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // Results count
                            HStack {
                                Text("\(movies.count) results found")
                                    .font(.custom("Inter-SemiBold", size: 14))
                                    .foregroundColor(Color(hex: "#666666"))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Movie Cards with Navigation
                            VStack(spacing: 8) {
                                ForEach(movies) { movie in
                                    NavigationLink(destination: MoviePageView(movieId: movie.id)) {
                                        MovieCardHorizontal(movie: movie)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .background(Color(hex: "#fdfdfd"))
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .task {
            // Load movies when view appears
            searchText = searchQuery
            loadMovies()
        }
        .onChange(of: filterState.appliedSelectedPlatforms) { oldValue, newValue in
            // Reload when applied filters change (only after "Show Results" is tapped)
            loadMovies()
        }
        .onChange(of: filterState.appliedSelectedGenres) { oldValue, newValue in
            // Reload when applied filters change (only after "Show Results" is tapped)
            loadMovies()
        }
        .onChange(of: filterState.appliedYearRange) { oldValue, newValue in
            // Reload when applied filters change (only after "Show Results" is tapped)
            loadMovies()
        }
        .onChange(of: filterState.appliedSortBy) { oldValue, newValue in
            // Reload when sort order changes
            loadMovies()
        }
        .sheet(isPresented: $showFilters) {
            SearchFiltersBottomSheet(isPresented: $showFilters) {
                // Trigger search when filters are applied
                print("🔄 [CATEGORY RESULTS] Filters applied, reloading movies")
                loadMovies()
            }
        }
        .onChange(of: showFilters) { oldValue, newValue in
            print("📋 [CATEGORY RESULTS] showFilters changed: \(oldValue) -> \(newValue)")
            if newValue {
                print("   ✅ Sheet should be presenting now")
            } else {
                print("   ❌ Sheet should be dismissed now")
            }
        }
        .overlay(alignment: .topTrailing) {
            // Filter Button as overlay - ensures it's above everything
            Button(action: {
                print("🔘 [CATEGORY RESULTS] Filter button OVERLAY tapped")
                print("   showFilters BEFORE: \(showFilters)")
                showFilters = true
                print("   showFilters AFTER: \(showFilters)")
            }) {
                ZStack {
                    Color(hex: "#f3f3f3")
                        .cornerRadius(8)
                    
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Color(hex: "#414141"))
                        .font(.system(size: 20))
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 16)
            .padding(.top, 76) // Match the nav bar padding
        }
    }
    
    // MARK: - Methods
    
    private func loadMovies() {
        isLoading = true
        error = nil
        
        Task {
            do {
                // Use Supabase search-movies endpoint with filters
                let query = searchQuery.isEmpty ? "popular" : searchQuery
                
                // Debug: Log current applied year range
                print("🔍 [CATEGORY] Current appliedYearRange: \(filterState.appliedYearRange.lowerBound)-\(filterState.appliedYearRange.upperBound)")
                
                // Get year range (only apply if not default range) - use APPLIED filters
                let yearRange: ClosedRange<Int>? = (filterState.appliedYearRange.lowerBound == 1925 && filterState.appliedYearRange.upperBound == 2025)
                    ? nil
                    : filterState.appliedYearRange
                
                // Get genres (only apply if not empty) - use APPLIED filters
                let genres: Set<String>? = filterState.appliedSelectedGenres.isEmpty ? nil : filterState.appliedSelectedGenres
                
                if let yearRange = yearRange {
                    print("   ✅ Year range: \(yearRange.lowerBound)-\(yearRange.upperBound) (will be sent to API)")
                } else {
                    print("   ⚠️ Year range: NIL (default range detected, not sending to API)")
                }
                
                if let genres = genres, !genres.isEmpty {
                    print("   ✅ Genres: \(genres.joined(separator: ", ")) (will be sent to API)")
                } else {
                    print("   ⚠️ Genres: NIL (no genres selected, not sending to API)")
                }
                
                let searchResults = try await SupabaseService.shared.searchMovies(
                    query: query,
                    yearRange: yearRange,
                    genres: genres
                )
                
                // Convert MovieSearchResult to Movie
                var convertedMovies = searchResults.map { result -> Movie in
                    Movie(
                        id: result.tmdbId,
                        title: result.title,
                        year: result.year ?? 0,
                        trailerURL: nil,
                        trailerDuration: nil,
                        posterImageURL: result.posterUrl,
                        tastyScore: nil,
                        aiScore: nil, // Category results are from TMDB, not database
                        voteAverage: result.voteAverage, // TMDB score (0-10 scale)
                        genres: [],
                        rating: nil,
                        director: nil,
                        writer: nil,
                        screenplay: nil,
                        composer: nil,
                        runtime: nil,
                        releaseDate: nil,
                        language: nil,
                        overview: result.overviewShort
                    )
                }
                
                // Apply sorting based on applied sortBy filter
                let sortBy = filterState.appliedSortBy
                print("🔀 [SORT] Applying sort: '\(sortBy)' to \(convertedMovies.count) movies")
                switch sortBy {
                case "Alphabetical":
                    // Sort alphabetically by title (A-Z)
                    convertedMovies.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    print("   ✅ Sorted alphabetically (A-Z)")
                case "Year":
                    // Sort by year (ascending - oldest first)
                    convertedMovies.sort { $0.year < $1.year }
                    print("   ✅ Sorted by year (oldest first)")
                case "Tasty Score":
                    // Sort by Tasty Score (descending - highest first)
                    convertedMovies.sort { ($0.tastyScore ?? 0) > ($1.tastyScore ?? 0) }
                    print("   ✅ Sorted by Tasty Score (highest first)")
                case "AI Score":
                    // Sort by AI Score (descending - highest first)
                    convertedMovies.sort { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
                    print("   ✅ Sorted by AI Score (highest first)")
                case "Watched":
                    // TODO: Implement watched sorting when watchlist data is available
                    // For now, sort watched movies first, then unwatched
                    convertedMovies.sort { movie1, movie2 in
                        let watched1 = WatchlistManager.shared.isWatched(movieId: movie1.id)
                        let watched2 = WatchlistManager.shared.isWatched(movieId: movie2.id)
                        if watched1 == watched2 {
                            return false // Keep relative order if both have same watched status
                        }
                        return watched1 && !watched2 // Watched movies first
                    }
                    print("   ✅ Sorted by watched status")
                default:
                    // "List order" - keep original order from API
                    print("   ✅ Keeping list order (no sort applied)")
                    break
                }
                
                await MainActor.run {
                    self.movies = convertedMovies
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    print("❌ Error loading movies: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterBadge: View {
    let title: String
    let count: Int
    let showAvatars: Bool
    
    var body: some View {
        Button(action: {
            // Open filter
        }) {
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#332100"))
                    
                    if showAvatars {
                        // Platform avatars
                        HStack(spacing: -4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(Color.teal)
                                .frame(width: 20, height: 20)
                        }
                        .padding(.trailing, 4)
                    } else {
                        Text("\(count)+")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(Color(hex: "#332100"))
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(999)
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color(hex: "#ececec"), lineWidth: 1)
            )
        }
    }
}

struct MovieCardHorizontal: View {
    let movie: Movie
    @State private var isWatched: Bool = false
    @State private var isInWatchlist: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster Image
            MoviePosterImage(
                posterURL: movie.posterImageURL,
                width: 81,
                height: 120,
                cornerRadius: 8
            )
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Top Section
                HStack(alignment: .top, spacing: 8) {
                    // Title and Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Text(String(movie.year))
                            Text("‧")
                            Text(movie.genres.joined(separator: "/"))
                            Text("‧")
                            Text(movie.runtime ?? "")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                        .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Ratings
                    VStack(alignment: .leading, spacing: 4) {
                        // Tasty Score
                        HStack(spacing: 2) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#648d00"))
                            
                            Text(movie.formattedTastyScore)
                                .font(.custom("Nunito-Bold", size: 14))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                        }
                        
                        // AI Score
                        HStack(spacing: 2) {
                            Image(systemName: "brain")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FEA500"))
                            
                            Text(movie.formattedAiScore)
                                .font(.custom("Nunito-Bold", size: 14))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                        }
                    }
                }
                
                // Bottom Section
                HStack(spacing: 8) {
                    // Watch On & Friends
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch on:")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#333333"))
                            
                            // Platform avatars
                            HStack(spacing: -6) {
                                ForEach(0..<3) { _ in
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: "#fdfdfd"), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .frame(width: 76)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Liked by:")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#333333"))
                            
                            // Friend avatars
                            HStack(spacing: -6) {
                                ForEach(0..<3) { _ in
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: "#fdfdfd"), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .frame(width: 76)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 4) {
                        // Mark as Watched
                        Button(action: {
                            isWatched.toggle()
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: isWatched ? "popcorn.fill" : "popcorn")
                                    .foregroundColor(Color(hex: "#414141"))
                                    .frame(width: 20, height: 20)
                                
                                if isWatched {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#8E8E93"))
                                        .background(Color.white.clipShape(Circle()))
                                        .offset(x: 8, y: -8)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#f3f3f3"))
                            .cornerRadius(8)
                        }
                        
                        // Add to Watchlist
                        Button(action: {
                            isInWatchlist.toggle()
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: isInWatchlist ? "list.bullet.clipboard.fill" : "list.bullet.clipboard")
                                    .foregroundColor(Color(hex: "#414141"))
                                    .frame(width: 20, height: 20)
                                
                                if isInWatchlist {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#FEA500"))
                                            .frame(width: 14, height: 14)
                                        
                                        Text("1")
                                            .font(.custom("Nunito-Bold", size: 10))
                                            .foregroundColor(.white)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: "#f3f3f3"), lineWidth: 1)
                                    )
                                    .offset(x: 8, y: -8)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#f3f3f3"))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, 4)
        }
        .padding(4)
        .background(Color(hex: "#fdfdfd"))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoryResultsView()
    }
}
