//  SearchGenresBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
//  Notes: Built Genres filter bottom sheet with expandable sections, active filter badges, counts, Clear All, and Apply Filters

import SwiftUI

struct SearchGenresBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var filterState = SearchFilterState.shared
    
    @State private var expandedSections: Set<String> = ["Fun & Light"]
    @State private var selectedGenres: Set<String> = []
    
    // Genre groups with counts
    private let genreGroups: [(name: String, genres: [(name: String, count: Int)])] = [
        (
            name: "Fun & Light",
            genres: [
                ("Comedy", 120),
                ("Romance", 888),
                ("Musical", 420),
                ("Family", 140),
                ("Animation", 1000)
            ]
        ),
        (
            name: "Epic & Imaginative",
            genres: [
                ("Adventure", 120),
                ("Fantasy", 1000),
                ("Sci-Fi", 190),
                ("Historical", 130)
            ]
        ),
        (
            name: "Dark & Intense",
            genres: [
                ("Action", 120),
                ("Thriller", 888),
                ("Mystery", 420),
                ("Crime", 140),
                ("Horror", 140),
                ("War", 1000),
                ("Western", 640)
            ]
        ),
        (
            name: "Real Stories",
            genres: [
                ("Documentary", 120),
                ("Biography", 888),
                ("Sport", 420),
                ("Drama", 140)
            ]
        )
    ]
    
    var activeFilterCount: Int {
        selectedGenres.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#b3b3b3"))
                .frame(width: 32, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Header
            HStack {
                Text("Genres")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                Button(action: {
                    filterState.clearGenreFilters()
                    selectedGenres = []
                }) {
                    Text("Clear All")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(Color(hex: "#414141"))
                        .underline()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Active Filter Badges
            if !selectedGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedGenres), id: \.self) { genre in
                            ActiveFilterBadge(
                                title: genre,
                                onRemove: {
                                    selectedGenres.remove(genre)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(genreGroups, id: \.name) { group in
                        GenreGroupSection(
                            groupName: group.name,
                            genres: group.genres,
                            isExpanded: expandedSections.contains(group.name),
                            selectedGenres: $selectedGenres,
                            onToggleExpand: {
                                if expandedSections.contains(group.name) {
                                    expandedSections.remove(group.name)
                                } else {
                                    expandedSections.insert(group.name)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            // Bottom Button
            Divider()
                .background(Color(hex: "#f3f3f3"))
            
            Button(action: {
                // Apply filters
                filterState.selectedGenres = selectedGenres
                dismiss()
            }) {
                Text(activeFilterCount > 0 ? "Apply Filters (\(activeFilterCount))" : "Apply Filters")
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
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 24, topTrailing: 24)))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            // Load current selections
            selectedGenres = filterState.selectedGenres
        }
    }
}

// MARK: - Genre Group Section

struct GenreGroupSection: View {
    let groupName: String
    let genres: [(name: String, count: Int)]
    let isExpanded: Bool
    @Binding var selectedGenres: Set<String>
    let onToggleExpand: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggleExpand) {
                HStack {
                    Text(groupName)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Divider()
                .background(Color(hex: "#f3f3f3"))
            
            // Genre List
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(genres, id: \.name) { genre in
                        GenreListItem(
                            name: genre.name,
                            count: genre.count,
                            isSelected: selectedGenres.contains(genre.name),
                            onToggle: {
                                if selectedGenres.contains(genre.name) {
                                    selectedGenres.remove(genre.name)
                                } else {
                                    selectedGenres.insert(genre.name)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Genre List Item

struct GenreListItem: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Genre Name
                Text(name)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                // Count and Checkbox
                HStack(spacing: 12) {
                    Text(count >= 1000 ? "1000+" : "\(count)")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#808080"))
                    
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? Color(hex: "#FEA500") : Color(hex: "#B3B3B3"))
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Filter Badge

struct ActiveFilterBadge: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#333333"))
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#333333"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#ffedcc"))
        .cornerRadius(18)
    }
}

// MARK: - Preview

#Preview {
    SearchGenresBottomSheet(isPresented: .constant(true))
}

