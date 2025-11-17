//  SearchFiltersBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:56 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 05:18 (America/Los_Angeles - Pacific Time)
//  Notes: Built comprehensive search filters bottom sheet with sort, scores, watched status, year, liked by, actors, and other filter options. Updated to work like WatchlistFiltersBottomSheet with detail sheets for each filter type. Fixed presentation detent to use .height(600) instead of .large for proper bottom sheet display.

import SwiftUI

struct SearchFiltersBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var filterState = SearchFilterState.shared
    
    @State private var selectedFilterType: FilterType? = nil
    
    enum FilterType: String, Identifiable {
        case sortBy = "Sort by"
        case platform = "Platform"
        case tastyScore = "Tasty Score"
        case aiScore = "AI Score"
        case genres = "Genres"
        case year = "Year"
        case likedBy = "Liked by"
        case actors = "Actors"
        
        var id: String { rawValue }
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
                    SearchFilterGroupRow(
                        title: "Sort by",
                        icon: nil,
                        onTap: { selectedFilterType = .sortBy }
                    )
                    SearchFilterGroupRow(
                        title: "Platform",
                        icon: nil,
                        onTap: { selectedFilterType = .platform }
                    )
                    SearchFilterGroupRow(
                        title: "Tasty Score",
                        icon: "mango",
                        onTap: { selectedFilterType = .tastyScore }
                    )
                    SearchFilterGroupRow(
                        title: "AI Score",
                        icon: "ai",
                        onTap: { selectedFilterType = .aiScore }
                    )
                    SearchFilterGroupRow(
                        title: "Genres",
                        icon: nil,
                        onTap: { selectedFilterType = .genres }
                    )
                    SearchFilterGroupRow(
                        title: "Year",
                        icon: nil,
                        onTap: { selectedFilterType = .year }
                    )
                    SearchFilterGroupRow(
                        title: "Liked by",
                        icon: nil,
                        onTap: { selectedFilterType = .likedBy }
                    )
                    SearchFilterGroupRow(
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
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedFilterType) { filterType in
            SearchFilterDetailSheet(filterType: filterType)
                .environmentObject(filterState)
        }
    }
}

// MARK: - Search Filter Group Row

struct SearchFilterGroupRow: View {
    let title: String
    let icon: String?
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
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
}

// MARK: - Preview

#Preview {
    SearchFiltersBottomSheet(isPresented: .constant(true))
}

