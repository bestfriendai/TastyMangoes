//  AddToListView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:20 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-01-15 at 14:45 (America/Los_Angeles - Pacific Time)
//  Notes: Updated to match Figma design with search bar at top, "ALREADY ADDED" section, "ALL LISTS" section, and "Confirm Changes" button. Updated thumbnail sizes to 64x64 and spacing to 16px.

import SwiftUI

struct AddToListView: View {
    let movieId: String
    let movieTitle: String
    var onNavigateToList: ((String, String) -> Void)? = nil // Callback: (listId, listName)
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    @State private var searchText: String = ""
    @State private var selectedListIds: Set<String> = []
    @State private var watchlists: [WatchlistItem] = []
    @State private var filteredWatchlists: [WatchlistItem] = []
    @State private var alreadyAddedLists: [WatchlistItem] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastListName: String = ""
    @State private var toastListId: String = ""
    @State private var showCreateWatchlistSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation with Search Bar
            topNavSection
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Already Added Section
                    if !alreadyAddedLists.isEmpty {
                        alreadyAddedSection
                    }
                    
                    // All Lists Section
                    allListsSection
                }
            }
            
            // Bottom Button
            bottomButtonSection
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            loadWatchlists()
            updateLists()
        }
        .onChange(of: searchText) { oldValue, newValue in
            updateLists()
        }
        .sheet(isPresented: $showCreateWatchlistSheet) {
            CreateWatchlistBottomSheet(isPresented: $showCreateWatchlistSheet) { newWatchlist in
                // Add the newly created list to selected lists
                selectedListIds.insert(newWatchlist.id)
                // Reload watchlists to include the new one
                loadWatchlists()
                updateLists()
            }
            .environmentObject(watchlistManager)
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastView(
                    title: "Added to Watchlist",
                    message: toastMessage,
                    listName: toastListName,
                    onGoToList: {
                        showToast = false
                        dismiss()
                        // Navigate to list using callback
                        if !toastListId.isEmpty {
                            onNavigateToList?(toastListId, toastListName)
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
                .padding(.top, 60)
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Top Navigation Section
    
    private var topNavSection: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 4) {
                HStack(spacing: 8) {
                    // Back Arrow Icon
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#333333"))
                    }
                    
                    // Search Field
                    TextField("Searching list by name...", text: $searchText)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    // Microphone Icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#666666"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(hex: "#f3f3f3"))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color(hex: "#f3f3f3"))
        }
        .background(Color.white)
    }
    
    // MARK: - Already Added Section
    
    private var alreadyAddedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("ALREADY ADDED")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(Color(hex: "#999999"))
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            // Already Added Lists
            VStack(spacing: 16) {
                ForEach(alreadyAddedLists) { list in
                    ListItemRow(
                        list: list,
                        movieId: movieId,
                        watchlistManager: watchlistManager,
                        isAlreadyAdded: true
                    ) {
                        // Already added lists are disabled
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - All Lists Section
    
    private var allListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("ALL LISTS")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(Color(hex: "#999999"))
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, alreadyAddedLists.isEmpty ? 16 : 0)
            
            // Create New Watchlist
            Button(action: {
                showCreateWatchlistSheet = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#f3f3f3"))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "#333333"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create New Watchlist")
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        
                        Text("Can't find the list you need? Create a new one.")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            
            // Watchlists List
            VStack(spacing: 16) {
                ForEach(filteredWatchlists) { list in
                    ListItemRow(
                        list: list,
                        movieId: movieId,
                        watchlistManager: watchlistManager,
                        isAlreadyAdded: false
                    ) {
                        toggleListSelection(list.id)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Bottom Button Section
    
    private var bottomButtonSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(hex: "#ffedcc"))
            
            Button(action: {
                submitSelections()
            }) {
                Text("Confirm Changes")
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
        .background(Color.white)
    }
    
    // MARK: - Helper Methods
    
    private func loadWatchlists() {
        // Load watchlists from WatchlistManager
        watchlists = watchlistManager.getAllWatchlists()
    }
    
    private func updateLists() {
        // Get lists that already contain this movie
        let existingListIds = watchlistManager.getListsForMovie(movieId: movieId)
        selectedListIds = existingListIds
        
        // Separate already added lists from all lists
        alreadyAddedLists = watchlists.filter { existingListIds.contains($0.id) }
        
        // Filter remaining lists based on search
        let remainingLists = watchlists.filter { !existingListIds.contains($0.id) }
        
        if searchText.isEmpty {
            filteredWatchlists = remainingLists
        } else {
            filteredWatchlists = remainingLists.filter { list in
                list.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func toggleListSelection(_ listId: String) {
        if selectedListIds.contains(listId) {
            // Deselect - remove from list
            watchlistManager.removeMovieFromList(movieId: movieId, listId: listId)
            selectedListIds.remove(listId)
        } else {
            // Add to list
            let success = watchlistManager.addMovieToList(movieId: movieId, listId: listId)
            if success {
                selectedListIds.insert(listId)
            }
        }
    }
    
    private func submitSelections() {
        // Add to all selected lists
        for listId in selectedListIds {
            _ = watchlistManager.addMovieToList(movieId: movieId, listId: listId)
        }
        
        // Show toast for first selected list
        if let firstListId = selectedListIds.first,
           let list = watchlists.first(where: { $0.id == firstListId }) {
            toastMessage = "\(movieTitle) added to \(list.name)."
            toastListName = list.name
            toastListId = firstListId
            showToast = true
            
            // Hide toast after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showToast = false
                }
            }
        }
        
        dismiss()
    }
}

// MARK: - List Item Row

struct ListItemRow: View {
    let list: WatchlistItem
    let movieId: String
    @ObservedObject var watchlistManager: WatchlistManager
    let isAlreadyAdded: Bool
    let onTap: () -> Void
    
    private var isSelected: Bool {
        if isAlreadyAdded {
            return true // Already added lists are always selected
        }
        return watchlistManager.isMovieInList(movieId: movieId, listId: list.id)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // List Icon/Thumbnail (64x64)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Text("\(list.filmCount) films")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                // Selection Indicator (24x24)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FEA500"))
                } else {
                    Circle()
                        .stroke(Color(hex: "#b3b3b3"), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded) // Already added lists are disabled
    }
}

// MARK: - Toast View

struct ToastView: View {
    let title: String
    let message: String
    let listName: String
    let onGoToList: () -> Void
    
    @State private var isVisible: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon Area
            ZStack {
                Circle()
                    .fill(Color(hex: "#fdfdfd"))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#648d00"))
            }
            
            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                
                Text(message)
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            Spacer()
            
            // Go to List Button
            Button(action: onGoToList) {
                Text("Go to List")
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(Color(hex: "#414141"))
                    .underline()
            }
        }
        .padding(12)
        .background(Color(hex: "#f3f3f3"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#648d00").opacity(0.24), lineWidth: 1)
        )
        .cornerRadius(8)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddToListView(movieId: "550", movieTitle: "Jurassic Park")
        .environmentObject(WatchlistManager.shared)
}
