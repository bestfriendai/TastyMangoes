//  MoviePageView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-16 at 23:37 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:13 (America/Los_Angeles - Pacific Time)
//  Notes: Fixed horizontal tab bar pinning - tab bar now properly pins below header when scrolling up, and scrolls to sections when tabs are clicked. Updated MenuBottomSheet to match Figma design with correct review icon. Changed AddToListView presentation from fullScreenCover to sheet to match bottom sheet design. Added navigation to list functionality from toast notifications. Replaced deprecated NavigationLink with fullScreenCover for navigating to IndividualListView.

import SwiftUI

// MARK: - Sections

private enum MovieSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case castCrew = "Cast & Crew"
    case reviews = "Reviews"
    case similar = "More to Watch"
    case getSmarter = "Get Smarter"
    case clips = "Movie Clips"
    case photos = "Photos"
    
    var id: String { rawValue }
}

struct MoviePageView: View {
    
    // MARK: - Properties
    
    let movieId: String
    @StateObject private var viewModel: MovieDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSection: MovieSection = .overview
    @State private var showMenuBottomSheet = false
    @State private var showAddToList = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var tabBarMinY: CGFloat = 1000 // Start with large value so pinned bar doesn't show initially
    @State private var showIndividualList = false
    @State private var navigateToListId: String? = nil
    @State private var navigateToListName: String? = nil
    
    // Computed property to determine if pinned tab bar should show
    private var shouldShowPinnedTabBar: Bool {
        // Show pinned tab bar when scrollable one has scrolled up to or past the header
        // tabBarMinY represents the top edge of the scrollable tab bar in scroll coordinate space
        // When it's <= ~132 (safe area ~52 + header ~80), it should be pinned
        // We check > 50 to ensure it's actually scrolled (not initial position)
        return tabBarMinY > 50 && tabBarMinY <= 132
    }
    
    // MARK: - Initialization
    
    init(movieId: String) {
        self.movieId = movieId
        _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieStringId: movieId))
    }
    
    // Alternative initializer for Int IDs
    init(movieId: Int) {
        self.movieId = String(movieId)
        _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieId: movieId))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else if let movie = viewModel.movie {
                movieContent(movie)
            }
        }
        .task {
            await viewModel.loadMovie()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading movie details...")
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#fdfdfd"))
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FF6B6B"))
            
            Text("Oops!")
                .font(.custom("Nunito-Bold", size: 24))
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            Text(viewModel.errorMessage)
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { viewModel.retry() }) {
                Text("Try Again")
                    .font(.custom("Inter-SemiBold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#333333"))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#fdfdfd"))
    }
    
    // MARK: - Movie Content
    
    private func movieContent(_ movie: MovieDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top padding to account for pinned header
                    Color.clear
                        .frame(height: 0)
                        .id("scrollTop")
                    
                    // Trailer/Backdrop Section (scrolls)
                    trailerSection(movie)
                    
                    // Poster and Scores Section (overlaps trailer)
                    posterAndScoresSection(movie)
                        .padding(.horizontal, 16)
                        .padding(.top, -58)
                    
                    // Mango's Tips + Watch On / Liked By cards
                    tipsAndCardsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    // Horizontal Section Tabs Bar (starts here, pins when it reaches top)
                    sectionTabsBar(proxy: proxy)
                        .padding(.top, 12)
                        .background(
                            GeometryReader { geometry in
                                let frame = geometry.frame(in: .named("scroll"))
                                Color.clear.preference(
                                    key: TabBarPositionKey.self,
                                    value: frame.minY
                                )
                            }
                        )
                        .opacity(shouldShowPinnedTabBar ? 0 : 1) // Hide scrollable tab bar when pinned one should show
                        .id("scrollableTabBar")
                    
                    // Content Sections
                    VStack(alignment: .leading, spacing: 32) {
                        // Spacer to account for pinned header + tab bar when scrolling to sections
                        Color.clear
                            .frame(height: 0)
                            .id("sectionsStart")
                        
                        overviewSection(movie)
                            .id(MovieSection.overview.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .overview,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                        
                        castCrewSection(movie)
                            .id(MovieSection.castCrew.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .castCrew,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                        
                        reviewsSection
                            .id(MovieSection.reviews.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .reviews,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                        
                        similarSection
                            .id(MovieSection.similar.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .similar,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                        
                        // Help Us Get Smarter section
                        helpUsGetSmarterSection
                            .id(MovieSection.getSmarter.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .getSmarter,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                        
                        // Movie Clips section
                        movieClipsSection
                            .id(MovieSection.clips.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .clips,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                        
                        // Photos section
                        photosSection
                            .id(MovieSection.photos.id)
                            .background(
                                GeometryReader { geometry in
                                    let frame = geometry.frame(in: .named("scroll"))
                                    Color.clear.preference(
                                        key: SectionVisibilityPreferenceKey.self,
                                        value: [SectionVisibility(
                                            section: .photos,
                                            minY: frame.minY,
                                            maxY: frame.maxY
                                        )]
                                    )
                                }
                            )
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
                    
                    // Bottom Action Buttons
                    bottomActionButtons
                        .padding(.top, 32)
                        .padding(.bottom, 100) // Extra padding to ensure buttons are visible above tab bar
                }
            }
            .coordinateSpace(name: "scroll")
            .background(Color(hex: "#fdfdfd"))
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    // Pinned Header: Back arrow, Title, Details, Share, Menu
                    pinnedHeader(movie)
                    
                    // Pinned Section Tabs Bar - shows when scrollable tab bar reaches the top
                    if shouldShowPinnedTabBar {
                        sectionTabsBar(proxy: proxy)
                            .background(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    } else {
                        // Spacer to maintain consistent header height when tab bar isn't pinned
                        Color.clear
                            .frame(height: 52)
                    }
                }
            }
            .onPreferenceChange(TabBarPositionKey.self) { value in
                tabBarMinY = value
            }
            .onPreferenceChange(SectionVisibilityPreferenceKey.self) { values in
                // Update selected section based on scroll position
                // Tab bar offset accounts for safe area (~52), header (~80), and tab bar height (~52) = ~184
                let tabBarOffset: CGFloat = 184
                
                let visibleSections = values.filter { visibility in
                    // Section is visible if it's in the top portion of the visible area (below pinned tab bar)
                    return visibility.minY <= tabBarOffset && visibility.maxY > tabBarOffset
                }
                
                if let firstVisible = visibleSections.min(by: { $0.minY < $1.minY }) {
                    if selectedSection != firstVisible.section {
                        selectedSection = firstVisible.section
                    }
                }
            }
            .sheet(isPresented: $showMenuBottomSheet) {
                MenuBottomSheet()
            }
            .sheet(isPresented: $showAddToList) {
                if let movie = viewModel.movie {
                    AddToListView(
                        movieId: movieId,
                        movieTitle: movie.title,
                        onNavigateToList: { listId, listName in
                            navigateToListId = listId
                            navigateToListName = listName
                            showAddToList = false
                            // Trigger navigation after sheet dismisses
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showIndividualList = true
                            }
                        }
                    )
                    .environmentObject(WatchlistManager.shared)
                }
            }
            .fullScreenCover(isPresented: $showIndividualList) {
                if let listId = navigateToListId, let listName = navigateToListName {
                    NavigationStack {
                        IndividualListView(listId: listId, listName: listName)
                            .environmentObject(WatchlistManager.shared)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }
    
    // MARK: - Pinned Header
    
    private func pinnedHeader(_ movie: MovieDetail) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Back Arrow
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                // Title and Details (centered)
                VStack(spacing: 4) {
                    Text(movie.title)
                        .font(.custom("Nunito-Bold", size: 18))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    HStack(spacing: 4) {
                        Text(movie.releaseYear)
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Text("·")
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Text(movie.genres.prefix(2).map { $0.name }.joined(separator: "/"))
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Text("·")
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Text(movie.formattedRuntime)
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
                
                Spacer()
                
                // Share and Menu Icons
                HStack(spacing: 16) {
                    Button(action: {
                        // Share action
                        print("Share tapped")
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                    }
                    
                    Button(action: {
                        showMenuBottomSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Trailer Section
    
    private func trailerSection(_ movie: MovieDetail) -> some View {
        ZStack(alignment: .topLeading) {
            // Backdrop Image
            if let backdropURL = movie.backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(hex: "#1a1a1a"))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(hex: "#1a1a1a"))
                    @unknown default:
                        Rectangle()
                            .fill(Color(hex: "#1a1a1a"))
                    }
                }
                .frame(height: 193)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(hex: "#1a1a1a"))
                    .frame(height: 193)
            }
            
            // Play Trailer Button
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#f3f3f3"))
                
                Text("Play Trailer")
                    .font(.custom("Nunito-Bold", size: 12))
                    .foregroundColor(Color(hex: "#f3f3f3"))
                
                if let duration = formatTrailerDuration(movie.trailerDuration) {
                    Text(duration)
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#ececec"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .padding(.top, 12)
            .padding(.leading, 12)
            .onTapGesture {
                if let trailerURL = movie.trailerURL {
                    print("Play trailer: \(trailerURL)")
                }
            }
        }
        .frame(height: 193)
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Poster and Scores Section
    
    private func posterAndScoresSection(_ movie: MovieDetail) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Poster Image
            if let posterURL = movie.posterURL {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(hex: "#333333"))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(hex: "#333333"))
                    @unknown default:
                        Rectangle()
                            .fill(Color(hex: "#333333"))
                    }
                }
                .frame(width: 84, height: 124)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                Rectangle()
                    .fill(Color(hex: "#333333"))
                    .frame(width: 84, height: 124)
                    .cornerRadius(8)
            }
            
            // Scores Section
            HStack(spacing: 0) {
                // Tasty Score
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image("TastyScoreIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                        
                        Text("Tasty Score")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                    
                    Text(movie.tastyScore != nil ? "\(Int(movie.tastyScore! * 100))%" : "N/A")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Rectangle()
                    .fill(Color(hex: "#ececec"))
                    .frame(width: 1, height: 40)
                
                // AI Score
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image("AIScoreIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                        
                        Text("AI Score")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                    
                    Text(movie.aiScore != nil ? String(format: "%.1f", movie.aiScore!) : "N/A")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Tips and Cards Section
    
    private var tipsAndCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mango's Tips Badge and Text
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    AIFilledIcon(size: 16)
                    Text("MANGO'S TIPS")
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundColor(Color(hex: "#648d00"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 9999)
                        .stroke(Color(hex: "#f7c200"), lineWidth: 1)
                )
                .cornerRadius(9999)
                
                HStack(spacing: 0) {
                    Text("You've been into courtroom dramas lately, and your friends loved this one — Juror #2 might be your next binge. It's smart, tense, and full... ")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#333333"))
                    Text("Read More")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#b56900"))
                        .underline()
                }
                .lineLimit(2)
            }
            
            // Watch On / Liked By cards
            HStack(spacing: 4) {
                // Watch On
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Watch on:")
                            .font(.custom("Nunito-Bold", size: 12))
                            .foregroundColor(Color(hex: "#333333"))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: -6) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "#fdfdfd"), lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 0)
                
                // Liked By
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Liked by:")
                            .font(.custom("Nunito-Bold", size: 12))
                            .foregroundColor(Color(hex: "#333333"))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: -6) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.red)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "#fdfdfd"), lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 0)
            }
        }
    }
    
    // MARK: - Section Tabs Bar
    
    private func sectionTabsBar(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MovieSection.allCases) { section in
                    SectionTabButton(
                        title: section.rawValue,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                        // Scroll to section - need to account for pinned header and tab bar
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Scroll to the section
                            // The anchor .top will position the section at the top of the visible area
                            // We need to account for the pinned header (~80) + tab bar (~52) = ~132 offset
                            proxy.scrollTo(section.id, anchor: .top)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 52)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Overview Section
    
    private func overviewSection(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !movie.overview.isEmpty {
                Text(movie.overview)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No synopsis available")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#999999"))
                    .italic()
            }
            
            if !movie.genres.isEmpty {
                HStack(spacing: 4) {
                    ForEach(movie.genres, id: \.id) { genre in
                        Text(genre.name)
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(Color(hex: "#332100"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#ffedcc"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9999)
                                    .stroke(Color(hex: "#ffdb99"), lineWidth: 1)
                            )
                            .cornerRadius(9999)
                    }
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 0) {
                if let _ = movie.runtime {
                    InfoRow(label: "Running time", value: movie.formattedRuntime)
                }
                
                if !movie.releaseDate.isEmpty {
                    InfoRow(label: "Release dates", value: movie.releaseDate)
                }
                
                InfoRow(label: "Country", value: "United States")
                
                if let rating = movie.rating {
                    InfoRow(label: "Age restrictions", value: rating)
                }
            }
            
            // View More Info link
            HStack {
                Text("View More Info")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Cast & Crew Section (with horizontal scroll)
    
    private func castCrewSection(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text("Cast & Crew")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                Text("See All")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
            
            // Horizontal scrolling cast cards
            if !viewModel.displayedCast.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.displayedCast.prefix(10), id: \.id) { member in
                            VStack(spacing: 8) {
                                // Profile Image
                                AsyncImage(url: member.profileURL) { phase in
                                    switch phase {
                                    case .empty:
                                        Circle()
                                            .fill(Color(hex: "#f0f0f0"))
                                            .frame(width: 80, height: 80)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    case .failure:
                                        Circle()
                                            .fill(Color(hex: "#f0f0f0"))
                                            .frame(width: 80, height: 80)
                                    @unknown default:
                                        Circle()
                                            .fill(Color(hex: "#f0f0f0"))
                                            .frame(width: 80, height: 80)
                                    }
                                }
                                
                                VStack(spacing: 2) {
                                    Text(member.name)
                                        .font(.custom("Nunito-Bold", size: 14))
                                        .foregroundColor(Color(hex: "#1a1a1a"))
                                        .lineLimit(1)
                                    
                                    Text(member.character)
                                        .font(.custom("Inter-Regular", size: 12))
                                        .foregroundColor(Color(hex: "#666666"))
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 100)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
            
            // Director and Writer
            if let director = movie.director {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Director")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    Text(director)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#333333"))
                }
                .padding(.top, 16)
            }
        }
    }
    
    // MARK: - Reviews Section (with horizontal scroll)
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text("Reviews")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                Text("See All")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
            
            // Filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Top")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#333333"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#ffedcc"))
                        .cornerRadius(20)
                    
                    Text("Friends")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                    
                    Text("Relevant Critics")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
            
            // Horizontal scrolling review cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        ReviewCard(index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
            .padding(.top, 12)
            
            // Leave a Review button
            Button(action: {
                print("Leave a Review tapped")
            }) {
                HStack {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16))
                    Text("Leave a Review")
                        .font(.custom("Inter-SemiBold", size: 14))
                }
                .foregroundColor(Color(hex: "#1a1a1a"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#ececec"), lineWidth: 1)
                )
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Similar Section (with horizontal scroll)
    
    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text("More Movies Like This")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                Text("See All")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
            
            // Horizontal scrolling similar movies
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        SimilarMovieCard(index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
    
    // MARK: - Help Us Get Smarter Section
    
    private var helpUsGetSmarterSection: some View {
        VStack(spacing: 16) {
            // Popcorn bucket illustration (placeholder - should be custom image)
            ZStack {
                // Popcorn bucket - using a combination of shapes to approximate
                VStack(spacing: 0) {
                    // Bucket top (red and white stripes)
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(hex: "#FF0000"))
                            .frame(width: 20, height: 4)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 20, height: 4)
                        Rectangle()
                            .fill(Color(hex: "#FF0000"))
                            .frame(width: 20, height: 4)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 20, height: 4)
                    }
                    
                    // Bucket body
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#FF0000"))
                        .frame(width: 80, height: 60)
                        .overlay(
                            // White stripes on bucket
                            VStack(spacing: 4) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 2)
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 2)
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 2)
                            }
                            .padding(.horizontal, 8)
                        )
                    
                    // Popcorn pieces (white circles)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                    }
                    .offset(y: -5)
                }
                
                // Mango icon overlay on popcorn
                MangoLogoIcon(size: 28)
                    .offset(x: -15, y: -10)
                
                // Sparkle icons (small stars)
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: "#FFC966"))
                    .offset(x: 20, y: -15)
                
                Image(systemName: "sparkle")
                    .font(.system(size: 6))
                    .foregroundColor(Color(hex: "#FFC966"))
                    .offset(x: -25, y: 5)
                
                Image(systemName: "sparkle")
                    .font(.system(size: 7))
                    .foregroundColor(Color(hex: "#FFC966"))
                    .offset(x: 25, y: 10)
            }
            .frame(height: 100)
            
            // Title
            Text("Help Us Get Smarter")
                .font(.custom("Nunito-Bold", size: 20))
                .foregroundColor(Color(hex: "#1a1a1a"))
            
            // Taste Level
            HStack(spacing: 4) {
                Text("Taste Level:")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#666666"))
                
                Text("65%")
                    .font(.custom("Inter-Bold", size: 14))
                    .foregroundColor(Color(hex: "#FFA500"))
            }
            
            // Description text
            Text("The more we know about what you like, the better we can pick movies just for you. Rate a few titles to train your recommendations.")
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#333333"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            // Start Rating button
            Button(action: {
                print("Start Rating tapped")
            }) {
                Text("Start Rating")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFC966"), // Bright yellow
                                Color(hex: "#FFA500")  // Orange
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Movie Clips Section
    
    private var movieClipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text("Movie Clips (3)")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                Text("See All")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
            
            // Horizontal scrolling movie clips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        MovieClipCard(index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text("Photos (12)")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                Text("See All")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
            
            // Horizontal scrolling photos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<6) { index in
                        PhotoCard(index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
    
    // MARK: - Bottom Action Buttons
    
    private var bottomActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                WatchlistManager.shared.toggleWatched(movieId: movieId)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Mark as Watched")
                        .font(.custom("Inter-SemiBold", size: 14))
                }
                .foregroundColor(Color(hex: "#333333"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(8)
            }
            
            Button(action: {
                showAddToList = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 16, weight: .medium))
                    Text("Add to Watchlist")
                        .font(.custom("Inter-SemiBold", size: 14))
                }
                .foregroundColor(Color(hex: "#333333"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper
    
    private func formatTrailerDuration(_ durationInSeconds: Int?) -> String? {
        guard let duration = durationInSeconds else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Menu Bottom Sheet

struct MenuBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#b3b3b3"))
                    .frame(width: 32, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            
            // Menu items
            VStack(spacing: 4) {
                MenuItem(
                    icon: "pencil",
                    title: "Make a Note",
                    description: "Make a personal note for this movie.",
                    action: {
                        print("Make a Note tapped")
                        dismiss()
                    }
                )
                
                MenuItem(
                    icon: "text.bubble",
                    title: "Leave a Review",
                    description: "Rate this movie and leave a review.",
                    action: {
                        print("Leave a Review tapped")
                        dismiss()
                    }
                )
                
                MenuItem(
                    icon: "hand.thumbsdown",
                    title: "NOT for Me",
                    description: "Mango will no longer recommend this movie or similar ones.",
                    action: {
                        print("NOT for Me tapped")
                        dismiss()
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            
            Spacer()
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(274)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Menu Item

private struct MenuItem: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#333333"))
                    .frame(width: 24, height: 24)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    Text(description)
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Section Tab Button

private struct SectionTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(isSelected ? Color(hex: "#333333") : Color(hex: "#666666"))
                    .padding(.bottom, 8)
                
                Rectangle()
                    .fill(isSelected ? Color(hex: "#FEA500") : Color.clear)
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - Movie Clip Card

private struct MovieClipCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                // Video thumbnail placeholder
                Rectangle()
                    .fill(Color(hex: "#1a1a1a"))
                    .frame(width: 248, height: 140)
                    .overlay(
                        // Play button overlay
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                        }
                    )
                
                // Duration badge
                VStack {
                    HStack {
                        Spacer()
                        Text("0:30")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            // Clip title
            Text("Clip Title \(index + 1)")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .padding(.top, 8)
                .lineLimit(1)
        }
        .frame(width: 248)
    }
}

// MARK: - Photo Card

private struct PhotoCard: View {
    let index: Int
    
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#f0f0f0"))
            .frame(width: 140, height: 210)
            .overlay(
                // Placeholder image icon
                Image(systemName: "photo.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#999999"))
            )
            .cornerRadius(8)
    }
}

// MARK: - Review Card

private struct ReviewCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "#f0f0f0"))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewer Name")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Text("Sep 12, 2025")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FEA500"))
                    Text("4.0")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
            }
            
            Text("Fusce volutpat lectus et nisi consectetur finibus. In vitae scelerisque augue, in varius eros. Nunc sapien diam, euismod et pr...")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#333333"))
                .lineLimit(3)
            
            Button(action: {}) {
                Text("Full Review")
                    .font(.custom("Inter-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Similar Movie Card

private struct SimilarMovieCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster placeholder
            Rectangle()
                .fill(Color(hex: "#f0f0f0"))
                .frame(width: 120, height: 180)
                .cornerRadius(8)
            
            Text("Movie Title")
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(1)
            
            Text("2024 · Action/Sci-Fi")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
            
            HStack(spacing: 4) {
                Image("TastyScoreIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                Text("99%")
                    .font(.custom("Inter-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FEA500"))
                Text("7.2")
                    .font(.custom("Inter-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#1a1a1a"))
            }
        }
        .frame(width: 120)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(label)
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 120, alignment: .leading)
                
                Text(value)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            
            Divider()
                .background(Color(hex: "#ececec"))
        }
    }
}

// MARK: - Scroll Position Tracking

fileprivate struct SectionVisibility: Equatable {
    let section: MovieSection
    let minY: CGFloat
    let maxY: CGFloat
}

fileprivate struct SectionVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [SectionVisibility] = []
    
    static func reduce(value: inout [SectionVisibility], nextValue: () -> [SectionVisibility]) {
        value.append(contentsOf: nextValue())
    }
}

fileprivate struct TabBarPositionKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview("Normal") {
    MoviePageView(movieId: 550)
}
