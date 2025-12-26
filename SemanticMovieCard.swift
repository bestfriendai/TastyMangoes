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
                if movie.status == .ready, let card = movie.card {
                    AsyncImage(url: URL(string: card.poster?.medium ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 80, height: 120)
                    .cornerRadius(8)
                } else {
                    // Loading shimmer
                    ShimmerView()
                        .frame(width: 80, height: 120)
                        .cornerRadius(8)
                }
                
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
                    
                    if movie.status == .ready, let card = movie.card {
                        HStack(spacing: 8) {
                            if let rating = card.aiScore {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.0f", rating / 10))
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
                    }
                    
                    // Match strength badge
                    matchStrengthBadge
                }
                
                Spacer()
            }
            
            // Mango's reason
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("🥭")
                        .font(.caption)
                    Text("Why Mango picked this:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                Text(movie.mangoReason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
            .padding(.top, 4)
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

