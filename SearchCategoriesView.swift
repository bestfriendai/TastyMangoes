//  SearchCategoriesView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:56 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 05:44 (America/Los_Angeles - Pacific Time)
//  Notes: Built category browsing view for search section with platform selection and genre categories organized by mood. Added checkbox for "My subscriptions" - when checked, shows only Prime and Max. Added platform logos with brand colors. Added selection indicators (checkmarks and borders) for categories. Added "Start Searching (N)" button at bottom when items are selected. Fixed button positioning using safeAreaInset to ensure it appears above tab bar and is always visible. Added temporary TEST button at top for debugging visibility. Fixed missing closing brace syntax error.

import SwiftUI

struct SearchCategoriesView: View {
    @State private var showMySubscriptions = false
    @State private var selectedPlatforms: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    
    // All platform options
    private let allPlatforms = ["Netflix", "Prime Video", "Disney+", "Max"]
    
    // User's subscriptions (when checkbox is checked) - for now just Prime and Max
    private var userSubscriptions: [String] {
        ["Prime Video", "Max"]
    }
    
    // Platforms to display based on checkbox state
    private var platforms: [String] {
        showMySubscriptions ? userSubscriptions : allPlatforms
    }
    
    // Total selected count for button
    private var totalSelections: Int {
        selectedPlatforms.count + selectedCategories.count
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
            // TEST BUTTON - Temporary, visible at top for testing
            if totalSelections > 0 {
                VStack(spacing: 0) {
                    Button(action: {
                        startSearching()
                    }) {
                        Text("TEST: Start Searching (\(totalSelections))")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#FEA500"))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    Divider()
                        .background(Color(hex: "#f3f3f3"))
                }
                .background(Color.white)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // My Subscriptions Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Checkbox and Label
                        HStack(spacing: 8) {
                            Button(action: {
                                showMySubscriptions.toggle()
                                // Clear platform selections when toggling
                                if showMySubscriptions {
                                    selectedPlatforms.removeAll()
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
                                        isSelected: selectedPlatforms.contains(platform)
                                    ) {
                                        if selectedPlatforms.contains(platform) {
                                            selectedPlatforms.remove(platform)
                                        } else {
                                            selectedPlatforms.insert(platform)
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
                        selectedCategories: $selectedCategories
                    )
                    .padding(.horizontal, 16)
                }
                
                // Bottom padding for button
                Color.clear
                    .frame(height: totalSelections > 0 ? 120 : 20)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
            // Start Searching Button (only show when selections are made)
            if totalSelections > 0 {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(hex: "#f3f3f3"))
                    
                    Button(action: {
                        startSearching()
                    }) {
                        Text("Start Searching (\(totalSelections))")
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
                .background(
                    Color.white
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: -2)
                )
            } else {
                Color.clear.frame(height: 0)
            }
        }
        }
    }
    
    private func startSearching() {
        // TODO: Navigate to search results with selected platforms and categories
        print("Starting search with \(selectedPlatforms.count) platforms and \(selectedCategories.count) categories")
    }
}

// MARK: - Category Group View

struct CategoryGroupView: View {
    let groupName: String
    let categories: [SearchCategoryItem]
    @Binding var selectedCategories: Set<String>
    
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
                        isSelected: selectedCategories.contains(category.name)
                    ) {
                        if selectedCategories.contains(category.name) {
                            selectedCategories.remove(category.name)
                        } else {
                            selectedCategories.insert(category.name)
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
                // Netflix red logo
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E50914"))
                    Text("N")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Prime Video":
                // Prime Video logo (blue/black)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#00A8E1"))
                    Text("P")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Disney+":
                // Disney+ blue logo
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#113CCF"))
                    Text("D")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            case "Max":
                // Max black logo
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    Text("M")
                        .font(.custom("Nunito-Bold", size: 32))
                        .foregroundColor(.white)
                }
            default:
                // Default placeholder
                Text(platform.prefix(1))
                    .font(.custom("Nunito-Bold", size: 24))
                    .foregroundColor(Color(hex: "#333333"))
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

