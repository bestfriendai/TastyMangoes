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
    
    @EnvironmentObject private var watchlistManager: WatchlistManager
    
    @State private var yourLists: [WatchlistItem] = []
    @State private var masterlistName: String = "Masterlist"
    @State private var masterlistMovies: [MasterlistMovie] = []
    @State private var isLoadingMovies: Bool = false
    
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
                    
                    // Masterlist Section
                    masterlistSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
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
        .onAppear {
            loadLists()
            loadMasterlistMovies()
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
                NavigationLink(destination: IndividualListView(listId: yourLists[listIndex].id, listName: yourLists[listIndex].name)) {
                    SmallListCard(list: yourLists[listIndex])
                }
            } else {
                // Empty space
                Spacer()
                    .frame(width: 169.5, height: 56)
            }
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
                    
                    HStack(spacing: 4) {
                        Text(masterlistName)
                            .font(.custom("Nunito-Bold", size: 20))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        
                        if watchlistManager.isMasterListCountLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Text("(\(watchlistManager.getWatchlist(listId: "masterlist")?.filmCount ?? 0))")
                                .font(.custom("Nunito-Bold", size: 20))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                        }
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
            
            // Movie List
            VStack(spacing: 0) {
                ForEach(masterlistMovies) { movie in
                    MasterlistMovieCard(movie: movie)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadLists() {
        // Load lists from WatchlistManager with current sort option
        // Use the shared sort option from WatchlistManager
        yourLists = watchlistManager.getAllWatchlists(sortBy: watchlistManager.currentSortOption)
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
}

// MARK: - Data Models
// Last modified: 2025-12-03 at 09:09 PST by Cursor Assistant

struct WatchlistItem: Identifiable, Codable {
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

// MARK: - Masterlist Movie Card

struct MasterlistMovieCard: View {
    let movie: MasterlistMovie
    @EnvironmentObject private var watchlistManager: WatchlistManager
    @State private var showMoviePage = false
    
    var body: some View {
        Button(action: {
            // Wire up NAVIGATE connection: Product Card → Movie Page
            showMoviePage = true
        }) {
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
                // Delete/Trash (with checkmark if watched)
                Button(action: {
                    // Delete or mark as watched
                }) {
                    ZStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        if movie.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#648d00"))
                                .offset(x: 8, y: -8)
                        }
                    }
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
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showMoviePage) {
            NavigationStack {
                MoviePageView(movieId: movie.id)
            }
        }
    }
}


// MARK: - Preview

#Preview {
    WatchlistView()
}

