//  WatchlistFilterDetailSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 03:22 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 04:07 (America/Los_Angeles - Pacific Time)
//  Notes: Created generic filter detail sheet for watchlist filters with support for different filter types (Sort by, Platform, Scores, Genres, Year, Liked by, Actors). Added interactive range sliders for scores, checkboxes for multi-select options, and radio buttons for single-select options. Replaced year text fields with range slider (1925-2025). Added editable text input fields below slider with bidirectional synchronization - typing in fields updates slider and vice versa.

import SwiftUI

struct WatchlistFilterDetailSheet: View {
    let filterType: WatchlistFiltersBottomSheet.FilterType
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var filterState: WatchlistFilterState
    
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
            ForEach(["List order", "Date added", "Alphabetical", "Tasty Score", "AI Score"], id: \.self) { option in
                Button(action: {
                    filterState.sortBy = option
                }) {
                    HStack(spacing: 12) {
                        // Radio Button
                        ZStack {
                            Circle()
                                .stroke(
                                    filterState.sortBy == option ? Color(hex: "#648d00") : Color(hex: "#b3b3b3"),
                                    lineWidth: 2
                                )
                                .frame(width: 20, height: 20)
                            
                            if filterState.sortBy == option {
                                Circle()
                                    .fill(Color(hex: "#648d00"))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        
                        Text(option)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color(hex: "#f3f3f3"))
            }
        }
    }
    
    // MARK: - Platform Content
    
    private var platformContent: some View {
        VStack(spacing: 0) {
            ForEach(["Netflix", "Apple TV", "Prime Video", "Disney+", "HBO Max", "Hulu"], id: \.self) { platform in
                Button(action: {
                    if filterState.selectedPlatforms.contains(platform) {
                        filterState.selectedPlatforms.remove(platform)
                    } else {
                        filterState.selectedPlatforms.insert(platform)
                    }
                }) {
                    HStack(spacing: 12) {
                        // Checkbox
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    filterState.selectedPlatforms.contains(platform) ? Color(hex: "#648d00") : Color(hex: "#b3b3b3"),
                                    lineWidth: 2
                                )
                                .frame(width: 20, height: 20)
                            
                            if filterState.selectedPlatforms.contains(platform) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#648d00"))
                            }
                        }
                        
                        Text(platform)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color(hex: "#f3f3f3"))
            }
        }
    }
    
    // MARK: - Score Content
    
    private func scoreContent(range: Binding<ClosedRange<Double>>, maxValue: Double) -> some View {
        VStack(spacing: 20) {
            // Current Range Display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("\(Int(range.wrappedValue.lowerBound))")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Max")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("\(Int(range.wrappedValue.upperBound))")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
            }
            
            // Range Slider
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
            ForEach(["Action", "Comedy", "Drama", "Thriller", "Horror", "Sci-Fi", "Romance", "Documentary"], id: \.self) { genre in
                Button(action: {
                    if filterState.selectedGenres.contains(genre) {
                        filterState.selectedGenres.remove(genre)
                    } else {
                        filterState.selectedGenres.insert(genre)
                    }
                }) {
                    HStack(spacing: 12) {
                        // Checkbox
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    filterState.selectedGenres.contains(genre) ? Color(hex: "#648d00") : Color(hex: "#b3b3b3"),
                                    lineWidth: 2
                                )
                                .frame(width: 20, height: 20)
                            
                            if filterState.selectedGenres.contains(genre) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#648d00"))
                            }
                        }
                        
                        Text(genre)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color(hex: "#f3f3f3"))
            }
        }
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
            ForEach(["Any", "Friends", "Following", "Everyone"], id: \.self) { option in
                Button(action: {
                    filterState.likedBy = option
                }) {
                    HStack(spacing: 12) {
                        // Radio Button
                        ZStack {
                            Circle()
                                .stroke(
                                    filterState.likedBy == option ? Color(hex: "#648d00") : Color(hex: "#b3b3b3"),
                                    lineWidth: 2
                                )
                                .frame(width: 20, height: 20)
                            
                            if filterState.likedBy == option {
                                Circle()
                                    .fill(Color(hex: "#648d00"))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        
                        Text(option)
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color(hex: "#f3f3f3"))
            }
        }
    }
    
    // MARK: - Actors Content
    
    private var actorsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actor Name")
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#666666"))
            
            TextField("Search for actor...", text: $filterState.actors)
                .font(.custom("Inter-Regular", size: 16))
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

// MARK: - Range Slider Component

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    
    @State private var lowerValue: Double
    @State private var upperValue: Double
    
    init(range: Binding<ClosedRange<Double>>, bounds: ClosedRange<Double>, step: Double) {
        self._range = range
        self.bounds = bounds
        self.step = step
        self._lowerValue = State(initialValue: range.wrappedValue.lowerBound)
        self._upperValue = State(initialValue: range.wrappedValue.upperBound)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Slider Track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#e0e0e0"))
                        .frame(height: 4)
                    
                    // Active Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#648d00"))
                        .frame(width: trackWidth(in: geometry), height: 4)
                        .offset(x: lowerOffset(in: geometry))
                    
                    // Lower Thumb
                    Circle()
                        .fill(Color(hex: "#648d00"))
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: lowerOffset(in: geometry) - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = value.location.x / geometry.size.width
                                    let clampedValue = max(bounds.lowerBound, min(newValue * (bounds.upperBound - bounds.lowerBound) + bounds.lowerBound, upperValue - step))
                                    lowerValue = round(clampedValue / step) * step
                                    updateRange()
                                }
                        )
                    
                    // Upper Thumb
                    Circle()
                        .fill(Color(hex: "#648d00"))
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: upperOffset(in: geometry) - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = value.location.x / geometry.size.width
                                    let clampedValue = min(bounds.upperBound, max(newValue * (bounds.upperBound - bounds.lowerBound) + bounds.lowerBound, lowerValue + step))
                                    upperValue = round(clampedValue / step) * step
                                    updateRange()
                                }
                        )
                }
            }
            .frame(height: 20)
        }
        .onChange(of: range) { oldValue, newValue in
            if lowerValue != newValue.lowerBound {
                lowerValue = newValue.lowerBound
            }
            if upperValue != newValue.upperBound {
                upperValue = newValue.upperBound
            }
        }
    }
    
    private func lowerOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = (lowerValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return percentage * geometry.size.width
    }
    
    private func upperOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = (upperValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return percentage * geometry.size.width
    }
    
    private func trackWidth(in geometry: GeometryProxy) -> CGFloat {
        return upperOffset(in: geometry) - lowerOffset(in: geometry)
    }
    
    private func updateRange() {
        range = lowerValue...upperValue
    }
}

// MARK: - Year Range Slider Component

struct YearRangeSlider: View {
    @Binding var range: ClosedRange<Int>
    let bounds: ClosedRange<Int>
    
    @State private var lowerValue: Int
    @State private var upperValue: Int
    
    init(range: Binding<ClosedRange<Int>>, bounds: ClosedRange<Int>) {
        self._range = range
        self.bounds = bounds
        self._lowerValue = State(initialValue: range.wrappedValue.lowerBound)
        self._upperValue = State(initialValue: range.wrappedValue.upperBound)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#e0e0e0"))
                    .frame(height: 4)
                
                // Active Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#648d00"))
                    .frame(width: trackWidth(in: geometry), height: 4)
                    .offset(x: lowerOffset(in: geometry))
                
                // Lower Thumb
                Circle()
                    .fill(Color(hex: "#648d00"))
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: lowerOffset(in: geometry) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = value.location.x / geometry.size.width
                                let clampedValue = max(bounds.lowerBound, min(Int(newValue * Double(bounds.upperBound - bounds.lowerBound)) + bounds.lowerBound, upperValue - 1))
                                lowerValue = clampedValue
                                updateRange()
                            }
                    )
                
                // Upper Thumb
                Circle()
                    .fill(Color(hex: "#648d00"))
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: upperOffset(in: geometry) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = value.location.x / geometry.size.width
                                let clampedValue = min(bounds.upperBound, max(Int(newValue * Double(bounds.upperBound - bounds.lowerBound)) + bounds.lowerBound, lowerValue + 1))
                                upperValue = clampedValue
                                updateRange()
                            }
                    )
            }
        }
        .frame(height: 20)
        .onChange(of: range) { oldValue, newValue in
            if lowerValue != newValue.lowerBound {
                lowerValue = newValue.lowerBound
            }
            if upperValue != newValue.upperBound {
                upperValue = newValue.upperBound
            }
        }
    }
    
    private func lowerOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = Double(lowerValue - bounds.lowerBound) / Double(bounds.upperBound - bounds.lowerBound)
        return percentage * geometry.size.width
    }
    
    private func upperOffset(in geometry: GeometryProxy) -> CGFloat {
        let percentage = Double(upperValue - bounds.lowerBound) / Double(bounds.upperBound - bounds.lowerBound)
        return percentage * geometry.size.width
    }
    
    private func trackWidth(in geometry: GeometryProxy) -> CGFloat {
        return upperOffset(in: geometry) - lowerOffset(in: geometry)
    }
    
    private func updateRange() {
        range = lowerValue...upperValue
    }
}

// MARK: - Year Input Field Component

struct YearInputField: View {
    let value: Int
    let bounds: ClosedRange<Int>
    let onValueChanged: (Int) -> Void
    
    @State private var textValue: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("", text: $textValue)
            .font(.custom("Inter-Regular", size: 16))
            .foregroundColor(Color(hex: "#1a1a1a"))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(hex: "#f3f3f3"))
            .cornerRadius(8)
            .focused($isFocused)
            .monospacedDigit()
            .onAppear {
                textValue = "\(value)"
            }
            .onChange(of: value) { oldValue, newValue in
                if !isFocused {
                    textValue = "\(newValue)"
                }
            }
            .onChange(of: textValue) { oldValue, newValue in
                if let intValue = Int(newValue) {
                    let clampedValue = max(bounds.lowerBound, min(intValue, bounds.upperBound))
                    if clampedValue != intValue {
                        // Update text if value was clamped
                        DispatchQueue.main.async {
                            textValue = "\(clampedValue)"
                        }
                    }
                    onValueChanged(clampedValue)
                } else if newValue.isEmpty {
                    // Allow empty while typing
                } else {
                    // Invalid input - revert to previous valid value
                    DispatchQueue.main.async {
                        textValue = "\(value)"
                    }
                }
            }
            .onChange(of: isFocused) { oldValue, newValue in
                isEditing = newValue
                if !newValue {
                    // When focus is lost, ensure text matches current value
                    textValue = "\(value)"
                }
            }
    }
}

// MARK: - Preview

#Preview {
    WatchlistFilterDetailSheet(filterType: .sortBy)
        .environmentObject(WatchlistFilterState.shared)
}

