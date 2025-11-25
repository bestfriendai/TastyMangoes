//  YourListsView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:17 (America/Los_Angeles - Pacific Time)
//  Notes: Created Watchlist / Your Lists view with search, Create New Watchlist card, and large list cards matching Figma design. Integrated list creation and sorting. Added menu button functionality to show ManageListBottomSheet.

import SwiftUI

struct YourListsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var showSortSheet = false
    @State private var showManageMode = false
    @State private var showCreateWatchlistSheet = false
    @State private var showManageListSheet = false
    @State private var selectedListForMenu: WatchlistItem? = nil
    @State private var selectedListIds: Set<String> = []
    
    @EnvironmentObject private var watchlistManager: WatchlistManager
    
    @State private var lists: [WatchlistItem] = [
        WatchlistItem(id: "1", name: "Must-Watch Movies", filmCount: 8, thumbnailURL: nil),
        WatchlistItem(id: "2", name: "Action Blockbusters", filmCount: 15, thumbnailURL: nil),
        WatchlistItem(id: "3", name: "Holiday Favorites", filmCount: 9, thumbnailURL: nil),
        WatchlistItem(id: "4", name: "Romantic Classics", filmCount: 12, thumbnailURL: nil),
        WatchlistItem(id: "5", name: "Feel-Good Comedies", filmCount: 12, thumbnailURL: nil),
        WatchlistItem(id: "6", name: "Award-Winning Documentaries", filmCount: 12, thumbnailURL: nil),
        WatchlistItem(id: "7", name: "Classic Horror Collection", filmCount: 10, thumbnailURL: nil),
        WatchlistItem(id: "8", name: "Cult Classics", filmCount: 7, thumbnailURL: nil),
        WatchlistItem(id: "9", name: "Animated Adventures", filmCount: 10, thumbnailURL: nil),
        WatchlistItem(id: "10", name: "International Films", filmCount: 12, thumbnailURL: nil),
        WatchlistItem(id: "11", name: "Chilling Thrillers", filmCount: 9, thumbnailURL: nil),
        WatchlistItem(id: "12", name: "Sci-Fi Masterpieces", filmCount: 11, thumbnailURL: nil)
    ]
    
    var filteredLists: [WatchlistItem] {
        if searchText.isEmpty {
            return lists
        } else {
            return lists.filter { list in
                list.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#fdfdfd")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation
                topNavigationHeader
                
                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Search Bar
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        // Lists
                        VStack(spacing: 12) {
                        // Create New Watchlist Card
                        Button(action: {
                            showCreateWatchlistSheet = true
                        }) {
                                CreateNewWatchlistCard()
                            }
                            .buttonStyle(.plain)
                            
                            // List Cards
                            ForEach(filteredLists) { list in
                                ZStack(alignment: .trailing) {
                                    NavigationLink(destination: IndividualListView(listId: list.id, listName: list.name)) {
                                        LargeListCard(
                                            list: list,
                                            isSelected: selectedListIds.contains(list.id),
                                            isManageMode: showManageMode,
                                            onTap: {
                                                if showManageMode {
                                                    toggleSelection(list.id)
                                                }
                                            },
                                            onMenuTap: {
                                                selectedListForMenu = list
                                                showManageListSheet = true
                                            },
                                            showMenuButton: !showManageMode
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Menu button overlay (only when not in manage mode)
                                    if !showManageMode {
                                        Button(action: {
                                            selectedListForMenu = list
                                            showManageListSheet = true
                                        }) {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(Color(hex: "#666666"))
                                                .padding(8)
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: -8, y: 0)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSortSheet) {
            SortByBottomSheet(
                isPresented: $showSortSheet,
                currentSort: watchlistManager.currentSortOption
            ) { newSortOption in
                watchlistManager.currentSortOption = newSortOption
                loadLists()
            }
        }
        .sheet(isPresented: $showCreateWatchlistSheet) {
            CreateWatchlistBottomSheet(isPresented: $showCreateWatchlistSheet) { newWatchlist in
                // Reload lists to include the new one
                loadLists()
            }
            .environmentObject(watchlistManager)
        }
        .sheet(isPresented: $showManageListSheet) {
            if let list = selectedListForMenu {
                ManageListBottomSheet(
                    isPresented: $showManageListSheet,
                    listId: list.id,
                    listName: list.name
                )
                .environmentObject(watchlistManager)
                .onDisappear {
                    // Reload lists in case list was deleted or modified
                    loadLists()
                }
            }
        }
        .onAppear {
            loadLists()
        }
    }
    
    // MARK: - Top Navigation Header
    
    private var topNavigationHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            // Back Button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .frame(width: 28, height: 28)
            }
            
            // Title
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Lists")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Text("(\(lists.count))")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            Spacer()
            
            // Manage Button
            Button(action: {
                showManageMode.toggle()
                if !showManageMode {
                    selectedListIds.removeAll()
                }
            }) {
                Image(systemName: showManageMode ? "checkmark" : "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
                
                TextField("Searching list by name...", text: $searchText)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#666666"))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(hex: "#f3f3f3"))
            .cornerRadius(8)
            
            // Sort Button
            Button(action: {
                showSortSheet = true
            }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "#f3f3f3"))
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadLists() {
        // Load lists from WatchlistManager with current sort
        lists = watchlistManager.getAllWatchlists(sortBy: watchlistManager.currentSortOption)
    }
    
    private func toggleSelection(_ listId: String) {
        if selectedListIds.contains(listId) {
            selectedListIds.remove(listId)
        } else {
            selectedListIds.insert(listId)
        }
    }
}

// MARK: - Create New Watchlist Card

struct CreateNewWatchlistCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Plus Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#f3f3f3"))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "plus")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#333333"))
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Create New Watchlist")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Text("Can't find the list you need? Create a new one.")
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            Spacer()
        }
        .padding(4)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Large List Card

struct LargeListCard: View {
    let list: WatchlistItem
    let isSelected: Bool
    let isManageMode: Bool
    let onTap: () -> Void
    let onMenuTap: () -> Void
    let showMenuButton: Bool
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#f3f3f3"))
                        .frame(width: 64, height: 64)
                    
                    if let thumbnailURL = list.thumbnailURL, let url = URL(string: thumbnailURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#999999"))
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#999999"))
                            @unknown default:
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#999999"))
                            }
                        }
                    } else {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }
                
                // List Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Text("\(list.filmCount) films")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                // Selection Indicator or Menu Placeholder
                if isManageMode {
                    // Selection Checkbox
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color(hex: "#FEA500") : Color(hex: "#b3b3b3"), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color(hex: "#FEC966"))
                                .frame(width: 12, height: 12)
                        }
                    }
                } else if showMenuButton {
                    // Placeholder space for menu button (actual button is in overlay)
                    Color.clear
                        .frame(width: 34, height: 34)
                }
            }
            .padding(4)
            .background(isSelected && isManageMode ? Color(hex: "#ffedcc") : Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        YourListsView()
    }
}

