//  MoviePageView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-16 at 23:37 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-09 at 19:40 (America/Los_Angeles - Pacific Time)
//  Notes: Fixed horizontal tab bar pinning - tab bar now properly pins below header when scrolling up, and scrolls to sections when tabs are clicked. Updated MenuBottomSheet to match Figma design with correct review icon. Changed AddToListView presentation from fullScreenCover to sheet to match bottom sheet design. Added navigation to list functionality from toast notifications. Replaced deprecated NavigationLink with fullScreenCover for navigating to IndividualListView.
//  Changes: Set 12pt top padding above Overview section for minimal breathing room

import SwiftUI
import UIKit
import SafariServices
import WebKit
import Supabase
import Auth

// MARK: - Sections

private enum MovieSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case castCrew = "Cast & Crew"
    case reviews = "Reviews"
    // TODO: Similar movies disabled - re-enable later
    // Keeping similar case commented out would break Swift - removed from allCases filter instead
    case getSmarter = "Get Smarter"
    case clips = "Movie Clips"
    case photos = "Stills"
    
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
    @State private var showRateBottomSheet = false
    @State private var showPlatformBottomSheet = false
    @State private var showFriendsBottomSheet = false
    @State private var showTrailerPlayer = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var tabBarMinY: CGFloat = 1000 // Start with large value so pinned bar doesn't show initially
    @State private var showIndividualList = false
    @State private var navigateToListId: String? = nil
    @State private var navigateToListName: String? = nil
    @State private var navigateToSearch = false
    @State private var showMangoListeningView = false
    @StateObject private var mangoSpeechRecognizer = SpeechRecognizer()
    @State private var showPosterCarousel = false
    @State private var selectedImageIndex = 0
    @State private var showGoogleSearch = false
    @State private var showGoogleWatchOn = false
    @State private var googleWatchOnURL: URL?
    @State private var showJustWatch = false
    
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
                    tipsAndCardsSection(movie: movie)
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
                        
                        // TODO: Similar Movies section disabled - re-enable later
                        // similarSection
                        //     .id(MovieSection.similar.id)
                        //     .background(
                        //         GeometryReader { geometry in
                        //             let frame = geometry.frame(in: .named("scroll"))
                        //             Color.clear.preference(
                        //                 key: SectionVisibilityPreferenceKey.self,
                        //                 value: [SectionVisibility(
                        //                     section: .similar,
                        //                     minY: frame.minY,
                        //                     maxY: frame.maxY
                        //                 )]
                        //             )
                        //         }
                        //     )
                        
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
                        
                        // Stills section
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
                        
                        // More Info section
                        moreInfoSection
                    }
                    .padding(.top, 12) // Small gap below tab bar for breathing room
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Extra padding to ensure content is visible above pinned buttons
                }
            }
            .coordinateSpace(name: "scroll")
            .background(Color(hex: "#fdfdfd"))
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Pinned Bottom Action Buttons
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(hex: "#f3f3f3").opacity(0.5)) // More translucent divider
                    
                    bottomActionButtons
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea(edges: .all)
                        }
                }
            }
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
                        prefilledRecommender: SearchFilterState.shared.detectedRecommender,
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
            .sheet(isPresented: $showRateBottomSheet) {
                if let movie = viewModel.movie {
                    RateBottomSheet(
                        isPresented: $showRateBottomSheet,
                        movieId: movieId,
                        movieTitle: movie.title
                    )
                }
            }
            .sheet(isPresented: $showPlatformBottomSheet) {
                if let movie = viewModel.movie {
                    PlatformBottomSheet(isPresented: $showPlatformBottomSheet, streaming: movie.streaming)
                } else {
                    PlatformBottomSheet(isPresented: $showPlatformBottomSheet, streaming: nil)
                }
            }
            .sheet(isPresented: $showFriendsBottomSheet) {
                FriendsBottomSheet(isPresented: $showFriendsBottomSheet)
            }
            .sheet(isPresented: $showTrailerPlayer) {
                if let movie = viewModel.movie {
                    let videoId = movie.trailerYoutubeId ?? ""
                    TrailerPlayerSheet(videoId: videoId, movieTitle: movie.title)
                }
            }
            .sheet(isPresented: $showGoogleSearch) {
                if let movie = viewModel.movie {
                    let searchQuery = "\(movie.title) \(movie.releaseYear) movie"
                    let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
                    if let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
                        SafariView(url: url)
                    }
                }
            }
            .sheet(isPresented: $showGoogleWatchOn) {
                if let url = googleWatchOnURL, let movie = viewModel.movie {
                    GoogleWatchOnView(
                        url: url,
                        tmdbId: Int(movieId) ?? 0,
                        movieTitle: movie.title,
                        movieYear: Int(movie.releaseYear) ?? nil,
                        workId: nil // Will be looked up by backend if needed
                    )
                }
            }
            .sheet(isPresented: $showJustWatch) {
                if let movie = viewModel.movie {
                    let searchQuery = movie.title
                    let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
                    if let url = URL(string: "https://www.justwatch.com/us/search?q=\(encodedQuery)") {
                        SafariView(url: url)
                    }
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
            .fullScreenCover(isPresented: $showMangoListeningView) {
                MangoListeningView(
                    speechRecognizer: mangoSpeechRecognizer,
                    isPresented: $showMangoListeningView
                )
            }
            .onChange(of: showMangoListeningView) { oldValue, newValue in
                // Clear movie context when listening view is dismissed
                if oldValue == true && newValue == false {
                    VoiceIntentRouter.setCurrentMovieId(nil)
                    print("🎬 [MoviePageView] Cleared movie context after voice interaction")
                }
            }
            .fullScreenCover(isPresented: $showPosterCarousel) {
                if let movie = viewModel.movie {
                    // Calculate safe index using selectedImageIndex directly
                    let posterCount = movie.posterURL != nil ? 1 : 0
                    let backdropCount = movie.backdropURL != nil ? 1 : 0
                    let maxIndex = posterCount + backdropCount + viewModel.movieImages.count - 1
                    let safeIndex = min(max(selectedImageIndex, 0), max(0, maxIndex))
                    
                    PosterCarouselView(
                        movie: movie,
                        movieImages: viewModel.movieImages,
                        initialIndex: safeIndex,
                        isPresented: $showPosterCarousel
                    )
                    .onAppear {
                        print("🖼️ [MoviePageView] Creating carousel - selectedImageIndex: \(selectedImageIndex), safeIndex: \(safeIndex), maxIndex: \(maxIndex)")
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
                        
                        if let rating = movie.rating, !rating.isEmpty, rating.trimmingCharacters(in: .whitespaces) != "" {
                            Text("·")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                            
                            Text(rating)
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                        
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
                    // Share button (wired from Figma: NAVIGATE or action)
                    Button(action: {
                        // Share action - TODO: Implement share functionality
                        if let movie = viewModel.movie {
                            let activityVC = UIActivityViewController(
                                activityItems: [movie.title, movie.posterURL ?? ""],
                                applicationActivities: nil
                            )
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootViewController = windowScene.windows.first?.rootViewController {
                                rootViewController.present(activityVC, animated: true)
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                    }
                    
                    // Menu button (wired from Figma: OVERLAY → Menu Bottom Sheet)
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
            // Backdrop Image - disable hit testing so button can receive taps
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
                .allowsHitTesting(false) // Allow taps to pass through to button
            } else {
                Rectangle()
                    .fill(Color(hex: "#1a1a1a"))
                    .frame(height: 193)
                    .allowsHitTesting(false) // Allow taps to pass through to button
            }
            
            // Play Trailer Button - bigger and white (using Button like movie clips)
            Button(action: {
                print("🎬 [Trailer] Button tapped for movie: \(movie.title)")
                print("🎬 [Trailer] movie.trailerYoutubeId: \(movie.trailerYoutubeId ?? "nil")")
                print("🎬 [Trailer] movie.trailerURL: \(movie.trailerURL ?? "nil")")
                print("🎬 [Trailer] viewModel.movieVideos count: \(viewModel.movieVideos.count)")
                
                // Try multiple sources for trailer URL
                var youtubeURLToOpen: URL?
                
                // Priority 1: Use trailer_youtube_id from database
                if let trailerYouTubeId = movie.trailerYoutubeId, !trailerYouTubeId.isEmpty {
                    let youtubeURLString = "https://www.youtube.com/watch?v=\(trailerYouTubeId)"
                    print("🎬 [Trailer] Constructing YouTube URL from ID: \(trailerYouTubeId) -> \(youtubeURLString)")
                    youtubeURLToOpen = URL(string: youtubeURLString)
                }
                
                // Priority 2: Extract ID from trailerURL if it's a full URL
                if youtubeURLToOpen == nil, let trailerURL = movie.trailerURL, !trailerURL.isEmpty {
                    print("🎬 [Trailer] Attempting to extract YouTube ID from trailerURL: \(trailerURL)")
                    if let extractedId = extractYouTubeId(from: trailerURL) {
                        let youtubeURLString = "https://www.youtube.com/watch?v=\(extractedId)"
                        print("🎬 [Trailer] Extracted ID: \(extractedId) -> \(youtubeURLString)")
                        youtubeURLToOpen = URL(string: youtubeURLString)
                    } else if trailerURL.contains("youtube.com") || trailerURL.contains("youtu.be") {
                        // If it's already a YouTube URL, use it directly
                        youtubeURLToOpen = URL(string: trailerURL)
                    }
                }
                
                // Priority 3: Fallback to viewModel videos (same as movie clips)
                if youtubeURLToOpen == nil {
                    print("🎬 [Trailer] Checking viewModel.movieVideos for trailer...")
                    if let firstTrailer = viewModel.movieVideos.first(where: { $0.type == "Trailer" }),
                       let youtubeURL = firstTrailer.youtubeURL {
                        print("🎬 [Trailer] Using trailer from viewModel videos: \(youtubeURL)")
                        youtubeURLToOpen = youtubeURL
                    }
                }
                
                // Open embedded player if we have a YouTube ID, otherwise fall back to external
                                if let trailerYouTubeId = movie.trailerYoutubeId, !trailerYouTubeId.isEmpty {
                                    print("🎬 [Trailer] Opening embedded player for: \(trailerYouTubeId)")
                                    showTrailerPlayer = true
                                } else if let url = youtubeURLToOpen {
                                    print("🎬 [Trailer] Opening URL externally: \(url)")
                                    UIApplication.shared.open(url)
                                } else {
                                    print("❌ [Trailer] No valid trailer URL found")
                                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Play Trailer")
                        .font(.custom("Nunito-Bold", size: 18))
                        .foregroundColor(.white)
                    
                    if let duration = formatTrailerDuration(movie.trailerDuration) {
                        Text(duration)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3)) // Add subtle background for better visibility
                .cornerRadius(8)
                .contentShape(Rectangle()) // Ensure entire area is tappable
            }
            .buttonStyle(PlainButtonStyle()) // Prevent default button styling
            .padding(.top, 12)
            .padding(.leading, 12)
        }
        .frame(height: 193)
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Poster and Scores Section
    
    private func posterAndScoresSection(_ movie: MovieDetail) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Poster Image - tappable to expand
            Button(action: {
                // Set initial index to poster (0)
                selectedImageIndex = 0
                showPosterCarousel = true
            }) {
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
            }
            .buttonStyle(PlainButtonStyle())
            
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
    
    private func tipsAndCardsSection(movie: MovieDetail) -> some View {
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
                
                Text("Coming soon")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
            }
            
            // Watch On / Liked By cards (wired from Figma: CHANGE_TO → Expanded states)
            HStack(spacing: 4) {
                // Watch On / Platform Card (wired from Figma: CHANGE_TO → Property 1=4)
                watchOnCard(movie: movie)
                
                // Liked By / Friends Card (wired from Figma: CHANGE_TO → Property 1=2)
                Button(action: {
                    showFriendsBottomSheet = true
                }) {
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
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Watch On Card
    
    private func watchOnCard(movie: MovieDetail) -> some View {
        // Get providers in priority order: flatrate > free > ads
        let providers: [StreamingProvider] = {
            guard let streaming = movie.streaming,
                  let us = streaming.us else {
                return []
            }
            
            var allProviders: [StreamingProvider] = []
            
            // Priority 1: Subscription streaming (most important)
            if let flatrate = us.flatrate {
                allProviders.append(contentsOf: flatrate)
            }
            
            // Priority 2: Free streaming
            if let free = us.free {
                allProviders.append(contentsOf: free)
            }
            
            // Priority 3: Free with ads
            if let ads = us.ads {
                allProviders.append(contentsOf: ads)
            }
            
            // Limit to first 3 for display
            return Array(allProviders.prefix(3))
        }()
        
        let hasProviders = !providers.isEmpty
        
        return Button(action: {
            if hasProviders {
                // Show the bottom sheet with all streaming platforms
                showPlatformBottomSheet = true
            } else {
                // No streaming data - open Google and scroll to "Where to watch" section
                let searchQuery = "\(movie.title) \(movie.releaseYear) movie where to watch"
                let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
                if let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
                    googleWatchOnURL = url
                    showGoogleWatchOn = true
                }
            }
        }) {
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
                
                if hasProviders {
                    HStack(spacing: -6) {
                        ForEach(providers) { provider in
                            AsyncImage(url: provider.logoURL) { phase in
                                switch phase {
                                case .empty:
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: "#fdfdfd"), lineWidth: 2)
                                        )
                                case .failure:
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                @unknown default:
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                }
                            }
                        }
                    }
                } else {
                    Text("More info")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#999999"))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Section Tabs Bar
    
    private func sectionTabsBar(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // TODO: Filter out disabled similar section - use activeCases instead of allCases
                ForEach(MovieSection.allCases.filter { section in
                    // Filter out similar section (commented out in enum but still exists)
                    section.rawValue != "More to Watch"
                }) { section in
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
                    InfoRow(label: "Release dates", value: formatReleaseDate(movie.releaseDate))
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
                    HStack(spacing: 1) {
                        ForEach(viewModel.displayedCast.prefix(10), id: \.id) { member in
                            VStack(spacing: 8) {
                                // Profile Image - 8% larger with 40% less spacing
                                AsyncImage(url: member.profileURL) { phase in
                                    switch phase {
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "#f0f0f0"))
                                            .frame(width: 119, height: 178)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 119, height: 178)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "#f0f0f0"))
                                            .frame(width: 119, height: 178)
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "#f0f0f0"))
                                            .frame(width: 119, height: 178)
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
                            .frame(width: 140)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
            
            // All Crew Positions - stacked vertically with aligned names
            VStack(alignment: .leading, spacing: 12) {
                ForEach(getCrewPositions(from: movie), id: \.job) { position in
                    HStack(alignment: .top, spacing: 0) {
                        Text(position.job)
                            .font(.custom("Inter-SemiBold", size: 14))
                            .foregroundColor(Color(hex: "#666666"))
                            .frame(width: 100, alignment: .leading)
                        
                        Text(position.names)
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#333333"))
                    }
                }
            }
            .padding(.top, 16)
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
            
            // Leave a Review button (wired from Figma: OVERLAY → Rate Bottom Sheet)
            Button(action: {
                showRateBottomSheet = true
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
                    
                    Text("Similar Movies")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
            }
            
            // Coming Soon placeholder - Similar Movies feature temporarily disabled
            VStack(spacing: 8) {
                Text("Coming Soon")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#999999"))
                    .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // Start Rating button (wired from Figma: OVERLAY → Rate Bottom Sheet)
            Button(action: {
                showRateBottomSheet = true
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
                    
                    Text("Movie Clips (\(viewModel.movieVideos.count))")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                if !viewModel.movieVideos.isEmpty {
                    Text("See All")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#FEA500"))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FEA500"))
                }
            }
            
            // Horizontal scrolling movie clips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !viewModel.movieVideos.isEmpty {
                        ForEach(viewModel.movieVideos.prefix(5)) { video in
                            MoviePageClipCard(video: video)
                        }
                    } else {
                        // Show loading placeholders while videos are being fetched
                        ForEach(0..<3) { index in
                            MovieClipCard(index: index)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
    
    // MARK: - Stills Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#FEA500"))
                        .frame(width: 6, height: 6)
                    
                    Text("Stills")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                if !viewModel.movieImages.isEmpty {
                    Text("See All")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#FEA500"))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FEA500"))
                }
            }
            
            // Horizontal scrolling photos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !viewModel.movieImages.isEmpty {
                        ForEach(Array(viewModel.movieImages.prefix(5).enumerated()), id: \.offset) { displayIndex, image in
                            MoviePagePhotoCard(
                                image: image,
                                onTap: {
                                    // Calculate index in carousel array
                                    // Carousel order: [poster (if exists), backdrop (if exists), ...photos]
                                    // The displayed images are prefix(5) of movieImages, so displayIndex matches the position
                                    var photosStartIndex = 0
                                    if viewModel.movie?.posterURL != nil {
                                        photosStartIndex += 1 // Poster takes index 0
                                    }
                                    if viewModel.movie?.backdropURL != nil {
                                        photosStartIndex += 1 // Backdrop takes next index
                                    }
                                    // Now photosStartIndex is where photos begin in the carousel
                                    // displayIndex is the position in the displayed prefix(5) array, which matches movieImages
                                    let carouselIndex = photosStartIndex + displayIndex
                                    
                                    print("🖼️ [MoviePageView] Tapped still - displayIndex: \(displayIndex), carouselIndex: \(carouselIndex)")
                                    print("🖼️ [MoviePageView] Poster exists: \(viewModel.movie?.posterURL != nil), Backdrop exists: \(viewModel.movie?.backdropURL != nil), photosStartIndex: \(photosStartIndex)")
                                    
                                    selectedImageIndex = carouselIndex
                                    showPosterCarousel = true
                                }
                            )
                        }
                    } else {
                        // Show loading placeholders while images are being fetched
                        ForEach(0..<6) { index in
                            PhotoCard(index: index)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
    
    // MARK: - More Info Section
    
    private var moreInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("More Info")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Spacer()
                
                Button(action: {
                    showGoogleSearch = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                        Text("Google")
                            .font(.custom("Inter-SemiBold", size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#FEA500"))
                    .cornerRadius(8)
                }
            }
            
            // Where to Watch row
            HStack {
                Text("Where to Watch")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Spacer()
                
                Button(action: {
                    showJustWatch = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 14, weight: .medium))
                        Text("JustWatch")
                            .font(.custom("Inter-SemiBold", size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#FEA500"))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Bottom Action Buttons
    
    private var bottomActionButtons: some View {
        let isWatched = WatchlistManager.shared.isWatched(movieId: movieId)
        let isInWatchlist = !WatchlistManager.shared.getListsForMovie(movieId: movieId).isEmpty
        
        return ZStack(alignment: .bottom) {
            HStack(spacing: 12) {
                // Mark as Watched button (wired from Figma: CHANGE_TO → Active state, OVERLAY → Rate Bottom Sheet)
                Button(action: {
                    // Only show rating sheet when marking as watched (not when un-watching)
                    let wasWatched = isWatched
                    // Toggle watched status (CHANGE_TO connection - changes button state)
                    // This will automatically sync to Supabase and trigger a full sync
                    WatchlistManager.shared.toggleWatched(movieId: movieId)
                    // Show rate bottom sheet only when marking as watched (per Figma prototype connection)
                    if !wasWatched {
                        showRateBottomSheet = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isWatched ? "popcorn.fill" : "popcorn")
                            .font(.system(size: 16, weight: .medium))
                        Text(isWatched ? "Watched" : "Mark as Watched")
                            .font(.custom("Inter-SemiBold", size: 14))
                    }
                    .foregroundColor(isWatched ? Color(hex: "#648d00") : Color(hex: "#333333"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isWatched ? Color(hex: "#f0f7e0") : Color(hex: "#F5F5F5"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isWatched ? Color(hex: "#648d00").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                
                // Spacer for center button
                Spacer()
                    .frame(width: 56)
                
                Button(action: {
                    showAddToList = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "list.bullet.rectangle")
                            .font(.system(size: 16, weight: .medium))
                        Text(isInWatchlist ? "In Watchlist" : "Add to Watchlist")
                            .font(.custom("Inter-SemiBold", size: 14))
                    }
                    .foregroundColor(isInWatchlist ? Color(hex: "#648d00") : Color(hex: "#333333"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isInWatchlist ? Color(hex: "#f0f7e0") : Color(hex: "#F5F5F5"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isInWatchlist ? Color(hex: "#648d00").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
            }
            
            // Mango button - universal functionality, elevated 50% above buttons
            Button(action: {
                // Set movie context before presenting listening view so voice commands know which movie we're on
                if let movie = viewModel.movie {
                    VoiceIntentRouter.setCurrentMovieId(movieId)
                    print("🎬 [MoviePageView] Set movie context for voice: \(movieId) - \(movie.title)")
                }
                showMangoListeningView = true
            }) {
                ZStack {
                    // Prominent filled orange circular background with gradient (matches tab bar)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#FFA500"),
                                    Color(hex: "#FF8C00")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            // Border with white opacity
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .frame(width: 56, height: 56)
                        )
                        .overlay(
                            // Inner shadow/glow effect
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                                .frame(width: 56, height: 56)
                                .blendMode(.overlay)
                        )
                    
                    // White mango logo icon inside the circle (matches tab bar)
                    MangoLogoIcon(size: 28, color: .white)
                }
                .shadow(color: Color(hex: "#FFA500").opacity(0.4), radius: 12, x: 0, y: 4)
            }
            .offset(y: -28) // Elevate 50% above buttons (56/2 = 28)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Functions
    
    // MARK: - Crew Position Data Structure
    struct CrewPosition: Identifiable {
        let id: String
        let job: String
        let names: String
    }
    
    private func getCrewPositions(from movie: MovieDetail) -> [CrewPosition] {
        guard let crew = movie.crew, !crew.isEmpty else { return [] }
        
        // Group crew by job title
        var positions: [String: [String]] = [:]
        
        for member in crew {
            let job = normalizeJobTitle(member.job)
            if positions[job] == nil {
                positions[job] = []
            }
            positions[job]?.append(member.name)
        }
        
        // Define priority order for display
        let priorityOrder = [
            "Director",
            "Writer",
            "Screenplay",
            "Producer",
            "Director of Photography",
            "Cinematography",
            "Composer",
            "Original Music Composer",
            "Music",
            "Editor",
            "Production Design",
            "Costume Design",
            "Makeup",
            "Sound",
            "Visual Effects"
        ]
        
        // Sort positions by priority, then alphabetically
        let sortedPositions = positions.sorted { first, second in
            let firstIndex = priorityOrder.firstIndex(of: first.key) ?? Int.max
            let secondIndex = priorityOrder.firstIndex(of: second.key) ?? Int.max
            
            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }
            return first.key < second.key
        }
        
        // Convert to CrewPosition array
        return sortedPositions.map { job, names in
            CrewPosition(
                id: job,
                job: job,
                names: names.joined(separator: ", ")
            )
        }
    }
    
    private func normalizeJobTitle(_ job: String) -> String {
        // Normalize job titles for consistent display
        let normalized: String
        switch job.lowercased() {
        case "screenplay", "writer", "story":
            normalized = "Writer"
        case "director of photography", "cinematography":
            normalized = "Director of Photography"
        case "original music composer", "music":
            normalized = "Composer"
        default:
            normalized = job
        }
        return normalized
    }
    
    /// Extracts YouTube ID from a YouTube URL string
    private func extractYouTubeId(from urlString: String) -> String? {
        // Handle formats like: https://www.youtube.com/watch?v=VIDEO_ID
        if let range = urlString.range(of: "watch?v=") {
            let idStart = urlString.index(range.upperBound, offsetBy: 0)
            let id = String(urlString[idStart...])
            // Remove any query parameters after the ID
            if let ampersandIndex = id.firstIndex(of: "&") {
                return String(id[..<ampersandIndex])
            }
            return id
        }
        // Handle short format: https://youtu.be/VIDEO_ID
        if let range = urlString.range(of: "youtu.be/") {
            let idStart = urlString.index(range.upperBound, offsetBy: 0)
            let id = String(urlString[idStart...])
            if let questionIndex = id.firstIndex(of: "?") {
                return String(id[..<questionIndex])
            }
            return id
        }
        return nil
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        // Parse date string (format: "YYYY-MM-DD" or similar)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = dateFormatter.date(from: dateString) {
            // Format as "Month Day, Year" (e.g., "November 1, 2024")
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMMM d, yyyy"
            return outputFormatter.string(from: date)
        }
        
        // Fallback: try to extract year if format is different
        if Int(dateString.prefix(4)) != nil {
            return dateString // Return as-is if we can't parse
        }
        
        return dateString // Return original if parsing fails
    }
    
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

private struct MoviePageClipCard: View {
    let video: TMDBVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                // Video thumbnail from YouTube
                if let thumbnailURL = video.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(hex: "#1a1a1a"))
                                .frame(width: 248, height: 140)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 248, height: 140)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color(hex: "#1a1a1a"))
                                .frame(width: 248, height: 140)
                        @unknown default:
                            Rectangle()
                                .fill(Color(hex: "#1a1a1a"))
                                .frame(width: 248, height: 140)
                        }
                    }
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
                    .onTapGesture {
                        if let youtubeURL = video.youtubeURL {
                            UIApplication.shared.open(youtubeURL)
                        }
                    }
                } else {
                    // Fallback placeholder
                    Rectangle()
                        .fill(Color(hex: "#1a1a1a"))
                        .frame(width: 248, height: 140)
                        .overlay(
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#1a1a1a"))
                            }
                        )
                        .onTapGesture {
                            if let youtubeURL = video.youtubeURL {
                                UIApplication.shared.open(youtubeURL)
                            }
                        }
                }
            }
            
            // Clip title
            Text(video.name)
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .padding(.top, 8)
                .lineLimit(2)
        }
        .frame(width: 248)
        .onTapGesture {
            if let youtubeURL = video.youtubeURL {
                UIApplication.shared.open(youtubeURL)
            }
        }
    }
}

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
            }
            
            // Clip title placeholder
            Text("Loading...")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .padding(.top, 8)
                .lineLimit(1)
        }
        .frame(width: 248)
    }
}

// MARK: - Photo Card

private struct MoviePagePhotoCard: View {
    let image: TMDBImage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: image.imageURL) { phase in
                switch phase {
                case .empty:
                    // Loading placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#E0E0E0"))
                        .frame(width: 140, height: 210)
                        .overlay(
                            ProgressView()
                        )
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 210)
                        .clipped()
                        .cornerRadius(8)
                case .failure:
                    // Error placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#E0E0E0"))
                        .frame(width: 140, height: 210)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(Color(hex: "#999999"))
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#E0E0E0"))
                        .frame(width: 140, height: 210)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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

private struct MoviePageSimilarMovieCard: View {
    let movie: Movie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            MoviePosterImage(
                posterURL: movie.posterImageURL,
                width: 120,
                height: 180,
                cornerRadius: 8
            )
            
            Text(movie.title)
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(1)
            
            // Year and genres
            HStack(spacing: 4) {
                Text(String(movie.year))
                if !movie.genres.isEmpty {
                    Text("·")
                    Text(movie.genres.prefix(2).joined(separator: "/"))
                        .lineLimit(1)
                }
            }
            .font(.custom("Inter-Regular", size: 12))
            .foregroundColor(Color(hex: "#666666"))
            
            // Scores
            HStack(spacing: 4) {
                // Tasty Score
                if let tastyScore = movie.tastyScore {
                    Image("TastyScoreIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                    Text("\(Int(tastyScore * 100))%")
                        .font(.custom("Inter-SemiBold", size: 12))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                // AI Score
                if let aiScore = movie.aiScore {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FEA500"))
                    Text(String(format: "%.1f", aiScore))
                        .font(.custom("Inter-SemiBold", size: 12))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
            }
        }
        .frame(width: 120)
    }
}

private struct SimilarMovieCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster placeholder
            Rectangle()
                .fill(Color(hex: "#f0f0f0"))
                .frame(width: 120, height: 180)
                .cornerRadius(8)
            
            Text("Loading...")
                .font(.custom("Nunito-Bold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(1)
            
            Text("—")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
            
            HStack(spacing: 4) {
                Spacer()
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

// MARK: - Safari View Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No update needed
    }
}

// Custom WebView that scrolls to "Where to watch" section on Google and captures streaming data
struct GoogleWatchOnView: UIViewControllerRepresentable {
    let url: URL
    let tmdbId: Int
    let movieTitle: String
    let movieYear: Int?
    let workId: Int?
    
    func makeUIViewController(context: Context) -> GoogleWatchOnViewController {
        return GoogleWatchOnViewController(
            url: url,
            tmdbId: tmdbId,
            movieTitle: movieTitle,
            movieYear: movieYear,
            workId: workId
        )
    }
    
    func updateUIViewController(_ uiViewController: GoogleWatchOnViewController, context: Context) {
        // No update needed
    }
}

class GoogleWatchOnViewController: UIViewController {
    let url: URL
    let tmdbId: Int
    let movieTitle: String
    let movieYear: Int?
    let workId: Int?
    var webView: WKWebView?
    
    init(url: URL, tmdbId: Int, movieTitle: String, movieYear: Int?, workId: Int?) {
        self.url = url
        self.tmdbId = tmdbId
        self.movieTitle = movieTitle
        self.movieYear = movieYear
        self.workId = workId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create WKWebView configuration
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        self.webView = webView
        
        view.addSubview(webView)
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.systemBlue, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
        
        // Load the URL
        webView.load(URLRequest(url: url))
    }
    
    @objc func closeTapped() {
        dismiss(animated: true)
    }
    
    func scrollToWhereToWatch() {
        // JavaScript to find and scroll to "Where to watch" section on Google
        // Google's movie search results have a "Where to watch" section that we need to scroll to
        let script = """
        (function() {
            // Function to find element containing text
            function findElementWithText(text, tagName) {
                const elements = document.querySelectorAll(tagName || '*');
                for (let el of elements) {
                    const elText = (el.textContent || el.innerText || '').trim();
                    if (elText === text || elText.startsWith(text)) {
                        return el;
                    }
                }
                return null;
            }
            
            // Try to find "Where to watch" heading (usually an H2 or H3)
            let targetElement = findElementWithText('Where to watch', 'h2') || 
                               findElementWithText('Where to watch', 'h3') ||
                               findElementWithText('Where to watch', 'div');
            
            // If not found, search all elements
            if (!targetElement) {
                const allElements = document.querySelectorAll('*');
                for (let el of allElements) {
                    const text = (el.textContent || el.innerText || '').trim();
                    // Look for exact match or starts with "Where to watch"
                    if ((text === 'Where to watch' || text.startsWith('Where to watch')) && 
                        el.offsetHeight > 0 && 
                        (el.tagName === 'H2' || el.tagName === 'H3' || el.tagName === 'DIV')) {
                        targetElement = el;
                        break;
                    }
                }
            }
            
            if (targetElement) {
                // Scroll the element into view
                targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                
                // Add a small offset to account for headers
                setTimeout(() => {
                    window.scrollBy({ top: -80, behavior: 'smooth' });
                }, 500);
                
                return true;
            }
            
            // Fallback: scroll down to approximate position where "Where to watch" usually appears
            // On mobile Google, it's typically around 400-600px down
            setTimeout(() => {
                window.scrollTo({ top: 500, behavior: 'smooth' });
            }, 1000);
            
            return false;
        })();
        """
        
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("⚠️ [GoogleWatchOn] Error scrolling: \(error.localizedDescription)")
            } else {
                if let success = result as? Bool, success {
                    print("✅ [GoogleWatchOn] Successfully scrolled to 'Where to watch' section")
                } else {
                    print("⚠️ [GoogleWatchOn] Used fallback scroll position")
                }
            }
        }
    }
}

extension GoogleWatchOnViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a bit for the page to fully render, then scroll and capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.scrollToWhereToWatch()
            // Capture streaming data in background (non-blocking)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.captureStreamingData()
            }
        }
    }
    
    func captureStreamingData() {
        // Simplified JavaScript - minimal version to test
        let script = """
        (function() {
            try {
            console.log('[GoogleCapture] Starting capture...');
            var providers = [];
            var seenProviders = {};
            
            // Find the "Available on" section
            function findAvailableOnSection() {
                // Look for heading "Available on" or "Where to watch"
                var headings = document.querySelectorAll('h2, h3, div[role="heading"], span');
                var section = null;
                
                for (var i = 0; i < headings.length; i++) {
                    var heading = headings[i];
                    var text = (heading.textContent || heading.innerText || '').trim();
                    if (text === 'Available on' || text === 'Where to watch' || text.indexOf('Available on') === 0) {
                        // Find the parent container that holds the list
                        var parent = heading.parentElement;
                        for (var j = 0; j < 8 && parent; j++) {
                            // Look for list items or cards
                            var hasListItems = parent.querySelectorAll('[role="listitem"], div[data-ved], a[href*="watch"], button').length > 0;
                            if (hasListItems || parent.querySelectorAll('img').length > 3) {
                                section = parent;
                                break;
                            }
                            parent = parent.parentElement;
                        }
                        if (!section) section = heading.parentElement;
                        break;
                    }
                }
                
                return section;
            }
            
            // Extract provider from a container element
            function extractProviderFromContainer(container) {
                var fullText = (container.textContent || container.innerText || '').trim();
                
                // Skip if contains price indicators
                if (fullText.indexOf('$') !== -1 || fullText.match(/From \\$\\d+/)) {
                    return null;
                }
                
                // Skip UI elements and buttons (Google's interface text)
                // Only match exact phrases or whole words to avoid false positives
                var uiTextPatterns = [
                    /Added to your services/i,
                    /Removed from your services/i,
                    /Your change wasn't saved/i,
                    /\\bUNDO\\b/i,  // Whole word only
                    /TRY AGAIN/i,
                    /EDIT SERVICES/i
                ];
                
                for (var i = 0; i < uiTextPatterns.length; i++) {
                    if (uiTextPatterns[i].test(fullText)) {
                        console.log('[GoogleCapture] Skipping UI text: ' + fullText.substring(0, 50));
                        return null;
                    }
                }
                
                // Check for single-word UI terms (exact matches only)
                var uiWords = ['Added', 'Removed', 'Your', 'UNDO', 'EDIT', 'SERVICES', 'Watch', 'Available', 'on'];
                var trimmedText = fullText.trim();
                var isUIWord = false;
                for (var j = 0; j < uiWords.length; j++) {
                    if (uiWords[j] === trimmedText) {
                        isUIWord = true;
                        break;
                    }
                }
                if (isUIWord || trimmedText === 'TRY AGAIN') {
                    console.log('[GoogleCapture] Skipping UI word: ' + trimmedText);
                    return null;
                }
                
                // Find provider name - look for text that looks like a service name
                // Common patterns: "Amazon Prime Video", "Netflix", "HBO MAX", etc.
                var providerNamePatterns = [
                    /(Amazon Prime Video|Prime Video)/i,
                    /(Netflix)/i,
                    /(HBO MAX|HBO|MAX)/i,
                    /(Disney\\+?|Disney Plus)/i,
                    /(Hulu)/i,
                    /(Paramount\\+?|Paramount Plus)/i,
                    /(Apple TV\\+?|Apple TV Plus)/i,
                    /(Peacock)/i,
                    /(Showtime)/i,
                    /(Starz)/i,
                    /(Xumo Play|Xumo)/i,
                    /(Plex)/i,
                    /(Sling TV|Sling)/i,
                    /(YouTube TV|YouTube)/i,
                    /(Pluto TV|Pluto)/i,
                    /(Tubi)/i,
                    /(Crackle)/i,
                    /(Vudu)/i,
                    /(Fubo TV|Fubo)/i,
                    /(Philo)/i
                ];
                
                var providerName = null;
                for (var k = 0; k < providerNamePatterns.length; k++) {
                    var match = fullText.match(providerNamePatterns[k]);
                    if (match) {
                        providerName = match[1] || match[0];
                        console.log('[GoogleCapture] Found provider via pattern: ' + providerName + ' in: ' + fullText.substring(0, 60));
                        break;
                    }
                }
                
                // If no pattern match, try to extract from structure
                if (!providerName) {
                    // Look for text that's likely a provider name (capitalized, 2-30 chars, not common words)
                    var uiWordsList = ['Watch', 'Available', 'on', 'Free', 'Subscription', 'EDIT', 'SERVICES', 'Requires', 'add-on', 'Added', 'Removed', 'Your', 'UNDO', 'TRY', 'AGAIN', 'to', 'your', 'services', 'change', "wasn't", 'saved'];
                    var words = [];
                    var currentWord = '';
                    for (var charIdx = 0; charIdx < fullText.length; charIdx++) {
                        var char = fullText.charAt(charIdx);
                        var charCode = char.charCodeAt(0);
                        if (charCode === 32 || charCode === 9 || charCode === 10 || charCode === 13) {
                            if (currentWord.length > 0) {
                                words.push(currentWord);
                                currentWord = '';
                            }
                        } else {
                            currentWord += char;
                        }
                    }
                    if (currentWord.length > 0) {
                        words.push(currentWord);
                    }
                    for (var m = 0; m < words.length; m++) {
                        var word = words[m].trim();
                        var isUIWord2 = false;
                        for (var n = 0; n < uiWordsList.length; n++) {
                            if (uiWordsList[n] === word) {
                                isUIWord2 = true;
                                break;
                            }
                        }
                        if (word.length >= 2 && word.length <= 30 && 
                            /^[A-Z]/.test(word) && 
                            !isUIWord2) {
                            // Try to get multi-word provider names
                            var name = word;
                            if (m + 1 < words.length && words[m + 1].trim().length > 0) {
                                var nextWord = words[m + 1].trim();
                                var isBadWord = (nextWord === 'Free' || nextWord === 'Subscription' || nextWord === 'Watch');
                                if (/^[A-Z]/.test(nextWord) && !isBadWord) {
                                    name = word + ' ' + nextWord;
                                    if (m + 2 < words.length && words[m + 2].trim() === 'Video' && word.indexOf('Prime') !== -1) {
                                        name = word + ' ' + nextWord + ' ' + words[m + 2].trim();
                                    }
                                }
                            }
                            if (name.length >= 3 && name.length <= 30) {
                                providerName = name;
                                break;
                            }
                        }
                    }
                }
                
                if (!providerName) return null;
                
                // Final validation: reject UI words that might have slipped through
                var providerNameTrimmed = providerName.trim();
                var uiWordsExact = ['Added', 'Removed', 'Your', 'UNDO', 'TRY', 'AGAIN', 'EDIT', 'SERVICES', 'Watch', 'Available', 'on'];
                var isExactUIWord = false;
                for (var p = 0; p < uiWordsExact.length; p++) {
                    if (uiWordsExact[p] === providerNameTrimmed) {
                        isExactUIWord = true;
                        break;
                    }
                }
                
                // Only reject if it's an exact match or contains UI phrases
                var lowerName = providerNameTrimmed.toLowerCase();
                if (isExactUIWord || 
                    lowerName === 'try again' ||
                    lowerName.indexOf('wasn\'t saved') !== -1 ||
                    lowerName === 'added to your services' ||
                    lowerName === 'removed from your services') {
                    console.log('[GoogleCapture] Rejected UI word in final validation: ' + providerNameTrimmed);
                    return null;
                }
                
                // Ensure provider name looks legitimate (contains letters, not just UI text)
                if (!/[A-Za-z]{3,}/.test(providerNameTrimmed)) {
                    console.log('[GoogleCapture] Rejected - too short or no letters: ' + providerNameTrimmed);
                    return null;
                }
                
                console.log('[GoogleCapture] Accepted provider: ' + providerNameTrimmed);
                
                // Find availability text - use simple string matching instead of regex
                var availability = 'subscription'; // default
                var lowerText = fullText.toLowerCase();
                if (lowerText.indexOf('free') !== -1 && lowerText.indexOf('subscription') === -1) {
                    availability = 'Free';
                } else if (lowerText.indexOf('primetime subscription') !== -1) {
                    availability = 'Primetime subscription';
                } else if (lowerText.indexOf('subscription add-on') !== -1 || lowerText.indexOf('requires add-on') !== -1) {
                    availability = 'Subscription add-on';
                } else if (lowerText.indexOf('subscription') !== -1) {
                    availability = 'Subscription';
                }
                
                // Skip paid options
                if (fullText.match(/\\$\\d+|From \\$\\d+/)) {
                    return null;
                }
                
                // Find logo
                var logoUrl = null;
                var img = container.querySelector('img');
                if (img && img.src && img.src.indexOf('data:') === -1 && img.src.length > 10) {
                    logoUrl = img.src;
                }
                
                return {
                    provider_name: providerName.trim(),
                    availability_text: availability,
                    provider_logo_url: logoUrl
                };
            }
            
            var section = findAvailableOnSection();
            if (!section) {
                console.log('[GoogleCapture] Could not find Available on section');
                // Debug: try to find any mention of "Available on" in the page
                var bodyText = document.body.innerText || '';
                if (bodyText.indexOf('Available on') !== -1 || bodyText.indexOf('Where to watch') !== -1) {
                    console.log('[GoogleCapture] Found "Available on" text in page but couldn't locate section');
                }
                return JSON.stringify([]);
            }
            
            console.log('[GoogleCapture] Found section, searching for providers...');
            console.log('[GoogleCapture] Section has ' + section.querySelectorAll('div, span, a').length + ' child elements');
            
            // Strategy 1: Look for list items or cards
            var listItems = section.querySelectorAll('[role="listitem"], div[data-ved], a[href*="watch"], button[aria-label*="Watch"]');
            for (var r = 0; r < listItems.length; r++) {
                var item = listItems[r];
                var provider = extractProviderFromContainer(item);
                if (provider) {
                    var lowerName2 = provider.provider_name.toLowerCase();
                    if (!seenProviders[lowerName2]) {
                        seenProviders[lowerName2] = true;
                        providers.push({
                            provider_name: provider.provider_name,
                            availability_text: provider.availability_text,
                            provider_logo_url: provider.provider_logo_url,
                            raw_data: {
                                full_text: (item.textContent || item.innerText || '').trim().substring(0, 200),
                                element_tag: item.tagName
                            }
                        });
                    }
                }
            }
            
            // Strategy 2: If no providers found, look for divs containing provider logos and text
            if (providers.length === 0) {
                var allDivs = section.querySelectorAll('div');
                for (var s = 0; s < allDivs.length; s++) {
                    var div = allDivs[s];
                    // Check if this div contains an image (logo)
                    if (div.querySelector('img')) {
                        var provider2 = extractProviderFromContainer(div);
                        if (provider2) {
                            var lowerName3 = provider2.provider_name.toLowerCase();
                            if (!seenProviders[lowerName3]) {
                                seenProviders[lowerName3] = true;
                                providers.push({
                                    provider_name: provider2.provider_name,
                                    availability_text: provider2.availability_text,
                                    provider_logo_url: provider2.provider_logo_url,
                                    raw_data: {
                                        full_text: (div.textContent || div.innerText || '').trim().substring(0, 200),
                                        element_tag: div.tagName
                                    }
                                });
                            }
                        }
                    }
                }
            }
            
            // Strategy 3: Fallback - search entire section text for provider names
            if (providers.length === 0) {
                var sectionText = (section.innerText || section.textContent || '').toLowerCase();
                var providerList = ['amazon prime video', 'prime video', 'netflix', 'hbo max', 'hbo', 'disney plus', 'disney+', 'hulu', 'paramount plus', 'paramount+', 'apple tv plus', 'apple tv+', 'peacock', 'showtime', 'starz', 'xumo play', 'xumo', 'plex', 'sling tv', 'sling', 'youtube tv', 'youtube', 'pluto tv', 'pluto', 'tubi', 'crackle', 'vudu', 'fubo tv', 'fubo', 'philo'];
                var providerDisplayNames = ['Amazon Prime Video', 'Prime Video', 'Netflix', 'HBO MAX', 'HBO', 'Disney Plus', 'Disney Plus', 'Hulu', 'Paramount Plus', 'Paramount Plus', 'Apple TV Plus', 'Apple TV Plus', 'Peacock', 'Showtime', 'Starz', 'Xumo Play', 'Xumo', 'Plex', 'Sling TV', 'Sling', 'YouTube TV', 'YouTube', 'Pluto TV', 'Pluto', 'Tubi', 'Crackle', 'Vudu', 'Fubo TV', 'Fubo', 'Philo'];
                
                for (var idx = 0; idx < providerList.length; idx++) {
                    var searchName = providerList[idx];
                    var displayName = providerDisplayNames[idx];
                    if (sectionText.indexOf(searchName) !== -1) {
                        var lowerDisplay = displayName.toLowerCase();
                        if (!seenProviders[lowerDisplay]) {
                            seenProviders[lowerDisplay] = true;
                            var avail = 'subscription';
                            if (sectionText.indexOf('free') !== -1 && sectionText.indexOf('subscription') === -1) {
                                avail = 'Free';
                            }
                            providers.push({
                                provider_name: displayName,
                                availability_text: avail,
                                provider_logo_url: null,
                                raw_data: { full_text: 'Found in section text' }
                            });
                        }
                    }
                }
            }
            
            var providerNames = [];
            for (var v = 0; v < providers.length; v++) {
                providerNames.push(providers[v].provider_name);
            }
            console.log('[GoogleCapture] Found ' + providers.length + ' providers: ' + providerNames.join(', '));
            
            if (providers.length === 0) {
                var sectionText = (section.innerText || section.textContent || '').substring(0, 300);
                console.log('[GoogleCapture] WARNING: No providers found. Section text sample: ' + sectionText);
            }
            
            console.log('[GoogleCapture] Returning ' + providers.length + ' providers');
            return JSON.stringify(providers);
            } catch (error) {
                var errorMsg = 'Unknown error';
                try {
                    errorMsg = error.message || String(error);
                } catch (e) {
                    errorMsg = 'Error getting error message: ' + String(e);
                }
                console.error('[GoogleCapture] JavaScript error: ' + errorMsg);
                try {
                    if (error.stack) {
                        console.error('[GoogleCapture] Stack: ' + error.stack);
                    }
                } catch (e) {
                    console.error('[GoogleCapture] Could not log stack');
                }
                return JSON.stringify([]);
            }
        })();
        """
        
        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("⚠️ [GoogleWatchOn] Error capturing streaming data: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("⚠️ [GoogleWatchOn] Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("⚠️ [GoogleWatchOn] Error userInfo: \(nsError.userInfo)")
                }
                // Try to get more details from the web view's console
                self.webView?.evaluateJavaScript("console.log('[GoogleCapture] Error occurred in capture script')") { _, _ in }
                return
            }
            
            guard let jsonString = result as? String else {
                print("⚠️ [GoogleWatchOn] No result returned from JavaScript")
                return
            }
            
            print("🔍 [GoogleWatchOn] JavaScript returned: \(jsonString.prefix(500))")
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let providers = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                print("⚠️ [GoogleWatchOn] Failed to parse JSON: \(jsonString)")
                return
            }
            
            if providers.count == 0 {
                print("⚠️ [GoogleWatchOn] No providers found in Google results")
                return
            }
            
            print("✅ [GoogleWatchOn] Captured \(providers.count) streaming providers: \(providers.map { $0["provider_name"] ?? "unknown" })")
            
            // Send to backend asynchronously (fire-and-forget)
            self.sendToBackend(providers: providers)
        }
    }
    
    func sendToBackend(providers: [[String: Any]]) {
        // Get Supabase URL and anon key from config
        let supabaseUrl = SupabaseConfig.supabaseURL
        let supabaseAnonKey = SupabaseConfig.supabaseAnonKey
        
        // Get current user ID if available (async)
        Task {
            var userId: String? = nil
            do {
                if let user = try await SupabaseService.shared.getCurrentUser() {
                    // SupabaseUser has id as UUID
                    userId = user.id.uuidString
                }
            } catch {
                print("⚠️ [GoogleWatchOn] Could not get user: \(error.localizedDescription)")
            }
            
            // Prepare request body
            let requestBody: [String: Any] = [
                "tmdb_id": self.tmdbId,
                "movie_title": self.movieTitle,
                "movie_year": self.movieYear as Any,
                "work_id": self.workId as Any,
                "providers": providers,
                "user_id": userId as Any
            ]
            
            guard let url = URL(string: "\(supabaseUrl)/functions/v1/capture-google-streaming"),
                  let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                print("⚠️ [GoogleWatchOn] Failed to create request")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.httpBody = jsonData
            
            // Send asynchronously (don't wait for response)
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("⚠️ [GoogleWatchOn] Error sending to backend: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("✅ [GoogleWatchOn] Successfully sent \(providers.count) providers to backend")
                    } else {
                        print("⚠️ [GoogleWatchOn] Backend returned status \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Preview

#Preview("Normal") {
    MoviePageView(movieId: 550)
}
