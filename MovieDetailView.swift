//  MovieDetailView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-22 at 20:30 (America/Los_Angeles - Pacific Time)
//  Notes: Complete Movie Detail view matching Figma design exactly - includes header, trailer, scores, tabs, overview, cast & crew, reviews, more to watch, clips, photos, and bottom action buttons

import SwiftUI

// MARK: - Movie Detail View

struct MovieDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MovieDetailViewModel
    @State private var selectedTab: MovieDetailTab = .overview
    @State private var showMenuSheet = false
    @State private var showShareSheet = false
    @State private var sectionTabsMinY: CGFloat = 1000 // Track section tabs position
    @State private var initialSectionTabsMinY: CGFloat = 1000 // Track initial position
    @State private var hasReachedPinningPoint: Bool = false // Track if we've scrolled past pinning threshold
    @State private var scrollProxy: ScrollViewProxy?
    
    // Simple cast member struct for display (to avoid conflict with Codable CastMember)
    struct SimpleCastMember: Identifiable {
        let id = UUID()
        let name: String
        let character: String
    }
    
    // Computed property to convert MovieDetail to MovieDetailInfo
    private var movie: MovieDetailInfo {
        guard let movieDetail = viewModel.movie else {
            // Fallback to dummy data if no movie loaded
            return MovieDetailData.juror2
        }
        
        return movieDetail.toMovieDetailInfo()
    }
    
    
    // Initializer for Movie model - fetches from TMDB
    init(movie: Movie) {
        // Try to convert string ID to Int for TMDB API
        // If it's a numeric string (like "550"), use it as Int ID
        // Otherwise, use string ID (MovieDetailViewModel supports both)
        if let intId = Int(movie.id) {
            // Use Int ID for TMDB API
            _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieId: intId))
        } else {
            // Use string ID - MovieDetailService will try to fetch from TMDB if possible
            // or fall back to JSON/local data
            _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieStringId: movie.id))
        }
    }
    
    // Initializer for MovieDetailInfo (for dummy data or direct use)
    init(movie: MovieDetailInfo = MovieDetailData.juror2) {
        // For dummy data, use a default ID
        _viewModel = StateObject(wrappedValue: MovieDetailViewModel(movieId: 0))
    }
    
    // Computed property to determine if pinned section tabs should show
    private var shouldShowPinnedSectionTabs: Bool {
        // Once we've reached the pinning point, keep it pinned
        // This ensures the section tabs stay pinned even if sectionTabsMinY goes negative
        return hasReachedPinningPoint
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#fdfdfd")
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else {
                VStack(spacing: 0) {
                    // Header - FIXED at top, never scrolls
                    topNavigationHeader
                        .padding(.top) // Account for safe area (status bar)
                        .padding(.bottom, 16)
                        .background(Color.white)
                        .zIndex(100)
                    
                    // Pinned Section Tabs - shows when scrollable section tabs reach top
                    if shouldShowPinnedSectionTabs {
                        sectionTabsBar
                            .background(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            .zIndex(99)
                    }
                    
                    // Scrollable content - starts below header
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Video + Rate Section
                                videoAndRateSection
                                    .padding(.horizontal, 16)
                                    .padding(.top, 0)
                                
                                // Rate Bloc (Mango's Tips)
                                rateBlocSection
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                
                                // Watch on Platform Icons
                                watchOnSection
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                
                                // Section Tabs Bar (scrollable, will be hidden when pinned)
                                sectionTabsBar
                                    .padding(.top, 16)
                                    .background(
                                        GeometryReader { geometry in
                                            let frame = geometry.frame(in: .named("scroll"))
                                            Color.clear.preference(
                                                key: TabBarPositionKey.self,
                                                value: frame.minY
                                            )
                                        }
                                    )
                                    .opacity(shouldShowPinnedSectionTabs ? 0 : 1)
                                    .id("scrollableSectionTabs")
                                
                                // All Sections Stacked Vertically
                                VStack(spacing: 0) {
                                    // Overview Section
                                    overviewSection
                                        .id(MovieDetailTab.overview.id)
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
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                    
                                    // Cast & Crew Section
                                    castCrewSection
                                        .id(MovieDetailTab.castCrew.id)
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
                                        .padding(.horizontal, 16)
                                        .padding(.top, 32)
                                    
                                    // Reviews Section
                                    reviewsSection
                                        .id(MovieDetailTab.reviews.id)
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
                                        .padding(.horizontal, 16)
                                        .padding(.top, 32)
                                    
                                    // More to Watch Section
                                    moreToWatchSection
                                        .id(MovieDetailTab.moreToWatch.id)
                                        .background(
                                            GeometryReader { geometry in
                                                let frame = geometry.frame(in: .named("scroll"))
                                                Color.clear.preference(
                                                    key: SectionVisibilityPreferenceKey.self,
                                                    value: [SectionVisibility(
                                                        section: .moreToWatch,
                                                        minY: frame.minY,
                                                        maxY: frame.maxY
                                                    )]
                                                )
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.top, 32)
                                    
                                    // Movie Clips Section
                                    movieClipsSection
                                        .id(MovieDetailTab.clips.id)
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
                                        .padding(.horizontal, 16)
                                        .padding(.top, 32)
                                    
                                    // Photos Section
                                    photosSection
                                        .id(MovieDetailTab.photos.id)
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
                                        .padding(.horizontal, 16)
                                        .padding(.top, 32)
                                        .padding(.bottom, 100) // Extra padding for bottom buttons
                                }
                            }
                        }
                        .coordinateSpace(name: "scroll")
                        .scrollIndicators(.hidden) // Hide scroll indicators for cleaner look
                        .onPreferenceChange(TabBarPositionKey.self) { value in
                            sectionTabsMinY = value
                            
                            // Track initial position on first update
                            if initialSectionTabsMinY == 1000 && value > 0 {
                                initialSectionTabsMinY = value
                            }
                            
                            // frame.minY is relative to ScrollView content
                            // As we scroll up, value decreases from initial position
                            // When section tabs reach top of visible ScrollView area (below header),
                            // value should be around 0 or negative
                            // Pin when value is close to 0 (scrolled up to top)
                            // Only pin if we've scrolled up significantly from initial position
                            let scrollDistance = initialSectionTabsMinY - value
                            
                            if value <= 0 && scrollDistance > 200 {
                                // Section tabs have scrolled up to the top
                                hasReachedPinningPoint = true
                            } else if value > 50 || scrollDistance < 100 {
                                // Scrolled back down or haven't scrolled enough, unpin
                                hasReachedPinningPoint = false
                            }
                        }
                        .onPreferenceChange(SectionVisibilityPreferenceKey.self) { values in
                            // Update selected tab based on scroll position
                            // Section tabs offset accounts for safe area (~52), header (~80), and section tabs height (~52) = ~184
                            // But since section tabs are now pinned, we need to account for header + section tabs
                            let headerHeight: CGFloat = 80 // Approximate header height
                            let sectionTabsHeight: CGFloat = 52 // Section tabs height
                            let sectionTabsOffset: CGFloat = headerHeight + sectionTabsHeight
                            
                            let visibleSections = values.filter { visibility in
                                // Section is visible if it's in the top portion of the visible area (below pinned section tabs)
                                return visibility.minY <= sectionTabsOffset && visibility.maxY > sectionTabsOffset
                            }
                            
                            if let firstVisible = visibleSections.min(by: { $0.minY < $1.minY }) {
                                if selectedTab != firstVisible.section {
                                    selectedTab = firstVisible.section
                                }
                            }
                        }
                        .onAppear {
                            scrollProxy = proxy
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomActionButtons
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showMenuSheet) {
            MovieDetailMenuBottomSheet()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet()
        }
        .navigationBarBackButtonHidden(true) // Hide default NavigationStack back button
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true) // Hide navigation bar completely
        .task {
            // Load movie data from TMDB when view appears
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
                .foregroundColor(Color(hex: "#1a1a1a"))
            
            Text(viewModel.errorMessage)
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                viewModel.retry()
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
        .background(Color(hex: "#fdfdfd"))
    }
    
    // MARK: - Top Navigation Header
    
    private var topNavigationHeader: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16.667, weight: .medium))
                    .foregroundColor(Color(hex: "#333333"))
                    .frame(width: 28, height: 28)
                    .background(Color.clear)
                    .cornerRadius(8)
            }
            
            // General Info
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // Extract year from releaseDate or use first 4 characters
                    let year = movie.releaseDate.prefix(4).isEmpty ? "2024" : String(movie.releaseDate.prefix(4))
                    Text(year)
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("‧")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text(movie.genres.joined(separator: "/"))
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("‧")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text(movie.runtime)
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                // Share Button
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16.667, weight: .medium))
                        .foregroundColor(Color(hex: "#000000"))
                        .frame(width: 28, height: 28)
                        .background(Color.clear)
                        .cornerRadius(8)
                }
                
                // Menu Button
                Button(action: {
                    showMenuSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16.667, weight: .medium))
                        .foregroundColor(Color(hex: "#333333"))
                        .frame(width: 28, height: 28)
                        .background(Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16) // Matches Figma px-[16px]
        .frame(height: 40) // Content height (matches Figma General Info height)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#f3f3f3")),
            alignment: .bottom
        )
    }
    
    // MARK: - Video + Rate Section
    
    private var videoAndRateSection: some View {
        VStack(spacing: 0) {
            // Video Player Area - use backdrop image if available
            ZStack(alignment: .topLeading) {
                if let backdropURL = movie.backdropURL {
                    AsyncImage(url: backdropURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#e0e0e0"))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#e0e0e0"))
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#e0e0e0"))
                        }
                    }
                } else {
                    // Placeholder for video/poster
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#e0e0e0"))
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
                
                // Play Trailer overlay (top-left)
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#f3f3f3"))
                    
                    HStack(spacing: 4) {
                        Text("Play Trailer")
                            .font(.custom("Nunito-Bold", size: 12))
                            .foregroundColor(Color(hex: "#f3f3f3"))
                        
                        if let duration = movie.trailerDuration {
                            Text(formatDuration(duration))
                                .font(.custom("Inter-Regular", size: 12))
                                .foregroundColor(Color(hex: "#ececec"))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .padding(.top, 12)
                .padding(.leading, 12)
            }
            .frame(height: 192.9375)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Poster + Score Container - overlaps video by ~58px (1/3)
            HStack(alignment: .bottom, spacing: 16) {
                // Poster Image - overlaps video by positioning it with negative margin
                if let posterURL = movie.posterURL {
                    AsyncImage(url: posterURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#d0d0d0"))
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#d0d0d0"))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.5))
                                )
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#d0d0d0"))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.5))
                                )
                        }
                    }
                    .frame(width: 84, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Placeholder if no poster
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#d0d0d0"))
                        .frame(width: 84, height: 124)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // Score Cards
                HStack(spacing: 16) {
                    // Tasty Score Card
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            HStack(spacing: 2) {
                                MangoLogoIcon(size: 16.667, color: Color(hex: "#648d00"))
                                Text("Tasty Score")
                                    .font(.custom("Inter-Regular", size: 12))
                                    .foregroundColor(Color(hex: "#666666"))
                            }
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                        Text("\(movie.tastyScore)%")
                            .font(.custom("Nunito-Bold", size: 20))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                    }
                    .frame(width: 108, height: 50)
                    
                    // Divider
                    Rectangle()
                        .fill(Color(hex: "#ececec"))
                        .frame(width: 1, height: 40)
                    
                    // AI Score Card
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            HStack(spacing: 2) {
                                AIFilledIcon(size: 20)
                                Text("AI Score")
                                    .font(.custom("Inter-Regular", size: 12))
                                    .foregroundColor(Color(hex: "#666666"))
                            }
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                        Text(String(format: "%.1f", movie.aiScore))
                            .font(.custom("Nunito-Bold", size: 20))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                    }
                    .frame(width: 88, height: 50)
                }
            }
            .padding(.leading, 12) // Match Figma: poster has 12px left padding
            .padding(.top, -58) // Overlap video by 58px (1/3 of 192.9375)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Rate Bloc Section (Mango's Tips)
    
    private var rateBlocSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge
            HStack(spacing: 4) {
                Text("Mango's Tips")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#ffedcc"))
                    .cornerRadius(999)
            }
            
            // Recommendation Text
            Text("This thriller delivers intense courtroom drama with compelling performances. Perfect for fans of legal suspense and character-driven narratives.")
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Watch On Section
    
    private var watchOnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watch on")
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#999999"))
            
            HStack(spacing: 12) {
                // Prime Video
                MovieDetailPlatformLogo(platform: "Prime Video")
                    .frame(width: 60, height: 60)
                
                // Netflix
                MovieDetailPlatformLogo(platform: "Netflix")
                    .frame(width: 60, height: 60)
                
                // Apple TV+
                MovieDetailPlatformLogo(platform: "Apple TV+")
                    .frame(width: 60, height: 60)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Section Tabs Bar
    
    private var sectionTabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MovieDetailTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                        // Scroll to section when tab is tapped
                        if let proxy = scrollProxy {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(tab.id, anchor: .top)
                            }
                        }
                    }) {
                        VStack(spacing: 0) {
                            Text(tab.rawValue)
                                .font(.custom("Nunito-SemiBold", size: 14))
                                .foregroundColor(selectedTab == tab ? Color(hex: "#1a1a1a") : Color(hex: "#666666"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            
                            // Underline indicator
                            Rectangle()
                                .fill(selectedTab == tab ? Color(hex: "#fea500") : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#f3f3f3")),
            alignment: .bottom
        )
    }
    
    // MARK: - Tab Content Section
    
    @ViewBuilder
    private var tabContentSection: some View {
        switch selectedTab {
        case .overview:
            overviewSection
        case .castCrew:
            castCrewSection
        case .reviews:
            reviewsSection
        case .moreToWatch:
            moreToWatchSection
        case .clips:
            movieClipsSection
        case .photos:
            photosSection
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Synopsis
            Text(movie.overview)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineSpacing(4)
            
            // Genre Badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(movie.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#f3f3f3"))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Details Table
            VStack(spacing: 0) {
                DetailRow(label: "Runtime", value: movie.runtime)
                DetailRow(label: "Release Date", value: movie.releaseDate)
                DetailRow(label: "Director", value: movie.director)
                DetailRow(label: "Rating", value: movie.rating)
            }
            
            // Read More Button
            Button(action: {
                // TODO: Expand overview
            }) {
                Text("Read more")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#fea500"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Cast & Crew Section
    
    private var castCrewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Cast & Crew")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                Spacer()
            }
            
            // Cast Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let castMembers = viewModel.movie?.cast {
                        ForEach(Array(castMembers.prefix(7).enumerated()), id: \.element.id) { index, castMember in
                            CastCard(
                                actor: MovieDetailView.SimpleCastMember(
                                    name: castMember.name,
                                    character: castMember.character
                                ),
                                profileURL: castMember.profileURL
                            )
                        }
                    } else {
                        // Fallback to movie.cast if viewModel doesn't have cast
                        ForEach(movie.cast.prefix(7), id: \.name) { actor in
                            CastCard(actor: actor)
                        }
                    }
                }
            }
            
            // Crew Details Table
            VStack(spacing: 0) {
                DetailRow(label: "Director", value: movie.director)
                DetailRow(label: "Writer", value: movie.writer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Reviews Section
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Reviews")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                Spacer()
            }
            
            // Review Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ReviewTabButton(title: "Top", isSelected: true)
                    ReviewTabButton(title: "Friends", isSelected: false)
                    ReviewTabButton(title: "Relevant Critics", isSelected: false)
                }
            }
            
            // Review Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { _ in
                        MovieDetailReviewCard()
                    }
                }
            }
            
            // View All Reviews Button
            Button(action: {
                // TODO: Show all reviews
            }) {
                Text("View all reviews")
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#fea500"))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - More to Watch Section
    
    private var moreToWatchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("More to Watch")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                Spacer()
            }
            
            // Movie Recommendations Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !viewModel.similarMovies.isEmpty {
                        ForEach(viewModel.similarMovies) { similarMovie in
                            MovieRecommendationCard(movie: similarMovie)
                        }
                    } else {
                        // Fallback placeholder
                        ForEach(0..<6) { _ in
                            MovieRecommendationCard()
                        }
                    }
                }
            }
            
            // Mango's Recommendation Card
            MangoRecommendationCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Movie Clips Section
    
    private var movieClipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Movie Clips")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                Spacer()
            }
            
            // Clips Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !viewModel.movieVideos.isEmpty {
                        ForEach(viewModel.movieVideos) { video in
                            MovieDetailClipCard(video: video)
                        }
                    } else {
                        // Fallback placeholder
                        ForEach(0..<5) { _ in
                            MovieDetailClipCard()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Photos")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                Spacer()
            }
            
            // Photos Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !viewModel.movieImages.isEmpty {
                        ForEach(viewModel.movieImages.prefix(6)) { image in
                            MovieDetailPhotoCard(image: image)
                        }
                    } else {
                        // Fallback placeholder
                        ForEach(0..<6) { _ in
                            MovieDetailPhotoCard()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
    
    // MARK: - Bottom Action Buttons
    
    private var bottomActionButtons: some View {
        HStack(spacing: 12) {
            // Mark as Watched Button
            Button(action: {
                // TODO: Mark as watched
            }) {
                Text("Mark as Watched")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#fea500"))
                    .cornerRadius(8)
            }
            
            // Add to Watchlist Button
            Button(action: {
                // TODO: Add to watchlist
            }) {
                Text("Add to Watchlist")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#ececec"), lineWidth: 1)
                    )
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#f3f3f3")),
            alignment: .top
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Supporting Types

enum MovieDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case castCrew = "Cast & Crew"
    case reviews = "Reviews"
    case moreToWatch = "More to Watch"
    case clips = "Movie Clips"
    case photos = "Photos"
    
    var id: String { rawValue }
}

// MARK: - Supporting Components

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#666666"))
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#f3f3f3")),
            alignment: .bottom
        )
    }
}

struct CastCard: View {
    let actor: MovieDetailView.SimpleCastMember
    let profileURL: URL?
    
    init(actor: MovieDetailView.SimpleCastMember, profileURL: URL? = nil) {
        self.actor = actor
        self.profileURL = profileURL
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Actor Photo
            if let profileURL = profileURL {
                AsyncImage(url: profileURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#e0e0e0"))
                            .frame(width: 124, height: 156)
                            .overlay(
                                ProgressView()
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 124, height: 156)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#e0e0e0"))
                            .frame(width: 124, height: 156)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#e0e0e0"))
                    .frame(width: 124, height: 156)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            // Actor Name
            Text(actor.name)
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(1)
            
            // Character Name
            Text(actor.character)
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
                .lineLimit(1)
        }
        .frame(width: 124)
    }
}

struct ReviewTabButton: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Button(action: {}) {
            Text(title)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(isSelected ? Color(hex: "#1a1a1a") : Color(hex: "#666666"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "#ffedcc") : Color(hex: "#f3f3f3"))
                .cornerRadius(8)
        }
    }
}

private struct MovieDetailReviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Reviewer Info
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "#e0e0e0"))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("John Doe")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    Text("2 days ago")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
            }
            
            // Review Text
            Text("Great movie! The performances were outstanding and the plot kept me engaged throughout.")
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(4)
        }
        .padding(16)
        .frame(width: 264)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct MovieRecommendationCard: View {
    let movie: Movie?
    
    init(movie: Movie? = nil) {
        self.movie = movie
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            if let movie = movie {
                MoviePosterImage(posterURL: movie.posterImageURL)
                    .frame(width: 124, height: 186)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#e0e0e0"))
                    .frame(width: 124, height: 186)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            // Title
            Text(movie?.title ?? "Similar Movie")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(2)
            
            // Year
            Text(movie?.year != nil && movie!.year > 0 ? String(movie!.year) : "2023")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
        }
        .frame(width: 124)
    }
}

struct MangoRecommendationCard: View {
    var body: some View {
        VStack(spacing: 16) {
            // Mango Avatar Section
            ZStack {
                Circle()
                    .fill(Color(hex: "#ffedcc"))
                    .frame(width: 56, height: 56)
                
                MangoLogoIcon(size: 40, color: Color(hex: "#648d00"))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text("Mango Recommends")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                HStack(spacing: 4) {
                    Text("Based on your")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("watch history")
                        .font(.custom("Inter-SemiBold", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Text("If you enjoyed this film, you'll love our curated selection of similar thrillers and dramas.")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .lineSpacing(4)
            }
            .padding(.horizontal, 16)
            
            // Button
            Button(action: {}) {
                Text("Explore Recommendations")
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#fea500"))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
    }
}

private struct MovieDetailClipCard: View {
    let video: TMDBVideo?
    
    init(video: TMDBVideo? = nil) {
        self.video = video
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clip Thumbnail
            if let video = video, let thumbnailURL = video.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#e0e0e0"))
                            .frame(width: 248, height: 140)
                            .overlay(ProgressView())
                    case .success(let image):
                        ZStack {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 248, height: 140)
                                .clipped()
                                .cornerRadius(8)
                            
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#e0e0e0"))
                            .frame(width: 248, height: 140)
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.9))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#e0e0e0"))
                    .frame(width: 248, height: 140)
                    .overlay(
                        ZStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    )
            }
            
            // Clip Title
            Text(video?.name ?? "Behind the Scenes")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(2)
        }
        .frame(width: 248)
    }
}

private struct MovieDetailPhotoCard: View {
    let image: TMDBImage?
    
    init(image: TMDBImage? = nil) {
        self.image = image
    }
    
    var body: some View {
        if let image = image, let imageURL = image.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#e0e0e0"))
                        .frame(width: 248, height: 140)
                        .overlay(ProgressView())
                case .success(let img):
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 248, height: 140)
                        .clipped()
                        .cornerRadius(8)
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#e0e0e0"))
                        .frame(width: 248, height: 140)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.5))
                        )
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#e0e0e0"))
                .frame(width: 248, height: 140)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.white.opacity(0.5))
                )
        }
    }
}

private struct MovieDetailMenuBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "#b3b3b3"))
                .frame(width: 32, height: 4)
                .padding(.top, 12)
            
            VStack(spacing: 0) {
                MovieDetailMenuItem(title: "Add to List", icon: "list.bullet")
                MovieDetailMenuItem(title: "Share", icon: "square.and.arrow.up")
                MovieDetailMenuItem(title: "Report Issue", icon: "exclamationmark.triangle", isDestructive: true)
            }
            .padding(.top, 24)
        }
        .background(Color.white)
        .presentationDetents([.height(250)])
    }
}

private struct MovieDetailMenuItem: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? Color.red : Color(hex: "#333333"))
                    .frame(width: 24)
                
                Text(title)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(isDestructive ? Color.red : Color(hex: "#1a1a1a"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

struct ShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Share Movie")
                .font(.custom("Nunito-Bold", size: 20))
                .padding()
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Scroll Position Tracking

fileprivate struct SectionVisibility: Equatable {
    let section: MovieDetailTab
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

// MARK: - Platform Logo Component (for MovieDetailView only)

private struct MovieDetailPlatformLogo: View {
    let platform: String
    
    var body: some View {
        Group {
            switch platform {
            case "Netflix":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E50914"))
                    Text("N")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Prime Video":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#00A8E1"))
                    Text("P")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Apple TV+":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    VStack(spacing: 2) {
                        Text("tv")
                            .font(.custom("Nunito-Bold", size: 18))
                            .foregroundColor(.white)
                        Text("+")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.white)
                    }
                }
            default:
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E0E0E0"))
                    Text(platform.prefix(1))
                        .font(.custom("Nunito-Bold", size: 24))
                        .foregroundColor(Color(hex: "#333333"))
                }
            }
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Dummy Data

struct MovieDetailData {
    static let juror2 = MovieDetailInfo(
        title: "Juror #2",
        overview: "A juror finds himself in a moral dilemma during a murder trial. As the case unfolds, he must confront his own past while deciding the fate of the defendant. This intense courtroom drama explores themes of justice, redemption, and the weight of personal responsibility.",
        genres: ["Thriller", "Drama", "Crime", "Mystery"],
        runtime: "1h 54min",
        releaseDate: "June 14, 2024",
        director: "Clint Eastwood",
        rating: "R",
        writer: "Jonathan Abrams",
        cast: [
            MovieDetailView.SimpleCastMember(name: "Nicholas Hoult", character: "Justin Kemp"),
            MovieDetailView.SimpleCastMember(name: "Toni Collette", character: "Grace Kennedy"),
            MovieDetailView.SimpleCastMember(name: "Zoey Deutch", character: "Kate"),
            MovieDetailView.SimpleCastMember(name: "Gabriel Basso", character: "Blake"),
            MovieDetailView.SimpleCastMember(name: "Kiefer Sutherland", character: "Prosecutor"),
            MovieDetailView.SimpleCastMember(name: "Leslie Bibb", character: "Defense Attorney"),
            MovieDetailView.SimpleCastMember(name: "Chris Messina", character: "Judge")
        ],
        tastyScore: 64,
        aiScore: 5.9,
        posterURL: nil,
        backdropURL: nil,
        trailerDuration: 260 // 4:20 in seconds
    )
}

struct MovieDetailInfo {
    let title: String
    let overview: String
    let genres: [String]
    let runtime: String
    let releaseDate: String
    let director: String
    let rating: String
    let writer: String
    let cast: [MovieDetailView.SimpleCastMember]
    let tastyScore: Int
    let aiScore: Double
    let posterURL: URL?
    let backdropURL: URL?
    let trailerDuration: Int? // Duration in seconds
}

// MARK: - MovieDetail Extension for Conversion

extension MovieDetail {
    /// Convert MovieDetail (from TMDB) to MovieDetailInfo (for display)
    func toMovieDetailInfo() -> MovieDetailInfo {
        // Convert genres from Genre objects to strings
        let genreStrings = genres.map { $0.name }
        
        // Format runtime
        let runtimeString = formattedRuntime
        
        // Format release date (use full date or just year)
        let releaseDateString = releaseDate.isEmpty ? releaseYear : releaseDate
        
        // Get director
        let directorName = director ?? "N/A"
        
        // Get rating
        let ratingString = rating ?? "N/A"
        
        // Get writers from crew
        let writers = crew?.filter { $0.job == "Writer" || $0.job == "Screenplay" } ?? []
        let writerNames = writers.isEmpty ? "N/A" : writers.map { $0.name }.joined(separator: ", ")
        
        // Convert cast members - use first 7 for display
        let castMembers = (cast ?? []).prefix(7).map { castMember in
            MovieDetailView.SimpleCastMember(
                name: castMember.name,
                character: castMember.character
            )
        }
        
        // Convert tastyScore (0-1 range) to percentage (0-100)
        let tastyScorePercent: Int
        if let tastyScore = tastyScore {
            tastyScorePercent = tastyScore > 1 ? Int(tastyScore) : Int(tastyScore * 100)
        } else {
            // Default to 0 if no tasty score
            tastyScorePercent = 0
        }
        
        // Use AI score or vote average as fallback
        let aiScoreValue = aiScore ?? voteAverage ?? 0.0
        
        return MovieDetailInfo(
            title: title,
            overview: overview.isEmpty ? "No overview available." : overview,
            genres: genreStrings,
            runtime: runtimeString,
            releaseDate: releaseDateString,
            director: directorName,
            rating: ratingString,
            writer: writerNames,
            cast: castMembers,
            tastyScore: tastyScorePercent,
            aiScore: aiScoreValue,
            posterURL: posterURL,
            backdropURL: backdropURL,
            trailerDuration: trailerDuration
        )
    }
}

// MARK: - Preview

#Preview {
    MovieDetailView()
}
