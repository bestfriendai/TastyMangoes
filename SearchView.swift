//  SearchView.swift
//  TastyMangoes
//
//  Originally created by Cursor Assistant on 2025-11-14
//  Modified by Claude on 2025-12-01 at 11:15 PM (Pacific Time) - Added FocusState for keyboard management
//  Modified by Claude on 2025-12-02 at 12:20 AM (Pacific Time) - Fixed flashing "no movies found" issue
//  Last modified: 2025-12-03 at 09:39 PST by Cursor Assistant
//
//  Changes made by Claude (2025-12-02):
//  - Reordered content logic to keep previous results visible while searching
//  - Only show loading view when there are no results to display
//  - Only show empty state after search truly completes with no results
//  - This prevents the distracting flash of "Oops! No movies found" while typing
//
//  Changes made by Cursor Assistant (2025-12-03):
//  - Fixed mic button to show instant UI feedback (shows .requesting state immediately)
//  - Updated overlay to show ListeningIndicator for both .requesting and .listening states
//  - Added proper stopListening reason tracking
//  - Added explicit search trigger when recording finishes (onChange of state to .processing)
//  - Added debug logging for transcript changes and search queries

import SwiftUI

struct SearchView: View {
    @ObservedObject private var viewModel = SearchViewModel.shared
    // Use @ObservedObject for singleton to avoid recreating state
    @ObservedObject private var filterState = SearchFilterState.shared
    @State private var showFilters = false
    @State private var showPlatformsSheet = false
    @State private var showGenresSheet = false
    @State private var navigateToResults = false
    @State private var selectedFilterType: SearchFiltersBottomSheet.FilterType? = nil
    @FocusState private var isSearchFocused: Bool  // Added by Claude for keyboard management
    @State private var autoOpenMovieId: String? = nil  // For auto-opening single result from Mango
    @State private var showAutoOpenMovie = false  // Controls fullScreenCover for auto-open
    
    // Computed property for selection count (use applied filters for display)
    private var totalSelections: Int {
        filterState.appliedSelectedPlatforms.count + filterState.appliedSelectedGenres.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Content - Reordered to prevent flashing empty state
                if viewModel.searchQuery.isEmpty && !viewModel.hasSearched {
                    // Default: Show categories view when no search query and haven't searched
                    categoriesView
                } else if let error = viewModel.error {
                    // Show error if there's one
                    errorView(error: error)
                } else if !viewModel.searchResults.isEmpty {
                    // Show results - keep visible even while a new search is in progress
                    ZStack {
                        resultsListView
                        
                        // Subtle loading indicator overlay when searching with existing results
                        if viewModel.isSearching {
                            VStack {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(8)
                                        .background(Color.white.opacity(0.9))
                                        .cornerRadius(8)
                                        .shadow(radius: 2)
                                        .padding(.trailing, 20)
                                        .padding(.top, 8)
                                }
                                Spacer()
                            }
                        }
                    }
                } else if viewModel.isSearching {
                    // Only show full loading view when we have no results to display yet
                    loadingView
                } else if !viewModel.searchQuery.isEmpty && viewModel.hasSearched {
                    // Only show empty state after search truly completes with no results
                    emptyStateView
                } else {
                    // Fallback to categories
                    categoriesView
                }
            }
            .background(Color(hex: "#fdfdfd"))
            .onAppear {
                // Check for pending Mango query (race condition fix)
                // This ensures queries aren't lost if notification fires before SearchView is ready
                if let pendingQuery = filterState.pendingMangoQuery {
                    print("🍋 [SearchView] Found pending Mango query: '\(pendingQuery)'")
                    // Small delay to ensure tab navigation animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.search(query: pendingQuery)
                        // Clear the pending query after triggering search
                        filterState.pendingMangoQuery = nil
                        print("🍋 [SearchView] Triggered search for pending query and cleared it")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mangoOpenMoviePage)) { notification in
                // Auto-open movie page when Mango finds a single result
                if let movieId = notification.userInfo?["movieId"] as? String {
                    autoOpenMovieId = movieId
                    showAutoOpenMovie = true
                }
            }
            .onChange(of: viewModel.searchResults) { oldResults, newResults in
                // Mango speaks when search results update (only when search is complete)
                guard let query = viewModel.lastQuery, !viewModel.isSearching else { return }
                
                if newResults.isEmpty {
                    MangoSpeaker.shared.speak("I couldn't find anything for \(query).")
                } else if newResults.count == 1 {
                    MangoSpeaker.shared.speak("I found one movie for \(query).")
                } else {
                    MangoSpeaker.shared.speak("I found \(newResults.count) matches for \(query).")
                }
            }
            .fullScreenCover(isPresented: $showAutoOpenMovie) {
                if let movieId = autoOpenMovieId {
                    NavigationStack {
                        MoviePageView(movieId: movieId)
                    }
                }
            }
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
            .navigationDestination(isPresented: $navigateToResults) {
                CategoryResultsView()
            }
        }
        .sheet(isPresented: $showFilters) {
            SearchFiltersBottomSheet(
                isPresented: $showFilters,
                onApplyFilters: {
                    // Trigger search when filters are applied
                    if !viewModel.searchQuery.isEmpty {
                        viewModel.search()
                    }
                },
                initialFilterType: selectedFilterType
            )
        }
        .sheet(isPresented: $showPlatformsSheet) {
            SearchPlatformsBottomSheet(isPresented: $showPlatformsSheet)
        }
        .sheet(isPresented: $showGenresSheet) {
            SearchGenresBottomSheet(isPresented: $showGenresSheet)
        }
        .onChange(of: filterState.appliedSelectedPlatforms) { oldValue, newValue in
            // Re-search when applied filters change (only after "Show Results" is tapped)
            if !viewModel.searchQuery.isEmpty {
                viewModel.search()
            }
        }
        .onChange(of: filterState.appliedSelectedGenres) { oldValue, newValue in
            // Re-search when applied filters change (only after "Show Results" is tapped)
            if !viewModel.searchQuery.isEmpty {
                viewModel.search()
            }
        }
        .onChange(of: filterState.appliedYearRange) { oldValue, newValue in
            // Re-search when applied filters change (only after "Show Results" is tapped)
            if !viewModel.searchQuery.isEmpty {
                viewModel.search()
            }
        }
        .onChange(of: filterState.appliedSortBy) { oldValue, newValue in
            // Re-sort existing results immediately when sort changes
            print("🔀 [SEARCH VIEW] Sort changed: '\(oldValue)' -> '\(newValue)'")
            viewModel.applySorting()
        }
        .onChange(of: showFilters) { oldValue, newValue in
            // When filter sheet is dismissed without applying, staged filters are discarded
            // When "Show Results" is tapped, applyStagedFilters() is called which triggers onChange above
            if !newValue {
                // Sheet was dismissed - reset selectedFilterType
                selectedFilterType = nil
                // If filters weren't applied, they're already discarded
                // If they were applied, the onChange handlers above will trigger search
            }
        }
        // Voice recognition removed - use TalkToMango center button for voice input
    }
    
    // MARK: - Actions
    
    private func startSearching() {
        isSearchFocused = false  // Added by Claude - dismiss keyboard
        // Wire up NAVIGATE connection: Search button → Category Results View
        // Navigate to results view with selected filters
        navigateToResults = true
    }
    
    // MARK: - Voice Command Parsing
    
    private func parseVoiceCommand(_ transcript: String) -> (query: String, recommender: String?) {
        let lowercased = transcript.lowercased()
        
        // Pattern: "[Name] recommends [Movie]"
        if let range = lowercased.range(of: " recommends ") {
            let recommender = String(transcript[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let movie = String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !recommender.isEmpty && !movie.isEmpty {
                return (movie, recommender)
            }
        }
        
        // Pattern: "[Name] recommended [Movie]" (past tense, no "by")
        if let range = lowercased.range(of: " recommended ") {
            // Check if it's NOT "recommended by" pattern
            let afterRecommended = String(transcript[range.upperBound...]).lowercased()
            if !afterRecommended.hasPrefix("by ") {
                let recommender = String(transcript[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let movie = String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !recommender.isEmpty && !movie.isEmpty {
                    return (movie, recommender)
                }
            }
        }
        
        // Pattern: "[Movie] recommended by [Name]"
        if let range = lowercased.range(of: " recommended by ") {
            let movie = String(transcript[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let recommender = String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !recommender.isEmpty && !movie.isEmpty {
                return (movie, recommender)
            }
        }
        
        // No recommendation pattern found - just a regular search
        return (transcript, nil)
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
                        .focused($isSearchFocused)  // Added by Claude for keyboard management
                        .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                            print("📝 [SEARCH VIEW] Search query changed: '\(oldValue)' -> '\(newValue)'")
                            print("   Current appliedYearRange: \(filterState.appliedYearRange.lowerBound)-\(filterState.appliedYearRange.upperBound)")
                            filterState.searchQuery = newValue // Sync to filterState for tab bar
                            viewModel.search()
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            isSearchFocused = false  // Added by Claude - dismiss keyboard
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "#999999"))
                                .frame(width: 20, height: 20)
                        }
                    }
                    
                    // Mic button removed - use TalkToMango center button for voice input
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
            // Debug: Log what the badge will show
            let _ = print("🏷️ [BADGE] yearFilterText will show: '\(filterState.yearFilterText)' (appliedYearRange: \(filterState.appliedYearRange.lowerBound)-\(filterState.appliedYearRange.upperBound))")
            
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
                        
                        // Year Badge
                        FilterBadgeButton(
                            title: filterState.yearFilterText,
                            onTap: {
                                selectedFilterType = .year
                                showFilters = true
                            }
                        )
                        
                        // Sort Badge
                        FilterBadgeButton(
                            title: filterState.sortFilterText,
                            onTap: {
                                selectedFilterType = .sortBy
                                showFilters = true
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
                                    filterState.clearAllAppliedFilters()
                                    // Also clear search results when clearing filters
                                    viewModel.searchResults = []
                                    viewModel.hasSearched = false
                                    // Trigger search if we have a query
                                    if !viewModel.searchQuery.isEmpty {
                                        viewModel.search()
                                    }
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
