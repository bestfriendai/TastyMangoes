//  WatchlistView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-16 at 23:42 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Notes: Built Watchlist / Masterlist section with header, Your Lists horizontal scroll, and Masterlist vertical movie list with filters. Updated to use new bottom sheets and match Figma design exactly.

import SwiftUI

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
    
    @EnvironmentObject private var watchlistManager: WatchlistManager
    
    @State private var yourLists: [WatchlistItem] = []
    
    @State private var masterlistMovies: [MasterlistMovie] = [
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
            isWatched: true
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
            isWatched: true
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
            isWatched: true
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
            ManageListBottomSheet(isPresented: $showManageList, listId: "masterlist", listName: "Masterlist")
        }
        .onAppear {
            loadLists()
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
            
            // Horizontal Scrollable List Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Create New Watchlist Card
                    Button(action: {
                        // Create new list
                    }) {
                        CreateNewListCard()
                    }
                    
                    // All lists
                    ForEach(yourLists) { list in
                        NavigationLink(destination: IndividualListView(listId: list.id, listName: list.name)) {
                            SmallListCard(list: list)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
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
                    
                    Text("Masterlist (\(masterlistMovies.count))")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
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
        // Load lists from WatchlistManager
        yourLists = watchlistManager.getAllWatchlists()
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
    @State private var showMoviePage = false
    
    var body: some View {
        Button(action: {
            // Wire up NAVIGATE connection: Product Card → Movie Page
            showMoviePage = true
        }) {
            HStack(spacing: 12) {
            // Poster
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#f0f0f0"))
                    .frame(width: 60, height: 90)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#999999"))
            }
            
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

