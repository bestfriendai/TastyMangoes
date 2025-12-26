//  SemanticMovieCard.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Card component for displaying semantic search movie results

import SwiftUI

struct SemanticMovieCard: View {
    let movie: SemanticMovie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: Poster + Title/Info
            HStack(alignment: .top, spacing: 12) {
                // Poster
                Group {
                    if movie.status == .ready, let card = movie.card {
                        // Ready card - use card poster
                        AsyncImage(url: URL(string: card.poster?.medium ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    } else if let posterPath = movie.preview?.posterPath {
                        // Loading card - use TMDB poster from preview
                        let posterUrl = posterPath.starts(with: "http") 
                            ? posterPath 
                            : "https://image.tmdb.org/t/p/w342\(posterPath)"
                        AsyncImage(url: URL(string: posterUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                        } placeholder: {
                            ShimmerView()
                        }
                    } else {
                        // No poster available - show shimmer
                        ShimmerView()
                    }
                }
                .frame(width: 80, height: 120)
                .cornerRadius(8)
                
                // Title and metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let year = movie.displayYear {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show scores and metadata for both ready and loading movies
                    if movie.status == .ready, let card = movie.card {
                        // Ready movie - use card data
                        HStack(spacing: 8) {
                            if let rating = card.aiScore {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", rating / 10))
                                        .font(.caption)
                                }
                            }
                            
                            if let runtime = card.runtimeDisplay {
                                Text(runtime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let cert = card.certification {
                                Text(cert)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Genres
                        if let genres = card.genres {
                            Text(genres.prefix(3).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let preview = movie.preview {
                        // Loading movie - show TMDB score if available
                        HStack(spacing: 8) {
                            if let rating = preview.voteAverage, rating > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    // Match strength badge
                    matchStrengthBadge
                }
                
                Spacer()
            }
            
            // Mango's reason - Always show, even for loading movies
            if !movie.mangoReason.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("🥭")
                            .font(.caption)
                        Text("Why Mango picked this:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    
                    Text(movie.mangoReason)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(nil)  // Show full reason, no truncation
                        .fixedSize(horizontal: false, vertical: true)  // Allow text wrapping
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var matchStrengthBadge: some View {
        let (text, color) = matchStrengthInfo
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
    
    private var matchStrengthInfo: (String, Color) {
        switch movie.matchStrength {
        case .strong:
            return ("Strong match", .green)
        case .good:
            return ("Good fit", .blue)
        case .worthConsidering:
            return ("Worth considering", .orange)
        }
    }
}

// Shimmer effect for loading cards
struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .white, .clear]),
                            startPoint: .init(x: phase - 1, y: 0),
                            endPoint: .init(x: phase, y: 0)
                        )
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

