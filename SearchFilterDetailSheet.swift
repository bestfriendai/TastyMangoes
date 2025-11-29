//  SearchFilterDetailSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 05:18 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 05:25 (America/Los_Angeles - Pacific Time)
//  Notes: Created generic filter detail sheet for search filters with support for different filter types (Sort by, Platform, Scores, Genres, Year, Liked by, Actors). Similar to WatchlistFilterDetailSheet but uses SearchFilterState. Removed duplicate RangeSlider, YearRangeSlider, and YearInputField components - these are already defined in WatchlistFilterDetailSheet.swift and accessible from the same module.

import SwiftUI

struct SearchFilterDetailSheet: View {
    let filterType: SearchFiltersBottomSheet.FilterType
    var onApplyFilters: (() -> Void)? = nil // Callback to trigger search after applying filters
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var filterState: SearchFilterState
    
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
            
            // Header
            HStack {
                Text(filterType.rawValue)
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                Button(action: {
                    clearFilter()
                }) {
                    Text("Clear")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(Color(hex: "#414141"))
                        .underline()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Content
            ScrollView {
                filterContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            
            // Apply Button
            VStack(spacing: 0) {
                Divider()
                    .background(Color(hex: "#f3f3f3"))
                
                Button(action: {
                    print("🔘 [FILTER DETAIL] 'Apply' button tapped for \(filterType.rawValue)")
                    print("   Staged year range: \(filterState.stagedYearRange.lowerBound)-\(filterState.stagedYearRange.upperBound)")
                    print("   Applied year range BEFORE: \(filterState.appliedYearRange.lowerBound)-\(filterState.appliedYearRange.upperBound)")
                    
                    // Apply staged filters to applied filters
                    filterState.applyStagedFilters()
                    
                    print("   Applied year range AFTER: \(filterState.appliedYearRange.lowerBound)-\(filterState.appliedYearRange.upperBound)")
                    
                    // Trigger search callback if provided
                    onApplyFilters?()
                    
                    // Dismiss the detail sheet
                    dismiss()
                }) {
                    Text("Apply")
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
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.hidden)
    }
    
    @ViewBuilder
    private var filterContent: some View {
        switch filterType {
        case .sortBy:
            sortByContent
        case .platform:
            platformContent
        case .tastyScore:
            scoreContent(range: $filterState.tastyScoreRange, maxValue: 100)
        case .aiScore:
            scoreContent(range: $filterState.aiScoreRange, maxValue: 10)
        case .genres:
            genresContent
        case .year:
            yearContent
        case .likedBy:
            likedByContent
        case .actors:
            actorsContent
        }
    }
    
    // MARK: - Sort By Content
    
    private var sortByContent: some View {
        VStack(spacing: 0) {
            let options = ["List order", "Tasty Score", "AI Score", "Watched", "Year"]
            ForEach(options, id: \.self) { option in
                RadioButtonRow(
                    title: option,
                    isSelected: filterState.sortBy == option
                ) {
                    filterState.sortBy = option
                }
                
                if option != options.last {
                    Divider()
                        .background(Color(hex: "#f3f3f3"))
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Platform Content
    
    private var platformContent: some View {
        VStack(spacing: 0) {
            let platforms = ["Netflix", "Prime Video", "Disney+", "Max", "Apple TV+", "Hulu"]
            ForEach(platforms, id: \.self) { platform in
                CheckboxRow(
                    title: platform,
                    isSelected: filterState.selectedPlatforms.contains(platform)
                ) {
                    if filterState.selectedPlatforms.contains(platform) {
                        filterState.selectedPlatforms.remove(platform)
                    } else {
                        filterState.selectedPlatforms.insert(platform)
                    }
                }
                
                if platform != platforms.last {
                    Divider()
                        .background(Color(hex: "#f3f3f3"))
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Score Content (Range Slider)
    
    private func scoreContent(range: Binding<ClosedRange<Double>>, maxValue: Double) -> some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                    Text("\(Int(range.wrappedValue.lowerBound))")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .monospacedDigit()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("To")
                    Text("\(Int(range.wrappedValue.upperBound))")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .monospacedDigit()
                }
            }
            
            RangeSlider(
                range: range,
                bounds: 0...maxValue,
                step: maxValue == 100 ? 1.0 : 0.1
            )
        }
        .padding(.top, 16)
    }
    
    // MARK: - Genres Content
    
    private var genresContent: some View {
        VStack(spacing: 0) {
            let genres = ["Comedy", "Romance", "Musical", "Family", "Animation", "Adventure", "Fantasy", "Sci-Fi", "Historical", "Action", "Thriller", "Mystery", "Crime", "Horror", "War", "Western", "Documentary", "Biography", "Sport", "Drama"]
            ForEach(genres, id: \.self) { genre in
                CheckboxRow(
                    title: genre,
                    isSelected: filterState.selectedGenres.contains(genre)
                ) {
                    if filterState.selectedGenres.contains(genre) {
                        filterState.selectedGenres.remove(genre)
                    } else {
                        filterState.selectedGenres.insert(genre)
                    }
                }
                
                if genre != genres.last {
                    Divider()
                        .background(Color(hex: "#f3f3f3"))
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Year Content
    
    private var yearContent: some View {
        VStack(spacing: 20) {
            // Year Range Slider (at top)
            YearRangeSlider(
                range: $filterState.yearRange,
                bounds: 1925...2025
            )
            
            // Text Input Fields (below slider)
            HStack(spacing: 8) {
                // From Year Input
                YearInputField(
                    value: filterState.yearRange.lowerBound,
                    bounds: 1925...filterState.yearRange.upperBound,
                    onValueChanged: { newValue in
                        if newValue <= filterState.yearRange.upperBound {
                            filterState.yearRange = newValue...filterState.yearRange.upperBound
                        }
                    }
                )
                
                // Separator
                Text("-")
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 20)
                
                // To Year Input
                YearInputField(
                    value: filterState.yearRange.upperBound,
                    bounds: filterState.yearRange.lowerBound...2025,
                    onValueChanged: { newValue in
                        if newValue >= filterState.yearRange.lowerBound {
                            filterState.yearRange = filterState.yearRange.lowerBound...newValue
                        }
                    }
                )
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Liked By Content
    
    private var likedByContent: some View {
        VStack(spacing: 0) {
            let options = ["Any", "Friends", "Following", "Everyone"]
            ForEach(options, id: \.self) { option in
                RadioButtonRow(
                    title: option,
                    isSelected: filterState.likedBy == option
                ) {
                    filterState.likedBy = option
                }
                
                if option != options.last {
                    Divider()
                        .background(Color(hex: "#f3f3f3"))
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Actors Content
    
    private var actorsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Enter actor name...", text: $filterState.actors)
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#1a1a1a"))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(hex: "#f3f3f3"))
                .cornerRadius(8)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helper Methods
    
    private func clearFilter() {
        switch filterType {
        case .sortBy:
            filterState.sortBy = "List order"
        case .platform:
            filterState.selectedPlatforms.removeAll()
        case .tastyScore:
            filterState.tastyScoreRange = 0...100
        case .aiScore:
            filterState.aiScoreRange = 0...10
        case .genres:
            filterState.selectedGenres.removeAll()
        case .year:
            filterState.yearRange = 1925...2025
        case .likedBy:
            filterState.likedBy = "Any"
        case .actors:
            filterState.actors = ""
        }
    }
}

// MARK: - Radio Button Row

struct RadioButtonRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "#FEA500") : Color(hex: "#B3B3B3"), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#FEA500"))
                            .frame(width: 14, height: 14)
                    }
                }
                
                Text(title)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checkbox Row

struct CheckboxRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(hex: "#FEA500") : Color(hex: "#B3B3B3"))
                
                Text(title)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SearchFilterDetailSheet(filterType: .sortBy)
        .environmentObject(SearchFilterState.shared)
}

