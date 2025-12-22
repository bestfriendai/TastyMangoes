//  IndividualListView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-16 at 23:57 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-09 at 17:25 (America/Los_Angeles - Pacific Time)
//  Changes:
//    1. Fixed first-tap movie opening bug (fullScreenCover item pattern)
//    2. Implemented smart caching for instant list loading:
//       - Load cached MovieCards instantly from MovieCardCache (no network)
//       - Only fetch missing cards via batch Supabase query
//       - Skip redundant Supabase sync (already synced at app launch)

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
    @State private var isLoadingMovies: Bool = false
    @StateObject private var filterState = WatchlistFilterState.shared
    
    // Use IdentifiableMovieId wrapper for fullScreenCover(item:) pattern
    @State private var selectedMovieId: IdentifiableMovieId? = nil
    
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
                    
                    // Movie List (Product Cards) with Swipe Actions
                    VStack(spacing: 12) {
                        // Create New Watchlist Card (if empty)
                        if movies.isEmpty && !isLoadingMovies {
                            Button(action: {
                                showAddMoviesSheet = true
                            }) {
                                CreateNewWatchlistCard()
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Loading indicator
                        if isLoadingMovies && movies.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                        
                        // Movie Cards with Swipe Actions
                        ForEach(movies) { movie in
                            SwipeableMovieCard(
                                movie: movie,
                                onTap: {
                                    // Safely convert movie ID
                                    guard let movieId = Int(movie.id), movieId > 0 else {
                                        print("⚠️ [IndividualListView] Invalid movie ID '\(movie.id)' - cannot open movie page")
                                        return
                                    }
                                    print("📋 [IndividualListView] Opening movie page for ID: \(movieId)")
                                    selectedMovieId = IdentifiableMovieId(id: movieId)
                                },
                                onDelete: {
                                    removeMovie(movieId: movie.id)
                                }
                            )
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
                    // Reload movies after adding - smart fetch will only get new ones
                    loadMoviesSmartFetch()
                }
        }
        // Use fullScreenCover(item:) pattern to fix first-tap bug
        .fullScreenCover(item: $selectedMovieId) { movieId in
            NavigationStack {
                MoviePageView(movieId: movieId.id)
            }
        }
        .onAppear {
            print("📋 [IndividualListView] Loading movies for list: \(listName) (ID: \(listId))")
            
            // Step 1: Load from local cache INSTANTLY (no network)
            loadMoviesFromCache()
            
            // Step 2: Smart fetch only missing movies in background
            // Don't do a full Supabase sync - WatchlistView already does that
            loadMoviesSmartFetch()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WatchlistManagerDidUpdate"))) { _ in
            // Reload movies when watchlist manager updates
            print("📋 [IndividualListView] WatchlistManagerDidUpdate notification received - reloading movies")
            loadMoviesFromCache()
            loadMoviesSmartFetch()
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
                    HStack(spacing: 4) {
                        Text(listName)
                            .font(.custom("Nunito-Bold", size: 20))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        
                        // Show loading spinner while fetching
                        if isLoadingMovies {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(Color(hex: "#FEA500"))
                        }
                    }
                    
                    Text("\(movies.count) films")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
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
    
    // MARK: - Smart Movie Loading (with local caching)
    
    /// Load movies instantly from local MovieCardCache (no network)
    private func loadMoviesFromCache() {
        let movieIdsSet = watchlistManager.getMoviesInList(listId: listId)
        let movieIds = Array(movieIdsSet)
        print("📋 [IndividualListView] Loading \(movieIds.count) movies from local cache for \(listName)...")
        
        let cache = MovieCardCache.shared
        var cachedMovies: [MasterlistMovie] = []
        
        for movieId in movieIds {
            if let card = cache.getCard(tmdbId: movieId) {
                let masterlistMovie = card.toMasterlistMovie(
                    isWatched: watchlistManager.isWatched(movieId: movieId),
                    friendsCount: 0
                )
                cachedMovies.append(masterlistMovie)
            }
        }
        
        movies = cachedMovies
        print("📋 [IndividualListView] Loaded \(cachedMovies.count)/\(movieIds.count) movies from local cache (instant)")
    }
    
    /// Smart fetch: Only get movies we don't have locally, using batch query
    private func loadMoviesSmartFetch() {
        let movieIdsSet = watchlistManager.getMoviesInList(listId: listId)
        let movieIds = Array(movieIdsSet)
        let cache = MovieCardCache.shared
        
        // Find which movies we're missing locally
        let missingIds = cache.getMissingIds(from: movieIds)
        
        if missingIds.isEmpty {
            print("📋 [IndividualListView] All \(movieIds.count) movies already cached locally!")
            // Refresh display from cache (in case watched status changed)
            loadMoviesFromCache()
            return
        }
        
        print("📋 [IndividualListView] Need to fetch \(missingIds.count)/\(movieIds.count) missing movies...")
        isLoadingMovies = true
        
        Task {
            do {
                // Batch fetch all missing movies in ONE query
                let fetchedCards = try await SupabaseService.shared.fetchMovieCardsBatch(tmdbIds: missingIds)
                
                // Cache the newly fetched cards locally
                cache.setCards(Array(fetchedCards.values))
                
                // Rebuild the full list from cache (now complete)
                await MainActor.run {
                    loadMoviesFromCache()
                    isLoadingMovies = false
                }
            } catch {
                print("⚠️ [IndividualListView] Batch fetch failed: \(error)")
                // Fall back to individual fetches
                await fetchMissingMoviesIndividually(missingIds: missingIds)
            }
        }
    }
    
    /// Fallback: fetch missing movies one at a time (if batch fails)
    private func fetchMissingMoviesIndividually(missingIds: [String]) async {
        let cache = MovieCardCache.shared
        
        for movieId in missingIds {
            do {
                // Try cache first, then edge function
                if let movieCard = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: movieId) {
                    cache.setCard(movieCard)
                } else {
                    let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
                    cache.setCard(movieCard)
                }
                
                // Update UI progressively
                await MainActor.run {
                    loadMoviesFromCache()
                }
            } catch {
                print("⚠️ [IndividualListView] Failed to fetch movie \(movieId): \(error)")
            }
        }
        
        await MainActor.run {
            isLoadingMovies = false
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    private func removeMovie(movieId: String) {
        // Remove movie from the list
        watchlistManager.removeMovieFromList(movieId: movieId, listId: listId)
        
        // Remove from local array
        movies.removeAll { $0.id == movieId }
        
        // Sync with Supabase
        Task {
            do {
                try await SupabaseWatchlistAdapter.removeMovie(
                    movieId: movieId,
                    fromListId: listId
                )
                print("✅ [IndividualListView] Removed movie \(movieId) from list \(listId) in Supabase")
            } catch {
                print("❌ [IndividualListView] Failed to remove movie \(movieId) from Supabase: \(error)")
            }
        }
    }
}

// MARK: - Swipeable Movie Card

struct SwipeableMovieCard: View {
    let movie: MasterlistMovie
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var initialDragLocation: CGPoint? = nil
    
    // Show delete button when swiped halfway (about -80 points for a typical card width)
    private let showDeleteButtonThreshold: CGFloat = -80
    // Snap to halfway position when swiped past threshold
    private let snapToDeletePosition: CGFloat = -80
    // Minimum horizontal movement before activating swipe (prevents interference with scrolling)
    private let horizontalActivationThreshold: CGFloat = 30
    // Minimum ratio of horizontal to vertical movement to activate swipe
    private let horizontalVerticalRatio: CGFloat = 2.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Delete button background - always visible when swiped
                if dragOffset < -20 {
                    HStack {
                        Spacer()
                        Button(action: {
                            // Confirm delete - animate out and call delete
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = -geometry.size.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDelete()
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                    }
                }
                
                // Movie card
                WatchlistProductCard(movie: movie)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                // Store initial location on first change
                                if initialDragLocation == nil {
                                    initialDragLocation = value.startLocation
                                }
                                
                                let horizontalMovement = abs(value.translation.width)
                                let verticalMovement = abs(value.translation.height)
                                
                                // Only activate if:
                                // 1. Horizontal movement exceeds threshold
                                // 2. Horizontal movement is at least 2x the vertical movement
                                // 3. Swiping left (negative width)
                                // 4. We haven't already started dragging OR we're continuing a horizontal drag
                                let isHorizontalIntent = horizontalMovement > horizontalActivationThreshold &&
                                                       horizontalMovement > verticalMovement * horizontalVerticalRatio &&
                                                       value.translation.width < 0
                                
                                if isHorizontalIntent {
                                    if !isDragging {
                                        isDragging = true
                                    }
                                    // Limit swipe to about halfway
                                    let maxSwipe = -geometry.size.width * 0.5
                                    dragOffset = max(maxSwipe, value.translation.width)
                                } else if !isDragging {
                                    // Don't interfere with scrolling - reset everything
                                    dragOffset = 0
                                    initialDragLocation = nil
                                }
                            }
                            .onEnded { value in
                                let horizontalMovement = abs(value.translation.width)
                                let verticalMovement = abs(value.translation.height)
                                
                                if isDragging && horizontalMovement > verticalMovement * horizontalVerticalRatio {
                                    // If swiped past threshold, snap to delete position
                                    if value.translation.width < showDeleteButtonThreshold {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            dragOffset = snapToDeletePosition
                                        }
                                    } else {
                                        // Not far enough - snap back
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            dragOffset = 0
                                        }
                                    }
                                } else {
                                    // Vertical swipe or not enough horizontal - snap back
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                }
                                isDragging = false
                                initialDragLocation = nil
                            }
                    )
                    .onTapGesture {
                        if dragOffset == 0 {
                            onTap()
                        } else {
                            // Snap back if swiped
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                            isDragging = false
                        }
                    }
            }
        }
        .frame(height: 144) // Approximate height of WatchlistProductCard
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
                            Image("TastyScoreIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                            
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
