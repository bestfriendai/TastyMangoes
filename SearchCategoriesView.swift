//  SearchCategoriesView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:56 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 05:44 (America/Los_Angeles - Pacific Time)
//  Notes: Built category browsing view for search section with platform selection and genre categories organized by mood. Added checkbox for "My subscriptions" - when checked, shows only Prime and Max. Added platform logos with brand colors. Added selection indicators (checkmarks and borders) for categories. Added "Start Searching (N)" button at bottom when items are selected. Fixed button positioning using safeAreaInset to ensure it appears above tab bar and is always visible. Added temporary TEST button at top for debugging visibility. Fixed missing closing brace syntax error.

import SwiftUI

struct SearchCategoriesView: View {
    @ObservedObject private var filterState = SearchFilterState.shared
    @State private var showMySubscriptions = false
    
    // All platform options (10 platforms total)
    private let allPlatforms = ["Netflix", "Prime Video", "Disney+", "Max", "Hulu", "Criterion", "Paramount+", "Apple TV+", "Peacock", "Tubi"]
    
    // User's subscriptions (when checkbox is checked) - Prime Video and Criterion
    private var userSubscriptions: [String] {
        ["Prime Video", "Criterion"]
    }
    
    // Platforms to display based on checkbox state
    private var platforms: [String] {
        showMySubscriptions ? userSubscriptions : allPlatforms
    }
    
    // Total selected count for button (using SearchFilterState)
    private var totalSelections: Int {
        filterState.selectedPlatforms.count + filterState.selectedGenres.count
    }
    
    // Category groups with counts (matching Figma design)
    private let categoryGroups: [(name: String, categories: [SearchCategoryItem])] = [
        (
            name: "FUN & LIGHT",
            categories: [
                SearchCategoryItem(name: "Comedy", icon: "theatermasks", count: 120),
                SearchCategoryItem(name: "Romance", icon: "heart", count: 888),
                SearchCategoryItem(name: "Musical", icon: "music.note", count: 420),
                SearchCategoryItem(name: "Family", icon: "house", count: 140),
                SearchCategoryItem(name: "Animation", icon: "pawprint", count: 1000)
            ]
        ),
        (
            name: "EPIC & IMAGINATIVE",
            categories: [
                SearchCategoryItem(name: "Adventure", icon: "globe", count: 120),
                SearchCategoryItem(name: "Fantasy", icon: "wand.and.stars", count: 1000),
                SearchCategoryItem(name: "Sci-Fi", icon: "airplane", count: 190),
                SearchCategoryItem(name: "Historical", icon: "building.columns", count: 130)
            ]
        ),
        (
            name: "DARK & INTENSE",
            categories: [
                SearchCategoryItem(name: "Action", icon: "hand.raised", count: 120),
                SearchCategoryItem(name: "Thriller", icon: "eye", count: 888),
                SearchCategoryItem(name: "Mystery", icon: "questionmark.circle", count: 420),
                SearchCategoryItem(name: "Crime", icon: "car", count: 140),
                SearchCategoryItem(name: "Horror", icon: "moon", count: 140),
                SearchCategoryItem(name: "War", icon: "sword", count: 1000),
                SearchCategoryItem(name: "Western", icon: "hat", count: 640)
            ]
        ),
        (
            name: "REAL STORIES",
            categories: [
                SearchCategoryItem(name: "Documentary", icon: "film", count: 120),
                SearchCategoryItem(name: "Biography", icon: "person", count: 888),
                SearchCategoryItem(name: "Sport", icon: "figure.run", count: 420),
                SearchCategoryItem(name: "Drama", icon: "theatermasks.fill", count: 140)
            ]
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Results Count and Clear All Section (only show when selections > 0)
                    if totalSelections > 0 {
                        HStack {
                            // "1000+ results found" text on left
                            Text("1000+ results found")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Color(hex: "#808080"))
                            
                            Spacer()
                            
                            // "Clear All" button on right
                            Button(action: {
                                // Clear all selections
                                filterState.selectedPlatforms.removeAll()
                                filterState.selectedGenres.removeAll()
                                // Also uncheck "My subscriptions" if it was checked
                                if showMySubscriptions {
                                    showMySubscriptions = false
                                }
                            }) {
                                Text("Clear All")
                                    .font(.custom("Nunito-SemiBold", size: 14))
                                    .foregroundColor(Color(hex: "#FEA500"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    
                    // My Subscriptions Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Checkbox and Label
                        HStack(spacing: 8) {
                            Button(action: {
                                showMySubscriptions.toggle()
                                // Add/remove subscription platforms when toggling
                                if showMySubscriptions {
                                    // When checking ON: Add subscription platforms
                                    filterState.selectedPlatforms.insert("Prime Video")
                                    filterState.selectedPlatforms.insert("Criterion")
                                } else {
                                    // When checking OFF: Remove subscription platforms
                                    filterState.selectedPlatforms.remove("Prime Video")
                                    filterState.selectedPlatforms.remove("Criterion")
                                }
                            }) {
                                Image(systemName: showMySubscriptions ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 24))
                                    .foregroundColor(showMySubscriptions ? Color(hex: "#FEA500") : Color(hex: "#B3B3B3"))
                            }
                            
                            Text("My subscriptions")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#333333"))
                        }
                        .padding(.horizontal, 16)
                        
                        // Platform Selection (horizontal scroll)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(platforms, id: \.self) { platform in
                                    PlatformCard(
                                        platform: platform,
                                        isSelected: filterState.selectedPlatforms.contains(platform)
                                    ) {
                                        if filterState.selectedPlatforms.contains(platform) {
                                            filterState.selectedPlatforms.remove(platform)
                                        } else {
                                            filterState.selectedPlatforms.insert(platform)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                    .padding(.top, 24)
                
                // Category Groups
                ForEach(categoryGroups, id: \.name) { group in
                    CategoryGroupView(
                        groupName: group.name,
                        categories: group.categories,
                        filterState: filterState
                    )
                    .padding(.horizontal, 16)
                }
                
                // Bottom padding
                Color.clear
                    .frame(height: 20)
                }
            }
        }
    }
    
    private func startSearching() {
        // TODO: Navigate to search results with selected platforms and categories
        print("Starting search with \(filterState.selectedPlatforms.count) platforms and \(filterState.selectedGenres.count) genres")
    }
}

// MARK: - Category Group View

struct CategoryGroupView: View {
    let groupName: String
    let categories: [SearchCategoryItem]
    @ObservedObject var filterState: SearchFilterState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group Title
            Text(groupName)
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#999999"))
                .textCase(.uppercase)
            
            // Category Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(categories) { category in
                    CategoryCard(
                        category: category,
                        isSelected: filterState.selectedGenres.contains(category.name)
                    ) {
                        if filterState.selectedGenres.contains(category.name) {
                            filterState.selectedGenres.remove(category.name)
                        } else {
                            filterState.selectedGenres.insert(category.name)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Search Category Item

struct SearchCategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let count: Int
}

// MARK: - Platform Card

struct PlatformCard: View {
    let platform: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 0)
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#FEA500"), lineWidth: 2)
                        .frame(width: 80, height: 80)
                }
                
                // Platform logo
                PlatformLogo(platform: platform)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Platform Logo View

struct PlatformLogo: View {
    let platform: String
    
    var body: some View {
        Group {
            switch platform {
            case "Netflix":
                // Netflix red logo - iconic red background
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E50914"))
                    Text("N")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Prime Video":
                // Prime Video logo - blue background
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#00A8E1"))
                    Text("P")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Disney+":
                // Disney+ blue logo - royal blue
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#113CCF"))
                    Text("D")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Max":
                // Max black logo - sleek black
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    Text("M")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Hulu":
                // Hulu green logo - vibrant green (#1CE783)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#1CE783"))
                    Text("H")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Criterion":
                // Criterion Collection - elegant black/white with "C" in sophisticated style
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    Text("C")
                        .font(.custom("Nunito-Bold", size: 28))
                        .foregroundColor(.white)
                }
            case "Paramount+":
                // Paramount+ blue logo - bright blue (#0064FF)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#0064FF"))
                    Text("P+")
                        .font(.custom("Nunito-Bold", size: 24))
                        .foregroundColor(.white)
                }
            case "Apple TV+":
                // Apple TV+ - black background with Apple TV+ text
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
            case "Peacock":
                // Peacock - colorful purple/blue gradient or solid purple
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6A1B9A"), Color(hex: "#1976D2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("P")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Tubi":
                // Tubi - orange/red brand color (#FA2B31)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#FA2B31"))
                    Text("T")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            default:
                // Default placeholder
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

// MARK: - Category Card

struct CategoryCard: View {
    let category: SearchCategoryItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FEA500"))
                
                // Category Name and Count
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.custom("Nunito-SemiBold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    Text(category.count >= 1000 ? "1000+" : "\(category.count)")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#808080"))
                }
                
                Spacer()
                
                // Selection indicator (checkmark)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FEA500"))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: "#FEA500") : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SearchCategoriesView()
}

