//  WatchlistFiltersBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:38 (America/Los_Angeles - Pacific Time)
//  Notes: Created Filters bottom sheet for watchlist with Sort by, Platform, Tasty Score, AI Score, Genres, Year, Liked by, and Actors filter groups matching Figma design. Renamed FilterGroupRow to WatchlistFilterGroupRow to avoid naming conflict. Added filter detail sheet functionality for all filter types.

import SwiftUI

struct WatchlistFiltersBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var filterState = WatchlistFilterState.shared
    
    @State private var selectedFilterType: FilterType? = nil
    
    enum FilterType: String {
        case sortBy = "Sort by"
        case platform = "Platform"
        case tastyScore = "Tasty Score"
        case aiScore = "AI Score"
        case genres = "Genres"
        case year = "Year"
        case likedBy = "Liked by"
        case actors = "Actors"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#b3b3b3"))
                    .frame(width: 32, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            
            // Title
            HStack {
                Text("Filters")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Filter Groups
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    WatchlistFilterGroupRow(
                        title: "Sort by",
                        icon: nil,
                        onTap: { selectedFilterType = .sortBy }
                    )
                    WatchlistFilterGroupRow(
                        title: "Platform",
                        icon: nil,
                        onTap: { selectedFilterType = .platform }
                    )
                    WatchlistFilterGroupRow(
                        title: "Tasty Score",
                        icon: "mango",
                        onTap: { selectedFilterType = .tastyScore }
                    )
                    WatchlistFilterGroupRow(
                        title: "AI Score",
                        icon: "ai",
                        onTap: { selectedFilterType = .aiScore }
                    )
                    WatchlistFilterGroupRow(
                        title: "Genres",
                        icon: nil,
                        onTap: { selectedFilterType = .genres }
                    )
                    WatchlistFilterGroupRow(
                        title: "Year",
                        icon: nil,
                        onTap: { selectedFilterType = .year }
                    )
                    WatchlistFilterGroupRow(
                        title: "Liked by",
                        icon: nil,
                        onTap: { selectedFilterType = .likedBy }
                    )
                    WatchlistFilterGroupRow(
                        title: "Actors",
                        icon: nil,
                        onTap: { selectedFilterType = .actors }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            // Close Button
            VStack(spacing: 0) {
                Divider()
                    .background(Color(hex: "#f3f3f3"))
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Close")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#333333"))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedFilterType) { filterType in
            WatchlistFilterDetailSheet(filterType: filterType)
                .environmentObject(filterState)
        }
    }
}

extension WatchlistFiltersBottomSheet.FilterType: Identifiable {
    var id: String { rawValue }
}

// MARK: - Watchlist Filter Group Row

struct WatchlistFilterGroupRow: View {
    let title: String
    let icon: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon (if provided)
                if let icon = icon {
                    if icon == "mango" {
                        // Mango icon placeholder
                        Image(systemName: "star.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#648d00"))
                            .frame(width: 24, height: 24)
                    } else if icon == "ai" {
                        // AI icon placeholder
                        Image(systemName: "star.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#FEA500"))
                            .frame(width: 24, height: 24)
                    }
                }
                
                // Title
                HStack(spacing: 4) {
                    Text(title)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    if title == "Tasty Score" || title == "AI Score" {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#333333"))
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.down")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#333333"))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        
        Divider()
            .background(Color(hex: "#f3f3f3"))
    }
}

// MARK: - Preview

#Preview {
    WatchlistFiltersBottomSheet(isPresented: .constant(true))
}

