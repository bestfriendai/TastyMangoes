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
    @State private var showMoviePage = false
    @State private var selectedMovieId: Int? = nil
    
    // Helper to safely convert movie ID
    private func safeMovieId(from movieId: String) -> Int? {
        return Int(movieId)
    }
    
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
                        if movies.isEmpty {
                            Button(action: {
                                showAddMoviesSheet = true
                            }) {
                                CreateNewWatchlistCard()
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Movie Cards with Swipe Actions
                        ForEach(movies) { movie in
                            SwipeableMovieCard(
                                movie: movie,
                                onTap: {
                                    // Only set movieId if we can safely convert it to a valid Int
                                    if let movieId = safeMovieId(from: movie.id), movieId > 0 {
                                        selectedMovieId = movieId
                                        showMoviePage = true
                                    } else {
                                        print("⚠️ [IndividualListView] Invalid movie ID '\(movie.id)' - cannot open movie page")
                                    }
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
                    // Reload movies after adding
                    loadMovies()
                }
        }
        .fullScreenCover(isPresented: $showMoviePage) {
            if let movieId = selectedMovieId, movieId > 0 {
                NavigationStack {
                    MoviePageView(movieId: movieId)
                }
            } else {
                // Fallback: show error or loading state
                ZStack {
                    Color(hex: "#fdfdfd")
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#999999"))
                        Text("Unable to load movie")
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(Color(hex: "#666666"))
                        Button("Close") {
                            showMoviePage = false
                        }
                        .font(.custom("Inter-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#FEA500"))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .onAppear {
            print("📋 [IndividualListView] Loading movies for list: \(listName) (ID: \(listId))")
            // Refresh cache from Supabase before loading to ensure we have latest data
            Task {
                print("📋 [IndividualListView] Syncing watchlist cache from Supabase...")
                await watchlistManager.syncFromSupabase()
                print("📋 [IndividualListView] Cache synced, loading movies...")
                await MainActor.run {
                    loadMovies()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WatchlistManagerDidUpdate"))) { _ in
            // Reload movies when watchlist manager updates
            print("📋 [IndividualListView] WatchlistManagerDidUpdate notification received - reloading movies")
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
        print("📋 [IndividualListView] Found \(movieIds.count) movies in local cache for list \(listName)")
        print("📋 [IndividualListView] Movie IDs: \(Array(movieIds).sorted())")
        
        // Fetch real movie data from Supabase (not mock data)
        Task {
            var fetchedMovies: [MasterlistMovie] = []
            
            for movieId in movieIds {
                print("📋 [IndividualListView] Fetching movie card for ID: \(movieId)")
                do {
                    // Try fetching from cache first
                    if let movieCard = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: movieId) {
                        let masterlistMovie = movieCard.toMasterlistMovie(
                            isWatched: watchlistManager.isWatched(movieId: movieId),
                            friendsCount: 0 // TODO: Implement friends count when available
                        )
                        fetchedMovies.append(masterlistMovie)
                        print("✅ [IndividualListView] Loaded movie \(movieId) from cache")
                    } else {
                        // Fallback to get-movie-card function
                        print("📋 [IndividualListView] Movie \(movieId) not in cache, fetching from get-movie-card...")
                        let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
                        let masterlistMovie = movieCard.toMasterlistMovie(
                            isWatched: watchlistManager.isWatched(movieId: movieId),
                            friendsCount: 0
                        )
                        fetchedMovies.append(masterlistMovie)
                        print("✅ [IndividualListView] Loaded movie \(movieId) from get-movie-card")
                    }
                } catch {
                    print("❌ [IndividualListView] Failed to fetch movie \(movieId): \(error)")
                    print("❌ [IndividualListView] Error details: \(error.localizedDescription)")
                    // Continue with other movies even if one fails
                }
            }
            
            await MainActor.run {
                print("📋 [IndividualListView] Loaded \(fetchedMovies.count) movies from Supabase")
                movies = fetchedMovies
            }
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

