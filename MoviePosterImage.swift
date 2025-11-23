//
//  MoviePosterImage.swift
//  TastyMangoes
//
//  Created by Claude on 11/14/25 at 9:59 AM
//

import SwiftUI

/// Displays a movie poster image from TMDB with loading and error states
struct MoviePosterImage: View {
    let posterURL: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
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
                let imageURL: URL? = {
                    if posterPath.hasPrefix("http://") || posterPath.hasPrefix("https://") {
                        // Already a full URL
                        return URL(string: posterPath)
                    } else {
                        // Just a path, build full URL using TMDBConfig
                        return TMDBConfig.imageURL(path: posterPath, size: .poster_medium)
                    }
                }()
                
                if let url = imageURL {
                    // Load image from TMDB
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            // Loading state
                            loadingView
                        case .success(let image):
                            // Successfully loaded
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            // Failed to load
                            errorView
                        @unknown default:
                            errorView
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
