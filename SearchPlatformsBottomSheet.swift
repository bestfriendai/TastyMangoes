//  SearchPlatformsBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:30 (America/Los_Angeles - Pacific Time)
//  Notes: Built Platforms filter bottom sheet with My Subscriptions and All Platforms sections, checkboxes, counts, Clear All, and Apply Filters

import SwiftUI

struct SearchPlatformsBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    // Use @ObservedObject for singleton to avoid recreating state
    @ObservedObject private var filterState = SearchFilterState.shared
    
    @State private var mySubscriptionsSelected: Set<String> = []
    @State private var allPlatformsSelected: Set<String> = []
    
    // Mock platform data with counts
    private let mySubscriptions: [(name: String, count: Int, icon: String)] = [
        ("Netflix", 88, "netflix"),
        ("Apple TV", 32, "appletv")
    ]
    
    private let allPlatforms: [(name: String, count: Int, icon: String)] = [
        ("Netflix", 88, "netflix"),
        ("Apple TV", 32, "appletv"),
        ("Prime Video", 24, "prime")
    ]
    
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
                Text("Platforms")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                Button(action: {
                    filterState.clearPlatformFilters()
                    mySubscriptionsSelected = []
                    allPlatformsSelected = []
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
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // My Subscriptions Section
                    FilterGroupSection(
                        title: "My Subscriptions",
                        count: mySubscriptionsSelected.count,
                        isAllSelected: mySubscriptionsSelected.count == mySubscriptions.count && !mySubscriptions.isEmpty,
                        onSelectAll: {
                            if mySubscriptionsSelected.count == mySubscriptions.count {
                                mySubscriptionsSelected = []
                            } else {
                                mySubscriptionsSelected = Set(mySubscriptions.map { $0.name })
                            }
                        }
                    ) {
                        ForEach(mySubscriptions, id: \.name) { platform in
                            PlatformListItem(
                                name: platform.name,
                                count: platform.count,
                                isSelected: mySubscriptionsSelected.contains(platform.name),
                                onToggle: {
                                    if mySubscriptionsSelected.contains(platform.name) {
                                        mySubscriptionsSelected.remove(platform.name)
                                    } else {
                                        mySubscriptionsSelected.insert(platform.name)
                                    }
                                }
                            )
                        }
                    }
                    
                    // All Platforms Section
                    FilterGroupSection(
                        title: "All Platforms",
                        count: nil,
                        isAllSelected: false,
                        onSelectAll: nil
                    ) {
                        ForEach(allPlatforms, id: \.name) { platform in
                            PlatformListItem(
                                name: platform.name,
                                count: platform.count,
                                isSelected: allPlatformsSelected.contains(platform.name),
                                onToggle: {
                                    if allPlatformsSelected.contains(platform.name) {
                                        allPlatformsSelected.remove(platform.name)
                                    } else {
                                        allPlatformsSelected.insert(platform.name)
                                    }
                                }
                            )
                        }
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
                filterState.selectedPlatforms = mySubscriptionsSelected.union(allPlatformsSelected)
                dismiss()
            }) {
                Text("Apply Filters")
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
            mySubscriptionsSelected = filterState.selectedPlatforms.intersection(Set(mySubscriptions.map { $0.name }))
            allPlatformsSelected = filterState.selectedPlatforms.intersection(Set(allPlatforms.map { $0.name }))
        }
    }
}

// MARK: - Filter Group Section

struct FilterGroupSection<Content: View>: View {
    let title: String
    let count: Int?
    let isAllSelected: Bool
    let onSelectAll: (() -> Void)?
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                if let count = count {
                    HStack(spacing: 12) {
                        Text("\(count)")
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(Color(hex: "#808080"))
                        
                        if let onSelectAll = onSelectAll {
                            Button(action: onSelectAll) {
                                Image(systemName: isAllSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 24))
                                    .foregroundColor(isAllSelected ? Color(hex: "#FEA500") : Color(hex: "#B3B3B3"))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            
            Divider()
                .background(Color(hex: "#f3f3f3"))
            
            // Content
            content
        }
    }
}

// MARK: - Platform List Item

struct PlatformListItem: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Platform Avatar
                Circle()
                    .fill(Color(hex: "#E0E0E0"))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(name.prefix(1))
                            .font(.custom("Nunito-Bold", size: 12))
                            .foregroundColor(Color(hex: "#333333"))
                    )
                
                // Platform Name
                Text(name)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                // Count and Checkbox
                HStack(spacing: 12) {
                    Text("\(count)")
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

// MARK: - Preview

#Preview {
    SearchPlatformsBottomSheet(isPresented: .constant(true))
}

