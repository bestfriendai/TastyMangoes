//  WatchlistView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-16 at 23:42 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Notes: Built Watchlist / Masterlist section with header, Your Lists horizontal scroll, and Masterlist vertical movie list with filters. Updated to use new bottom sheets and match Figma design exactly.

import SwiftUI
import Combine

// MARK: - All Lists View (placeholder)

struct AllListsView: View {
    var body: some View {
        Text("All Lists View")
            .font(.custom("Nunito-Bold", size: 20))
            .foregroundColor(Color(hex: "#1a1a1a"))
    }
}

struct WatchlistView: View {
    @State private var searchText: String = ""
    @State private var watchedFilter: String = "Any"
    @State private var showFilterSheet = false
    @State private var showManageList = false
    @State private var showCreateWatchlistSheet = false
    @State private var showMoviePage = false
    @State private var selectedMovieId: Int? = nil
    @State private var showDeleteConfirmation = false
    @State private var movieToDelete: String? = nil
    @State private var otherListsContainingMovie: [String] = []
    
    @EnvironmentObject private var watchlistManager: WatchlistManager
    
    @State private var yourLists: [WatchlistItem] = []
    @State private var masterlistName: String = "Masterlist"
    @State private var masterlistMovies: [MasterlistMovie] = []
    @State private var isLoadingMovies: Bool = false
    @State private var watchedMovies: [MasterlistMovie] = []
    @State private var isLoadingWatchedMovies: Bool = false
    @State private var isWatchedSectionExpanded: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#fdfdfd")
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Header Section
                    topHeaderSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    
                    // Your Lists Section
                    yourListsSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                    
                    // Watched Section
                    watchedSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                    
                    // Masterlist Section
                    masterlistSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar (will be adjusted by safeAreaInset)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            WatchlistFiltersBottomSheet(isPresented: $showFilterSheet)
        }
        .sheet(isPresented: $showManageList) {
            ManageListBottomSheet(isPresented: $showManageList, listId: "masterlist", listName: masterlistName)
                .environmentObject(watchlistManager)
                .onDisappear {
                    // Reload master list name when sheet dismisses (in case it was edited)
                    loadMasterlistName()
                }
        }
        .sheet(isPresented: $showCreateWatchlistSheet) {
            CreateWatchlistBottomSheet(isPresented: $showCreateWatchlistSheet) { newWatchlist in
                // Reload lists to include the new one
                loadLists()
            }
            .environmentObject(watchlistManager)
        }
        .fullScreenCover(isPresented: $showMoviePage) {
            if let movieId = selectedMovieId, movieId > 0 {
                NavigationStack {
                    MoviePageView(movieId: movieId)
                }
            } else {
                // Fallback: show error view if invalid ID
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
        .alert("Delete from All Lists?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                movieToDelete = nil
                otherListsContainingMovie = []
            }
            Button("Delete", role: .destructive) {
                if let movieId = movieToDelete {
                    removeMovieFromMasterlist(movieId: movieId)
                }
                movieToDelete = nil
                otherListsContainingMovie = []
            }
        } message: {
            if !otherListsContainingMovie.isEmpty {
                let listNames = otherListsContainingMovie.compactMap { listId in
                    watchlistManager.getWatchlist(listId: listId)?.name
                }
                let listNamesText = listNames.joined(separator: ", ")
                Text("This movie is also in: \(listNamesText). Deleting from Masterlist will remove it from all your lists.")
            } else {
                Text("This will delete the movie from all your lists.")
            }
        }
        .onAppear {
            print("📋 [WatchlistView] onAppear - syncing cache from Supabase...")
            Task {
                await watchlistManager.syncFromSupabase()
                print("📋 [WatchlistView] Cache synced, loading lists and movies...")
                await MainActor.run {
                    loadLists()
                    loadMasterlistMovies()
                    loadWatchedMovies()
                }
            }
        }
        .onChange(of: watchlistManager.currentSortOption) { oldValue, newValue in
            // Reload lists when sort option changes (e.g., from YourListsView)
            loadLists()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WatchlistManagerDidUpdate"))) { _ in
            // Reload lists when watchlist manager updates (e.g., after creating/deleting lists)
            loadLists()
            loadMasterlistName() // Also reload masterlist name in case it was edited
            loadMasterlistMovies() // Reload movies when watchlist changes
            loadWatchedMovies() // Reload watched movies when watchlist changes
        }
        }
    }
    
    // MARK: - Top Header Section
    
    private var topHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and Avatar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Discover Your Lists")
                            .font(.custom("Nunito-Bold", size: 24))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        Text("👑")
                            .font(.system(size: 24))
                    }
                    
                    Text("Create and customize your watchlists for any needs.")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                        .lineSpacing(4)
                }
                
                Spacer()
                
                // Profile Avatar
                Circle()
                    .fill(Color(hex: "#f0f0f0"))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#999999"))
                    )
            }
            
            // Search and Filter
            HStack(spacing: 8) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    TextField("Searching film by name...", text: $searchText)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    Button(action: {
                        // Voice search
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#666666"))
                    }
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
    }
    
    // MARK: - Your Lists Section
    
    private var yourListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Your Lists (\(yourLists.count))")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Spacer()
                
                NavigationLink(destination: YourListsView()) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.custom("Inter-SemiBold", size: 14))
                            .foregroundColor(Color(hex: "#FEA500"))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FEA500"))
                    }
                }
            }
            
            // Horizontal Scrollable Grid (3 rows x 2 columns = 6 cards per page)
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Group lists into pages of 6 cards (3 rows x 2 columns)
                        ForEach(0..<numberOfPages, id: \.self) { pageIndex in
                            VStack(spacing: 4) {
                                // Row 1 (2 cards)
                                HStack(spacing: 4) {
                                    cardForPosition(page: pageIndex, row: 0, column: 0)
                                    cardForPosition(page: pageIndex, row: 0, column: 1)
                                }
                                
                                // Row 2 (2 cards)
                                HStack(spacing: 4) {
                                    cardForPosition(page: pageIndex, row: 1, column: 0)
                                    cardForPosition(page: pageIndex, row: 1, column: 1)
                                }
                                
                                // Row 3 (2 cards)
                                HStack(spacing: 4) {
                                    cardForPosition(page: pageIndex, row: 2, column: 0)
                                    cardForPosition(page: pageIndex, row: 2, column: 1)
                                }
                            }
                            .frame(width: geometry.size.width - 32) // Full width minus padding
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
            .frame(height: 180) // Fixed height for the grid
        }
    }
    
    // Calculate number of pages needed (6 cards per page)
    private var numberOfPages: Int {
        let totalCards = yourLists.count + 1 // +1 for "Create New" card
        return max(1, (totalCards + 5) / 6) // Round up to nearest page
    }
    
    // Get card for specific position in grid
    @ViewBuilder
    private func cardForPosition(page: Int, row: Int, column: Int) -> some View {
        let position = (page * 6) + (row * 2) + column
        
        if position == 0 {
            // First position: "Create New" card
            Button(action: {
                showCreateWatchlistSheet = true
            }) {
                CreateNewListCard()
            }
        } else {
            // Other positions: List cards
            let listIndex = position - 1 // -1 because position 0 is "Create New"
            if listIndex < yourLists.count {
                let list = yourLists[listIndex]
                // Use the list object directly to ensure correct navigation
                NavigationLink(destination: IndividualListView(listId: list.id, listName: list.name)) {
                    SmallListCard(list: list)
                }
                .onAppear {
                    print("📋 [WatchlistView] Card at position \(position) (index \(listIndex)): \(list.name) (ID: \(list.id))")
                }
            } else {
                // Empty space
                Spacer()
                    .frame(width: 169.5, height: 56)
            }
        }
    }
    
    // MARK: - Watched Section
    
    private var watchedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header with Chevron - same style as Masterlist
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text(watchedCountText)
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isWatchedSectionExpanded.toggle()
                    }
                    if isWatchedSectionExpanded && watchedMovies.isEmpty {
                        loadWatchedMovies()
                    }
                }) {
                    Image(systemName: isWatchedSectionExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#666666"))
                        .frame(width: 28, height: 28)
                }
            }
            
            // Watched Movies List (shown when expanded)
            if isWatchedSectionExpanded {
                if isLoadingWatchedMovies {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if watchedMovies.isEmpty {
                    Text("No watched movies yet")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(watchedMovies) { movie in
                            MasterlistMovieCard(movie: movie)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Open movie page - safely convert movie ID
                                    guard let movieId = Int(movie.id), movieId > 0 else {
                                        print("⚠️ [WatchlistView] Invalid movie ID '\(movie.id)' - cannot open movie page")
                                        return
                                    }
                                    
                                    print("📋 [WatchlistView] Opening movie page for ID: \(movieId) (movie: \(movie.title))")
                                    selectedMovieId = movieId
                                    showMoviePage = true
                                }
                        }
                    }
                }
            }
        }
    }
    
    private var watchedCountText: String {
        // Use the loaded movies count if available, otherwise show 0
        let watchedCount = watchedMovies.count
        
        if watchedCount > 0 {
            return "Watched (\(watchedCount))"
        } else {
            return "Watched"
        }
    }
    
    // MARK: - Masterlist Section
    
    private var masterlistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text(masterlistCountText)
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    // Show loading spinner while movies are being fetched
                    if isLoadingMovies {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color(hex: "#FEA500"))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showManageList = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .frame(width: 28, height: 28)
                }
            }
            
            // Filter Dropdown
            Button(action: {
                // Show filter options
            }) {
                HStack {
                    Text("Watched: \(watchedFilter)")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "#ffedcc"))
                .cornerRadius(8)
            }
            
            // Movie List with Swipe Actions
            VStack(spacing: 0) {
                ForEach(masterlistMovies) { movie in
                    SwipeableMasterlistMovieCard(
                        movie: movie,
                        onTap: {
                            // Open movie page - safely convert movie ID
                            guard let movieId = Int(movie.id), movieId > 0 else {
                                print("⚠️ [WatchlistView] Invalid movie ID '\(movie.id)' - cannot open movie page")
                                return
                            }
                            
                            print("📋 [WatchlistView] Opening movie page for ID: \(movieId) (movie: \(movie.title))")
                            selectedMovieId = movieId
                            showMoviePage = true
                        },
                        onDelete: {
                            handleMasterlistDelete(movieId: movie.id)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var masterlistCountText: String {
        // Get the actual count from WatchlistManager to avoid showing "0" while loading
        let movieIds = watchlistManager.getMoviesInList(listId: "masterlist")
        let actualCount = movieIds.count
        
        // If we're loading and haven't populated movies yet, use the count from manager
        // Otherwise use the loaded movies count
        let displayCount = (isLoadingMovies && masterlistMovies.isEmpty) ? actualCount : masterlistMovies.count
        
        // Only show count if we have movies or if we know the count from the manager
        if displayCount > 0 || (!isLoadingMovies && actualCount > 0) {
            return "\(masterlistName) (\(displayCount))"
        } else {
            // Show just the name without count while loading or if empty
            return masterlistName
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadLists() {
        // Load lists from WatchlistManager with current sort option
        // Use the shared sort option from WatchlistManager
        print("📋 [WatchlistView] Loading lists from cache...")
        let allLists = watchlistManager.getAllWatchlists(sortBy: watchlistManager.currentSortOption)
        // Filter out Masterlist by both ID and name (case-insensitive) as a safety measure
        // This prevents any list named "Masterlist" from appearing in regular lists section
        yourLists = allLists.filter { list in
            let isMasterlistById = list.id == "masterlist" || list.id == "1"
            let isMasterlistByName = list.name.lowercased() == "masterlist"
            return !isMasterlistById && !isMasterlistByName
        }
        print("📋 [WatchlistView] Loaded \(yourLists.count) lists from cache (filtered out Masterlist)")
        loadMasterlistName()
    }
    
    private func loadMasterlistName() {
        // Get master list name from WatchlistManager
        // Masterlist has id "masterlist" or "1"
        if let masterlist = watchlistManager.getWatchlist(listId: "masterlist") {
            masterlistName = masterlist.name
        } else if let masterlist = watchlistManager.getWatchlist(listId: "1") {
            masterlistName = masterlist.name
        } else {
            masterlistName = "Masterlist" // Default fallback
        }
    }
    
    private func loadMasterlistMovies() {
        guard !isLoadingMovies else { return }
        isLoadingMovies = true
        
        Task {
            // Get movie IDs from masterlist
            let movieIds = watchlistManager.getMoviesInList(listId: "masterlist")
            print("📋 [WatchlistView] Found \(movieIds.count) movies in masterlist cache")
            
            // Fetch movie cards from Supabase
            var fetchedMovies: [MasterlistMovie] = []
            
            for movieId in movieIds {
                // movieId is stored as TMDB ID string
                do {
                    let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
                    let masterlistMovie = movieCard.toMasterlistMovie(
                        isWatched: watchlistManager.isWatched(movieId: movieId),
                        friendsCount: 0 // TODO: Implement friends count when available
                    )
                    fetchedMovies.append(masterlistMovie)
                } catch {
                    print("⚠️ Failed to fetch movie card for ID \(movieId): \(error)")
                    // Continue with other movies even if one fails
                }
            }
            
            await MainActor.run {
                self.masterlistMovies = fetchedMovies
                self.isLoadingMovies = false
            }
        }
    }
    
    private func handleMasterlistDelete(movieId: String) {
        print("🗑️ [WatchlistView] handleMasterlistDelete called for movie: \(movieId)")
        
        // Check if movie exists in other lists
        let allLists = watchlistManager.getListsForMovie(movieId: movieId)
        print("🗑️ [WatchlistView] Movie \(movieId) is in lists: \(allLists)")
        
        let otherLists = allLists.filter { $0 != "masterlist" && $0 != "1" }
        print("🗑️ [WatchlistView] Other lists (excluding masterlist): \(otherLists)")
        
        if !otherLists.isEmpty {
            // Movie is in other lists - show confirmation
            print("🗑️ [WatchlistView] Movie is in other lists - showing confirmation alert")
            otherListsContainingMovie = Array(otherLists)
            movieToDelete = movieId
            showDeleteConfirmation = true
        } else {
            // Movie is only in masterlist - delete directly
            print("🗑️ [WatchlistView] Movie is only in masterlist - deleting directly")
            removeMovieFromMasterlist(movieId: movieId)
        }
    }
    
    private func removeMovieFromMasterlist(movieId: String) {
        // Get all lists containing this movie
        let allListsContainingMovie = watchlistManager.getListsForMovie(movieId: movieId)
        
        // Remove movie from masterlist
        watchlistManager.removeMovieFromList(movieId: movieId, listId: "masterlist")
        
        // Remove from all other lists as well
        for listId in allListsContainingMovie {
            if listId != "masterlist" && listId != "1" {
                watchlistManager.removeMovieFromList(movieId: movieId, listId: listId)
            }
        }
        
        // Remove from local array
        masterlistMovies.removeAll { $0.id == movieId }
        
        // Sync with Supabase - remove from all lists
        Task {
            do {
                // Remove from masterlist
                try await SupabaseWatchlistAdapter.removeMovie(
                    movieId: movieId,
                    fromListId: "masterlist"
                )
                print("✅ [WatchlistView] Removed movie \(movieId) from masterlist in Supabase")
                
                // Remove from all other lists
                for listId in allListsContainingMovie {
                    if listId != "masterlist" && listId != "1" {
                        try await SupabaseWatchlistAdapter.removeMovie(
                            movieId: movieId,
                            fromListId: listId
                        )
                        print("✅ [WatchlistView] Removed movie \(movieId) from list \(listId) in Supabase")
                    }
                }
            } catch {
                print("❌ [WatchlistView] Failed to remove movie \(movieId) from Supabase: \(error)")
            }
        }
    }
    
    private func loadWatchedMovies() {
        guard !isLoadingWatchedMovies else { return }
        isLoadingWatchedMovies = true
        
        Task {
            // Get all watched movie IDs from WatchlistManager
            // Note: We need to access the watchedMovies dictionary
            // Since it's private, we'll get all movies from all lists and filter by watched status
            var watchedMovieIds: Set<String> = []
            
            // Get all movies from all lists
            let allListIds = watchlistManager.getAllWatchlists().map { $0.id } + ["masterlist"]
            for listId in allListIds {
                let movieIds = watchlistManager.getMoviesInList(listId: listId)
                for movieId in movieIds {
                    if watchlistManager.isWatched(movieId: movieId) {
                        watchedMovieIds.insert(movieId)
                    }
                }
            }
            
            print("📋 [WatchlistView] Found \(watchedMovieIds.count) watched movies")
            
            // Fetch movie cards from Supabase
            var fetchedMovies: [MasterlistMovie] = []
            
            for movieId in watchedMovieIds {
                do {
                    let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
                    let masterlistMovie = movieCard.toMasterlistMovie(
                        isWatched: true, // All movies in this list are watched
                        friendsCount: 0
                    )
                    fetchedMovies.append(masterlistMovie)
                } catch {
                    print("⚠️ Failed to fetch watched movie card for ID \(movieId): \(error)")
                    // Continue with other movies even if one fails
                }
            }
            
            await MainActor.run {
                self.watchedMovies = fetchedMovies
                self.isLoadingWatchedMovies = false
            }
        }
    }
}

// MARK: - Data Models

struct WatchlistItem: Identifiable {
    let id: String
    let name: String
    let filmCount: Int
    let thumbnailURL: String?
}

struct MasterlistMovie: Identifiable {
    let id: String
    let title: String
    let year: String
    let genres: [String]
    let runtime: String
    let posterURL: String?
    let tastyScore: Double?
    let aiScore: Double?
    let friendsCount: Int
    let isWatched: Bool
}

// MARK: - MovieCard Extension for Watchlist

extension MovieCard {
    func toMasterlistMovie(isWatched: Bool = false, friendsCount: Int = 0) -> MasterlistMovie {
        // Calculate tastyScore from sourceScores (TMDB rating normalized to 0-1)
        let tastyScore: Double? = {
            if let tmdbScore = sourceScores?.tmdb?.score {
                // Normalize TMDB score (0-10) to 0-1 scale
                return tmdbScore / 10.0
            }
            return nil
        }()
        
        // Extract year from releaseDate if year is not available
        let yearString: String = {
            if let year = year {
                return String(year)
            } else if let releaseDate = releaseDate, releaseDate.count >= 4 {
                return String(releaseDate.prefix(4))
            }
            return ""
        }()
        
        return MasterlistMovie(
            id: tmdbId, // Use TMDB ID, not work_id, so navigation works correctly
            title: title,
            year: yearString,
            genres: genres ?? [],
            runtime: runtimeDisplay ?? (runtimeMinutes.map { "\($0) min" } ?? ""),
            posterURL: poster?.medium ?? poster?.large ?? poster?.small,
            tastyScore: tastyScore,
            aiScore: aiScore,
            friendsCount: friendsCount,
            isWatched: isWatched
        )
    }
}

// MARK: - Create New List Card

struct CreateNewListCard: View {
    var body: some View {
        VStack(spacing: 8) {
            // Plus Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#f3f3f3"))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            // Text
            Text("Create New Watchlist")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 169.5, height: 56)
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Small List Card

struct SmallListCard: View {
    let list: WatchlistItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#f0f0f0"))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#999999"))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.custom("Inter-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .lineLimit(1)
                
                Text("\(list.filmCount) films")
                    .font(.custom("Inter-Regular", size: 10))
                    .foregroundColor(Color(hex: "#666666"))
            }
        }
        .frame(width: 169.5, height: 56)
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Swipeable Masterlist Movie Card

struct SwipeableMasterlistMovieCard: View {
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
                            print("🗑️ [SwipeableMasterlistMovieCard] Delete button tapped for movie: \(movie.id)")
                            // Immediately call onDelete (don't wait for animation)
                            onDelete()
                            // Then animate out
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = -geometry.size.width
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .zIndex(10) // Ensure button is above other elements
                        .padding(.trailing, 16)
                    }
                    .zIndex(5) // Ensure delete button area is above card
                }
                
                // Movie card
                MasterlistMovieCard(movie: movie)
                    .offset(x: dragOffset)
                    .allowsHitTesting(dragOffset == 0) // Disable card taps when swiped
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only handle tap if not currently dragging and card is not swiped
                        if !isDragging && dragOffset == 0 {
                            onTap()
                        } else if dragOffset != 0 {
                            // Snap back if swiped
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                            isDragging = false
                        }
                    }
            }
        }
        .frame(height: 120) // Approximate height of MasterlistMovieCard
    }
}

// MARK: - Masterlist Movie Card

struct MasterlistMovieCard: View {
    let movie: MasterlistMovie
    @EnvironmentObject private var watchlistManager: WatchlistManager
    
    var body: some View {
            HStack(spacing: 12) {
            // Poster
            MoviePosterImage(
                posterURL: movie.posterURL,
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
                Text("\(movie.year) · \(movie.genres.joined(separator: "/")) · \(movie.runtime)")
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
                
                // Scores and Friends
                HStack(spacing: 12) {
                    // Tasty Score
                    if let tastyScore = movie.tastyScore {
                        HStack(spacing: 4) {
                            Image("TastyScoreIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                            Text("\(Int(tastyScore * 100))%")
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
                    
                    // Friends
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                        Text("\(movie.friendsCount) friends")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
                
                // Recommendation Indicator
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
                if movie.isWatched {
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
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        .padding(.bottom, 8)
    }
}


// MARK: - Preview

#Preview {
    WatchlistView()
}

