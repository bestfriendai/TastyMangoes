//
//  SearchView.swift
//  TastyMangoes
//
//  Originally created by Cursor Assistant on 2025-11-14
//  Modified by Claude on 2025-12-01 at 11:15 PM (Pacific Time) - Added FocusState for keyboard management
//  Modified by Claude on 2025-12-02 at 12:20 AM (Pacific Time) - Fixed flashing "no movies found" issue
//  Modified by Claude on 2025-12-15 at 11:10 AM (Pacific Time) - Phase 2: Added voice search selection tracking
//  Modified by Claude on 2025-12-15 at 5:15 PM (Pacific Time) - Fixed candidates_shown always 0 bug
//
//  Changes made by Claude (2025-12-02):
//  - Reordered content logic to keep previous results visible while searching
//  - Only show loading view when there are no results to display
//  - Only show empty state after search truly completes with no results
//  - This prevents the distracting flash of "Oops! No movies found" while typing
//
//  Changes made by Claude (2025-12-15 11:10 AM):
//  - SearchMovieCard now tracks voice search selections (selected_movie_id, candidates_shown)
//  - Logs to Supabase when user taps a movie from voice-initiated search results
//
//  Changes made by Claude (2025-12-15 5:15 PM):
//  - Changed viewModel from @StateObject to @ObservedObject using SearchViewModel.shared
//  - This fixes candidates_shown always showing 0 (SearchMovieCard was reading from .shared
//    while SearchView had its own instance with the actual results)

import SwiftUI

struct SearchView: View {
    // FIXED: Use shared instance so SearchMovieCard can read correct searchResults.count
    @ObservedObject private var viewModel = SearchViewModel.shared
    // Use @ObservedObject for singleton to avoid recreating state
    @ObservedObject private var filterState = SearchFilterState.shared
    @ObservedObject private var hintSearchCoordinator = HintSearchCoordinator.shared
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showFilters = false
    @State private var showPlatformsSheet = false
    @State private var showGenresSheet = false
    @State private var navigateToResults = false
    @State private var selectedFilterType: SearchFiltersBottomSheet.FilterType? = nil
    @FocusState private var isSearchFocused: Bool  // Added by Claude for keyboard management
    
    // Computed property for selection count (use applied filters for display)
    private var totalSelections: Int {
        filterState.appliedSelectedPlatforms.count + filterState.appliedSelectedGenres.count
    }
    
    // Extract main content to help compiler type-check
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.searchQuery.isEmpty && !viewModel.hasSearched {
            categoriesView
        } else if let error = viewModel.error {
            errorView(error: error)
        } else if !viewModel.searchResults.isEmpty {
            ZStack {
                resultsListView
                VStack {
                    HStack {
                        Spacer()
                        if viewModel.isSearching {
                            ProgressView()
                                .padding(8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                                .padding(.trailing, 20)
                                .padding(.top, 8)
                        } else if let progress = hintSearchCoordinator.verificationProgress {
                            Text("Verifying \(progress.current) of \(progress.total)...")
                                .font(.custom("Nunito-Regular", size: 14))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                                .padding(.trailing, 20)
                                .padding(.top, 8)
                        }
                    }
                    Spacer()
                }
            }
        } else if viewModel.isSearching {
            loadingView
        } else if !viewModel.searchQuery.isEmpty && viewModel.hasSearched {
            emptyStateView
        } else {
            categoriesView
        }
    }
    
    // Extract bottom button to help compiler
    @ViewBuilder
    private var bottomButton: some View {
        // Hide button when there are search results or when searching is in progress
        let shouldShowButton = (totalSelections > 0 || !viewModel.searchQuery.isEmpty) 
            && viewModel.searchResults.isEmpty 
            && !hintSearchCoordinator.isSearching
            && !hintSearchCoordinator.isAISearching
        
        if shouldShowButton {
            VStack(spacing: 0) {
                let buttonText = totalSelections > 0
                    ? "Start Searching (\(totalSelections))"
                    : "Start Searching"
                Button(action: startSearching) {
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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    searchHeader
                    mainContent
                }
                .background(Color(hex: "#fdfdfd"))
                
                // Bottom button overlay - positioned above tab bar without creating its own safeAreaInset
                bottomButton
                    .background(Color.white) // Ensure white background extends to edge
                    .padding(.bottom, 80) // Space for tab bar height (tab bar is in TabBarView's safeAreaInset)
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
        .onAppear {
            // Check for pending Mango query when SearchView appears (fallback for race conditions)
            if let pendingQuery = filterState.pendingMangoQuery, !pendingQuery.isEmpty {
                print("🍋 [SearchView] onAppear - Found pending Mango query: '\(pendingQuery)'")
                print("🍋 [SearchView] Triggering search for pending query")
                viewModel.isMangoInitiatedSearch = true
                viewModel.search(query: pendingQuery)
                // Clear the pending query after processing
                filterState.pendingMangoQuery = nil
            } else {
                print("🍋 [SearchView] onAppear - No pending Mango query")
            }
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
        .onChange(of: speechRecognizer.transcript) { oldValue, newValue in
            // Update search text when transcript changes
            if !newValue.isEmpty {
                let parsed = parseVoiceCommand(newValue)
                viewModel.searchQuery = parsed.query
                filterState.searchQuery = parsed.query
                
                if let recommender = parsed.recommender {
                    filterState.detectedRecommender = recommender
                    print("🎤 Detected recommendation: '\(parsed.query)' from '\(recommender)'")
                    print("🎤 Stored recommender in filterState: \(recommender)")
                } else {
                    // Clear recommender if no pattern detected
                    filterState.detectedRecommender = nil
                }
                // Search will be triggered automatically by the onChange(of: viewModel.searchQuery) modifier
            }
        }
        .overlay(alignment: .top) {
            if case .listening = speechRecognizer.state {
                ListeningIndicator(
                    transcript: speechRecognizer.transcript,
                    onStop: {
                        Task {
                            speechRecognizer.stopListening()
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: speechRecognizer.state)
            }
        }
        .onDisappear {
            // Stop microphone when navigating away
            if case .listening = speechRecognizer.state {
                Task {
                    speechRecognizer.stopListening()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startSearching() {
        isSearchFocused = false  // Added by Claude - dismiss keyboard
        // Wire up NAVIGATE connection: Search button → Category Results View
        // Navigate to results view with selected filters
        // NOTE: CategoryResultsView makes a separate API call and doesn't share SearchViewModel.shared.searchResults
        // This can cause "No movies found" to appear briefly until the API call completes
        // Consider refactoring CategoryResultsView to use SearchViewModel.shared.searchResults if query matches
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
                    
                    Button(action: {
                        Task {
                            switch speechRecognizer.state {
                            case .listening:
                                speechRecognizer.stopListening()
                            case .idle, .error:
                                await speechRecognizer.startListening()
                            default:
                                break
                            }
                        }
                    }) {
                        Image(systemName: speechRecognizer.state == .listening ? "stop.circle.fill" : "mic.fill")
                            .foregroundColor(speechRecognizer.state == .listening ? .red : Color(hex: "#666666"))
                            .frame(width: 20, height: 20)
                    }
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
                            if !viewModel.searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Show animated indicator if hint search is in progress
                                    if hintSearchCoordinator.isSearching || hintSearchCoordinator.isAISearching {
                                        HStack(spacing: 0) {
                                            Text("\(viewModel.searchResults.count) results")
                                                .font(.custom("Inter-SemiBold", size: 14))
                                                .foregroundColor(Color(hex: "#666666"))
                                            
                                            AnimatedEllipsisView()
                                        }
                                        
                                        // Show verification progress if available
                                        if let progress = hintSearchCoordinator.verificationProgress {
                                            Text("Verifying \(progress.current) of \(progress.total)...")
                                                .font(.custom("Inter-Regular", size: 12))
                                                .foregroundColor(Color(hex: "#999999"))
                                        } else if hintSearchCoordinator.isAISearching {
                                            Text("Loading more results...")
                                                .font(.custom("Inter-Regular", size: 12))
                                                .foregroundColor(Color(hex: "#999999"))
                                        }
                                    } else {
                                        Text("\(viewModel.searchResults.count) results found")
                                            .font(.custom("Inter-SemiBold", size: 14))
                                            .foregroundColor(Color(hex: "#666666"))
                                    }
                                }
                            } else if filterState.hasActiveFilters {
                                Text("0 results found")
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
                            SearchMovieCard(movie: movie)
                                .onTapGesture {
                                    // Stop speech recognizer when navigating to movie detail
                                    if case .listening = speechRecognizer.state {
                                        Task {
                                            speechRecognizer.stopListening()
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for tab bar (will be adjusted by safeAreaInset)
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
                        .simultaneousGesture(TapGesture().onEnded {
                            // Stop speech recognizer when navigating to movie detail
                            if case .listening = speechRecognizer.state {
                                Task {
                                    speechRecognizer.stopListening()
                                }
                            }
                        })
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Search Movie Card (Product Card)
// Last modified by Claude on 2025-12-15 at 11:10 AM (Pacific Time)
// Phase 2: Added voice search selection tracking (selected_movie_id, candidates_shown)

struct SearchMovieCard: View {
    let movie: Movie
    @State private var showMoviePage = false
    
    private let watchlistManager = WatchlistManager.shared
    
    // Check if movie is in any watchlist
    private var isInWatchlist: Bool {
        !watchlistManager.getListsForMovie(movieId: movie.id).isEmpty
    }
    
    // Check if movie is watched
    private var isWatched: Bool {
        watchlistManager.isWatched(movieId: movie.id)
    }
    
    // Calculate Tasty Score from aiScore (aiScore × 10, e.g., 71.6 → 716%)
    // aiScore is on 0-100 scale, we want to show as percentage × 10
    // So 71.6 becomes 7.16 (on 0-1 scale), which displays as 716% when multiplied by 100
    private var tastyScore: Double? {
        if let aiScore = movie.aiScore {
            return aiScore / 10.0 // Convert 71.6 to 7.16 (0-1 scale), displays as 716%
        }
        return movie.tastyScore
    }
    
    // Calculate Tasty Score percentage directly (aiScore × 10)
    private var tastyScorePercentage: Int? {
        if let aiScore = movie.aiScore {
            return Int(aiScore * 10) // 71.6 → 716
        }
        if let tastyScore = movie.tastyScore {
            return Int(tastyScore * 100) // Already on 0-1 scale
        }
        return nil
    }
    
    var body: some View {
        Button(action: {
            // Phase 2: Track movie selection if this was a voice search
            trackVoiceSearchSelection()
            
            // Wire up NAVIGATE connection: Product Card → Movie Page
            showMoviePage = true
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Poster
                MoviePosterImage(
                    posterURL: movie.posterImageURL,
                    width: 60,
                    height: 90,
                    cornerRadius: 8
                )
                
                // Movie Info
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(movie.title)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .lineLimit(1)
                    
                    // Year, Genre, Runtime
                    let genresText = movie.genres.isEmpty ? "" : movie.genres.joined(separator: "/")
                    let runtimeText = movie.runtime ?? ""
                    let metadataParts = [
                        movie.year > 0 ? String(movie.year) : nil,
                        genresText.isEmpty ? nil : genresText,
                        runtimeText.isEmpty ? nil : runtimeText
                    ].compactMap { $0 }
                    
                    if !metadataParts.isEmpty {
                        Text(metadataParts.joined(separator: " · "))
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                            .lineLimit(1)
                    }
                    
                    // Scores and Friends
                    HStack(spacing: 12) {
                        // Tasty Score (use aiScore × 10 if available)
                        if let tastyScorePercent = tastyScorePercentage {
                            HStack(spacing: 4) {
                                Image("TastyScoreIcon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                Text("\(tastyScorePercent)%")
                                    .font(.custom("Inter-SemiBold", size: 12))
                                    .foregroundColor(Color(hex: "#1a1a1a"))
                            }
                        }
                        
                        // AI Score
                        if let aiScore = movie.aiScore {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#FEA500"))
                                Text(String(format: "%.1f", aiScore))
                                    .font(.custom("Inter-SemiBold", size: 12))
                                    .foregroundColor(Color(hex: "#1a1a1a"))
                            }
                        }
                        
                        // Friends (placeholder)
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#666666"))
                            Text("0 friends")
                                .font(.custom("Inter-Regular", size: 12))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                    }
                    
                    // Recommendation Indicator (if available)
                    if let recommendation = watchlistManager.getRecommendationData(movieId: movie.id),
                       let recommender = recommendation.recommenderName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#666666"))
                            
                            Text("Recommended by \(recommender)")
                                .font(.custom("Inter-Regular", size: 12))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    // Watched indicator (checkmark if watched)
                    if isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#648d00"))
                    }
                    
                    // Green checkmark if in any watchlist
                    if isInWatchlist {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#648d00"))
                    }
                    
                    // Menu
                    Button(action: {
                        // Show menu
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
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
    
    // MARK: - Voice Search Selection Tracking
    
    /// Track movie selection if this search was initiated by voice
    private func trackVoiceSearchSelection() {
        // Check if there's a pending voice event (meaning this was a voice search)
        guard let eventId = SearchFilterState.shared.pendingVoiceEventId else {
            return // Not a voice search, nothing to track
        }
        
        // Get the number of candidates shown - now correctly reads from shared instance
        let candidatesShown = SearchViewModel.shared.searchResults.count
        
        // Convert movie.id from String to Int
        guard let movieIdInt = Int(movie.id) else {
            print("⚠️ [VoiceSelection] Could not convert movie.id '\(movie.id)' to Int")
            return
        }
        
        print("🎯 [VoiceSelection] User selected movie \(movieIdInt) (\(movie.title)) from \(candidatesShown) candidates")
        
        // Log the selection to Supabase
        Task {
            await VoiceAnalyticsLogger.updateVoiceEventSelection(
                eventId: eventId,
                selectedMovieId: movieIdInt,
                candidatesShown: candidatesShown
            )
            
            // Clear the voice event tracking after selection is logged
            await MainActor.run {
                SearchFilterState.shared.pendingVoiceEventId = nil
                SearchFilterState.shared.pendingVoiceUtterance = nil
                SearchFilterState.shared.pendingVoiceCommand = nil
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

// MARK: - Animated Ellipsis View

struct AnimatedEllipsisView: View {
    @State private var dotCount = 1
    @State private var timer: Timer?
    
    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .font(.custom("Inter-SemiBold", size: 14))
            .foregroundColor(Color(hex: "#666666"))
            .onAppear {
                // Cycle through 1, 2, 3 dots every 0.5 seconds
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dotCount = (dotCount % 3) + 1
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
