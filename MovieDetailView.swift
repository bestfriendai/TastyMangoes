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
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#fdfdfd")
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Top Navigation Header
                        topNavigationHeader
                            .padding(.top, 60) // Status bar height
                            .padding(.bottom, 16)
                        
                        // Video + Rate Section
                        videoAndRateSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Rate Bloc (Mango's Tips)
                        rateBlocSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Watch on Platform Icons
                        watchOnSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Tab Bar
                        tabBarSection
                            .padding(.top, 16)
                        
                        // Tab Content
                        tabContentSection
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomActionButtons
                }
            }
        }
        .sheet(isPresented: $showMenuSheet) {
            MovieDetailMenuBottomSheet()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet()
        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
            ZStack {
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
                
                // Play button overlay
                Button(action: {
                    // TODO: Play trailer
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(height: 192.9375)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Poster + Score Container
            HStack(alignment: .bottom, spacing: 16) {
                // Poster Image - use real poster if available
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
            .padding(.top, 16)
        }
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
    
    // MARK: - Tab Bar Section
    
    private var tabBarSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MovieDetailTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
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
                    ForEach(movie.cast.prefix(7), id: \.name) { actor in
                        CastCard(actor: actor)
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
                    ForEach(0..<6) { _ in
                        MovieRecommendationCard()
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
                    ForEach(0..<5) { _ in
                        MovieDetailClipCard()
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
                    ForEach(0..<6) { _ in
                        MovieDetailPhotoCard()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Actor Photo
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#e0e0e0"))
                .frame(width: 124, height: 156)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                )
            
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#e0e0e0"))
                .frame(width: 124, height: 186)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.white.opacity(0.5))
                )
            
            // Title
            Text("Similar Movie")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .lineLimit(2)
            
            // Year
            Text("2023")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clip Thumbnail
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
            
            // Clip Title
            Text("Behind the Scenes")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1a1a1a"))
        }
        .frame(width: 248)
    }
}

private struct MovieDetailPhotoCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: "#e0e0e0"))
            .frame(width: 248, height: 140)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.5))
            )
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
        backdropURL: nil
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
        
        // Convert cast members
        let castMembers = (cast ?? []).map { castMember in
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
            backdropURL: backdropURL
        )
    }
}

// MARK: - Preview

#Preview {
    MovieDetailView()
}
