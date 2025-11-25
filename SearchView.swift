//  SearchView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-14 at 09:59 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 04:45 (America/Los_Angeles - Pacific Time)
//  Notes: Search view with search bar, suggestions, results, and filter functionality. Updated to show yellow header with "Find Your Movie" title and description when empty (categories view), simpler white header when searching. Removed automatic popular movies loading. Changed to show real-time search results as user types instead of suggestions. Categories view shows by default when search query is empty.

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var filterState = SearchFilterState.shared
    @State private var showFilters = false
    @State private var showPlatformsSheet = false
    @State private var showGenresSheet = false
    @State private var navigateToResults = false
    
    // Computed property for selection count
    private var totalSelections: Int {
        filterState.selectedPlatforms.count + filterState.selectedGenres.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Content
                if viewModel.searchQuery.isEmpty && !viewModel.hasSearched {
                    // Default: Show categories view when no search query and haven't searched
                    categoriesView
                } else if viewModel.isSearching {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else if !viewModel.searchQuery.isEmpty && !viewModel.searchResults.isEmpty {
                    // Show real-time search results as user types (has query and has results)
                    resultsListView
                } else if !viewModel.searchQuery.isEmpty && viewModel.searchResults.isEmpty && viewModel.hasSearched {
                    // Show empty state when query exists but no results found
                    emptyStateView
                } else {
                    // Fallback to categories
                    categoriesView
                }
            }
            .background(Color(hex: "#fdfdfd"))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Start Searching Button - show when selections > 0 OR search query is not empty
                if totalSelections > 0 || !viewModel.searchQuery.isEmpty {
                    VStack(spacing: 0) {
                        Button(action: {
                            startSearching()
                        }) {
                            // Show count if there are selections, otherwise just "Start Searching"
                            let buttonText = totalSelections > 0 
                                ? "Start Searching (\(totalSelections))"
                                : "Start Searching"
                            Text(buttonText)
                                .font(.custom("Nunito-Bold", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#333333"))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                        .background(Color.white)
                    }
                } else {
                    Color.clear.frame(height: 0)
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            SearchFiltersBottomSheet(isPresented: $showFilters)
        }
        .sheet(isPresented: $showPlatformsSheet) {
            SearchPlatformsBottomSheet(isPresented: $showPlatformsSheet)
        }
        .sheet(isPresented: $showGenresSheet) {
            SearchGenresBottomSheet(isPresented: $showGenresSheet)
        }
        .navigationDestination(isPresented: $navigateToResults) {
            CategoryResultsView()
        }
        .onChange(of: filterState.selectedPlatforms) { oldValue, newValue in
            // Reset results when filters change
            if newValue.isEmpty && filterState.selectedGenres.isEmpty {
                viewModel.searchResults = []
                viewModel.hasSearched = false
            }
        }
        .onChange(of: filterState.selectedGenres) { oldValue, newValue in
            // Reset results when filters change
            if newValue.isEmpty && filterState.selectedPlatforms.isEmpty {
                viewModel.searchResults = []
                viewModel.hasSearched = false
            }
        }
    }
    
    // MARK: - Actions
    
    private func startSearching() {
        // Wire up NAVIGATE connection: Search button → Category Results View
        // Navigate to results view with selected filters
        navigateToResults = true
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 0) {
            // Show title section only when search is empty (categories view)
            if viewModel.searchQuery.isEmpty && !viewModel.hasSearched && viewModel.searchResults.isEmpty {
                // Top section with title and avatar
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Find Your Movie 🎬")
                            .font(.custom("Nunito-Bold", size: 28))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        
                        Text("Type a title or pick a genre")
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Text("to discover the film you're looking for.")
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                    
                    Spacer()
                    
                    // Avatar
                    Circle()
                        .fill(Color(hex: "#E0E0E0"))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#666666"))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            
            // Search Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "#666666"))
                        .frame(width: 20, height: 20)
                    
                    TextField("Searching by name...", text: $viewModel.searchQuery)
                        .font(.custom("Inter-Regular", size: 16))
                        .foregroundColor(Color(hex: "#666666"))
                        .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                            filterState.searchQuery = newValue // Sync to filterState for tab bar
                            viewModel.search()
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "#999999"))
                                .frame(width: 20, height: 20)
                        }
                    }
                    
                    Image(systemName: "mic.fill")
                        .foregroundColor(Color(hex: "#666666"))
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(hex: "#f3f3f3"))
                .cornerRadius(8)
                
                Button(action: {
                    showFilters = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#666666"))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#f3f3f3"))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, viewModel.searchQuery.isEmpty && !viewModel.hasSearched && viewModel.searchResults.isEmpty ? 0 : 16)
            .padding(.bottom, 12)
            
            // Filter Badges (only show when there are active filters or search results)
            if filterState.hasActiveFilters || !viewModel.searchResults.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Platform Badge
                        FilterBadgeButton(
                            title: filterState.platformFilterText,
                            onTap: {
                                showPlatformsSheet = true
                            }
                        )
                        
                        // Genre Badge
                        FilterBadgeButton(
                            title: filterState.genreFilterText,
                            onTap: {
                                showGenresSheet = true
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
                .padding(.bottom, 12)
            }
        }
        .background(
            // Yellow gradient background when showing categories, white when searching
            viewModel.searchQuery.isEmpty && !viewModel.hasSearched && viewModel.searchResults.isEmpty
                ? LinearGradient(
                    colors: [Color(hex: "#FFD60A"), Color(hex: "#FFA500")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
        )
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Searching movies...")
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(error: TMDBError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FF6B6B"))
            
            Text("Oops!")
                .font(.custom("Nunito-Bold", size: 24))
                .foregroundColor(Color(hex: "#1a1a1a"))
            
            Text(error.localizedDescription)
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                Task {
                    await viewModel.loadPopularMovies()
                }
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
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            // Back button - show when search query is not empty
            if !viewModel.searchQuery.isEmpty {
                HStack {
                    Button(action: {
                        // Clear search and return to genre/platform selection
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#333333"))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
            VStack(spacing: 16) {
                Image(systemName: "film")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                
                Text("No movies found")
                    .font(.custom("Nunito-Bold", size: 24))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Text("Try a different search term")
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.searchQuery.isEmpty {
                    // Show search history
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Last Searching Results")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                        
                        let history = SearchHistoryManager.shared.getSearchHistory()
                        if history.isEmpty {
                            Text("No recent searches")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Color(hex: "#999999"))
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        } else {
                            ForEach(history, id: \.self) { item in
                                SearchHistoryItem(
                                    query: item,
                                    onTap: {
                                        viewModel.selectSuggestion(item)
                                    },
                                    onRemove: {
                                        SearchHistoryManager.shared.removeFromHistory(item)
                                    }
                                )
                            }
                        }
                    }
                } else {
                    // Show suggestions
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchSuggestions, id: \.self) { suggestion in
                            SearchSuggestionItem(
                                suggestion: suggestion,
                                query: viewModel.searchQuery,
                                onTap: {
                                    viewModel.selectSuggestion(suggestion)
                                }
                            )
                        }
                    }
                }
            }
        }
        .background(Color(hex: "#fdfdfd"))
    }
    
    // MARK: - Results List
    
    private var resultsListView: some View {
        return VStack(spacing: 0) {
            // Back button - only show when search query is not empty
            if !viewModel.searchQuery.isEmpty {
                HStack {
                    Button(action: {
                        // Clear search and return to genre/platform selection
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#333333"))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
            ScrollView {
                VStack(spacing: 16) {
                    // Results count (only show when there are results or active filters)
                    if !viewModel.searchResults.isEmpty || filterState.hasActiveFilters {
                        HStack {
                            // Show count based on whether we have search results or just filters
                            let resultsText = !viewModel.searchResults.isEmpty 
                                ? "\(viewModel.searchResults.count) results found"
                                : (filterState.hasActiveFilters ? "0 results found" : "")
                            
                            if !resultsText.isEmpty {
                                Text(resultsText)
                                    .font(.custom("Inter-SemiBold", size: 14))
                                    .foregroundColor(Color(hex: "#666666"))
                            }
                            
                            Spacer()
                            
                            // Clear All button when filters are active
                            if filterState.hasActiveFilters {
                                Button(action: {
                                    filterState.clearAllFilters()
                                    // Also clear search results when clearing filters
                                    viewModel.searchResults = []
                                    viewModel.hasSearched = false
                                }) {
                                    Text("Clear All")
                                        .font(.custom("Nunito-SemiBold", size: 14))
                                        .foregroundColor(Color(hex: "#FEA500"))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                
                    // Movie cards
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.searchResults) { movie in
                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                SearchMovieCard(movie: movie)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Categories View
    
    private var categoriesView: some View {
        return SearchCategoriesView(searchQuery: viewModel.searchQuery)
    }
    
    // MARK: - Popular Movies View
    
    private var popularMoviesView: some View {
        return ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Popular Movies")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.loadTrendingMovies()
                        }
                    }) {
                        Text("Trending")
                            .font(.custom("Inter-SemiBold", size: 14))
                            .foregroundColor(Color(hex: "#8B5CF6"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Movie cards
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.searchResults) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                            SearchMovieCard(movie: movie)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Search Movie Card (Product Card)

struct SearchMovieCard: View {
    let movie: Movie
    @State private var showMoviePage = false
    
    var body: some View {
        Button(action: {
            // Wire up NAVIGATE connection: Product Card → Movie Page
            showMoviePage = true
        }) {
            HStack(alignment: .top, spacing: 12) {
            // Poster
            MoviePosterImage(
                posterURL: movie.posterImageURL,
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
                    if movie.year > 0 {
                        Text(String(movie.year))
                        Text("·")
                    }
                    
                    if !movie.genres.isEmpty {
                        Text(movie.genres.prefix(2).joined(separator: "/"))
                        if let runtime = movie.runtime, !runtime.isEmpty {
                            Text("·")
                            Text(runtime)
                        }
                    } else if let runtime = movie.runtime, !runtime.isEmpty {
                        Text(runtime)
                    }
                }
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
                
                // Scores
                HStack(spacing: 12) {
                    // Tasty Score
                    if let tastyScore = movie.tastyScore {
                        HStack(spacing: 4) {
                            // Use mango icon if available, otherwise use star
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
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showMoviePage) {
            NavigationStack {
                MoviePageView(movieId: movie.id)
            }
        }
    }
}

// MARK: - Filter Badge Button

struct FilterBadgeButton: View {
    let title: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#333333"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#ffedcc"))
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search History Item

struct SearchHistoryItem: View {
    let query: String
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 20)
                
                Text(query)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#999999"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Suggestion Item

struct SearchSuggestionItem: View {
    let suggestion: String
    let query: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 20)
                
                Text(suggestion)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
