//
//  WatchlistBottomSheet.swift
//  TastyMangoes
//
//  Created from Figma Component Library
//

import SwiftUI

struct Watchlist: Identifiable {
    let id: String
    let name: String
    let filmCount: Int
    let imageURL: String?
    let isSelected: Bool
}

struct WatchlistBottomSheet: View {
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var selectedWatchlists: Set<String> = []
    @State private var watchlists: [Watchlist] = []
    @State private var dragOffset: CGFloat = 0
    
    // Sample data - replace with your actual data source
    private let sampleWatchlists = [
        Watchlist(id: "1", name: "Masterlist", filmCount: 8, imageURL: nil, isSelected: true),
        Watchlist(id: "2", name: "Must-Watch Movies", filmCount: 12, imageURL: nil, isSelected: false),
        Watchlist(id: "3", name: "Sci-Fi Masterpieces", filmCount: 10, imageURL: nil, isSelected: false),
        Watchlist(id: "4", name: "Action Blockbusters", filmCount: 20, imageURL: nil, isSelected: false),
        Watchlist(id: "5", name: "My Favorite Films", filmCount: 15, imageURL: nil, isSelected: false),
        Watchlist(id: "6", name: "Animated Adventures", filmCount: 15, imageURL: nil, isSelected: false)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            dragHandle
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                isPresented = false
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            
            // Body Content
            ScrollView {
                VStack(spacing: 24) {
                    // Recommendation Section
                    recommendationSection
                    
                    // All Lists Section
                    allListsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            // Bottom Section
            bottomSection
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .frame(maxHeight: 600)
        .offset(y: max(0, dragOffset))
        .onAppear {
            watchlists = sampleWatchlists
            // Pre-select watchlists that are already selected
            selectedWatchlists = Set(watchlists.filter { $0.isSelected }.map { $0.id })
        }
    }
    
    // MARK: - Drag Handle
    
    private var dragHandle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#b3b3b3"))
                .frame(width: 32, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Recommendation Section
    
    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: {}) {
                ListCardView(
                    watchlist: Watchlist(
                        id: "master",
                        name: "Masterlist",
                        filmCount: 8,
                        imageURL: nil,
                        isSelected: true
                    ),
                    isDisabled: true
                )
            }
        }
    }
    
    // MARK: - All Lists Section
    
    private var allListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR LISTS")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#999999"))
                    .textCase(.uppercase)
                
                // Search Input
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    TextField("Searching list by name...", text: $searchText)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    Button(action: {}) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(hex: "#f3f3f3"))
                .cornerRadius(8)
            }
            
            // Watchlist Cards
            VStack(spacing: 12) {
                // Create New Watchlist Card
                Button(action: {
                    // Handle create new watchlist
                }) {
                    CreateWatchlistCard()
                }
                
                // Existing Watchlists
                ForEach(filteredWatchlists) { watchlist in
                    Button(action: {
                        toggleWatchlistSelection(watchlist.id)
                    }) {
                        ListCardView(
                            watchlist: watchlist,
                            isDisabled: watchlist.id == "1" // Disable masterlist
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Button Section
            VStack(spacing: 0) {
                Divider()
                    .background(Color(hex: "#f3f3f3"))
                
                HStack {
                    Button(action: {
                        // Handle add to watchlist
                        isPresented = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#333333"))
                            
                            Text("Add to Watchlist (\(selectedWatchlists.count))")
                                .font(.custom("Nunito-Bold", size: 14))
                                .foregroundColor(Color(hex: "#333333"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#f3f3f3"))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            
            // Home Indicator
            homeIndicator
        }
    }
    
    // MARK: - Home Indicator
    
    private var homeIndicator: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .frame(width: 134, height: 5)
                .padding(.bottom, 8)
        }
        .frame(height: 34)
    }
    
    // MARK: - Computed Properties
    
    private var filteredWatchlists: [Watchlist] {
        if searchText.isEmpty {
            return watchlists
        } else {
            return watchlists.filter { watchlist in
                watchlist.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleWatchlistSelection(_ id: String) {
        if id == "1" { return } // Don't allow deselecting masterlist
        
        if selectedWatchlists.contains(id) {
            selectedWatchlists.remove(id)
        } else {
            selectedWatchlists.insert(id)
        }
    }
}

// MARK: - List Card View

struct ListCardView: View {
    let watchlist: Watchlist
    let isDisabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Image/Icon
            if let imageURL = watchlist.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderImage
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)
            } else {
                placeholderImage
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 0) {
                Text(watchlist.name)
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .lineLimit(1)
                
                Text("\(watchlist.filmCount) films")
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // Checkbox
            CheckboxView(
                isSelected: watchlist.isSelected || (isDisabled && watchlist.id == "1"),
                isDisabled: isDisabled
            )
        }
        .padding(.vertical, 4)
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: "#f3f3f3"))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
            )
    }
}

// MARK: - Create Watchlist Card

struct CreateWatchlistCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Plus Icon Container
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#f3f3f3"))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#333333"))
                )
            
            // Text Content
            VStack(alignment: .leading, spacing: 0) {
                Text("Create New Watchlist")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .lineLimit(1)
                
                Text("Can't find the list you need? Create a new one.")
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
                    .padding(.top, 4)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Checkbox View

struct CheckboxView: View {
    let isSelected: Bool
    let isDisabled: Bool
    
    var body: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isDisabled ? Color(hex: "#fea500") : Color(hex: "#fea500"))
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#b3b3b3"))
            }
        }
        .frame(width: 24, height: 24)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Modifier for Presentation

extension View {
    func watchlistBottomSheet(isPresented: Binding<Bool>) -> some View {
        ZStack(alignment: .bottom) {
            self
            
            if isPresented.wrappedValue {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isPresented.wrappedValue = false
                        }
                    }
                
                // Bottom Sheet
                WatchlistBottomSheet(isPresented: isPresented)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented.wrappedValue)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            WatchlistBottomSheet(isPresented: .constant(true))
        }
    }
}

