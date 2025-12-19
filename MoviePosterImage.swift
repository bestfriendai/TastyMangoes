//
//  MoviePosterImage.swift
//  TastyMangoes
//
//  Created by Claude on 11/14/25 at 9:59 AM
//

import SwiftUI

/// Displays a movie poster image from TMDB with loading and error states
/// Includes retry logic for failed image loads
struct MoviePosterImage: View {
    let posterURL: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var retryCount = 0
    @State private var lastPosterURL: String?
    @State private var retryKey = UUID()
    
    private let maxRetries = 2
    
    init(
        posterURL: String?,
        width: CGFloat = 100,
        height: CGFloat = 150,
        cornerRadius: CGFloat = 8
    ) {
        self.posterURL = posterURL
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let posterPath = posterURL, !posterPath.isEmpty {
                // Check if it's already a full URL or just a path
                let baseImageURL: URL? = {
                    if posterPath.hasPrefix("http://") || posterPath.hasPrefix("https://") {
                        // Already a full URL
                        return URL(string: posterPath)
                    } else {
                        // Just a path, build full URL using TMDBConfig
                        return TMDBConfig.imageURL(path: posterPath, size: .poster_medium)
                    }
                }()
                
                if let baseURL = baseImageURL {
                    // Add cache-busting parameter on retry to avoid cached failures
                    let urlWithRetry: URL = {
                        if retryCount > 0 {
                            // Add cache-busting query parameter to force fresh load
                            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                            if components?.queryItems == nil {
                                components?.queryItems = []
                            }
                            components?.queryItems?.append(URLQueryItem(name: "_retry", value: "\(retryCount)"))
                            let retryURL = components?.url ?? baseURL
                            #if DEBUG
                            print("🖼️ [MoviePosterImage] Retry URL: \(retryURL.absoluteString)")
                            #endif
                            return retryURL
                        }
                        #if DEBUG
                        print("🖼️ [MoviePosterImage] Loading: \(baseURL.absoluteString)")
                        #endif
                        return baseURL
                    }()
                    
                    // Load image with retry support
                    // Use id modifier to force view recreation on retry
                    AsyncImage(url: urlWithRetry) { phase in
                        switch phase {
                        case .empty:
                            // Loading state
                            loadingView
                        case .success(let image):
                            // Successfully loaded
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(let error):
                            // Failed to load - attempt retry
                            retryView(baseURL: baseURL, error: error)
                        @unknown default:
                            retryView(baseURL: baseURL, error: nil)
                        }
                    }
                    .id(retryKey) // Force recreation on retry
                    .onChange(of: posterPath) { newPath in
                        // Reset retry count when URL changes (handles race conditions)
                        if lastPosterURL != newPath {
                            lastPosterURL = newPath
                            retryCount = 0
                            retryKey = UUID()
                        }
                    }
                    .onAppear {
                        // Track URL on appear to detect changes
                        if lastPosterURL != posterPath {
                            lastPosterURL = posterPath
                            retryCount = 0
                            retryKey = UUID()
                        }
                    }
                } else {
                    // Invalid URL
                    placeholderView
                }
            } else {
                // No URL provided
                placeholderView
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 240/255, green: 240/255, blue: 240/255))
        )
    }
    
    // MARK: - Retry Logic
    
    @ViewBuilder
    private func retryView(baseURL: URL, error: Error?) -> some View {
        Group {
            if retryCount < maxRetries {
                // Still retrying - show loading and trigger retry
                loadingView
                    .task {
                        // Trigger retry after a short delay
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        if retryCount < maxRetries {
                            retryCount += 1
                            retryKey = UUID() // Force view recreation with new URL
                            #if DEBUG
                            print("🖼️ [MoviePosterImage] Retry \(retryCount)/\(maxRetries) for: \(baseURL.absoluteString)")
                            if let error = error {
                                print("   Error: \(error.localizedDescription)")
                            }
                            #endif
                        }
                    }
            } else {
                // Max retries reached - show error
                errorView
            }
        }
    }
    
    // MARK: - State Views
    
    private var loadingView: some View {
        ZStack {
            Color(red: 240/255, green: 240/255, blue: 240/255)
            
            ProgressView()
                .tint(Color(red: 255/255, green: 165/255, blue: 0/255))
        }
    }
    
    private var errorView: some View {
        ZStack {
            Color(red: 240/255, green: 240/255, blue: 240/255)
            
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                
                Text("Failed")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Color(red: 240/255, green: 240/255, blue: 240/255)
            
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                
                Text("No Image")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
            }
        }
    }
}

// MARK: - Previews

#Preview("With URL") {
    MoviePosterImage(
        posterURL: "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        width: 120,
        height: 180
    )
}

#Preview("Loading") {
    MoviePosterImage(
        posterURL: "https://invalid-url.com/image.jpg",
        width: 120,
        height: 180
    )
}

#Preview("No Image") {
    MoviePosterImage(
        posterURL: nil,
        width: 120,
        height: 180
    )
}
