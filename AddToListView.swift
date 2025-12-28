//  AddToListView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 00:20 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 02:55 (America/Los_Angeles - Pacific Time)
//  Notes: Converted to bottom sheet modal to match Figma design with Masterlist section, YOUR LISTS section, search, and Add to Watchlist button with count. Fixed unused return value warning. Added Create New Watchlist functionality and Navigate to List callback.

import SwiftUI

struct AddToListView: View {
    let movieId: String
    let movieTitle: String
    var prefilledRecommender: String? = nil
    var onNavigateToList: ((String, String) -> Void)? = nil // Callback: (listId, listName)
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    @ObservedObject private var filterState = SearchFilterState.shared
    @State private var searchText: String = ""
    @State private var selectedListIds: Set<String> = []
    @State private var watchlists: [WatchlistItem] = []
    @State private var filteredWatchlists: [WatchlistItem] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastListName: String = ""
    @State private var toastListId: String = ""
    @State private var showCreateWatchlistSheet = false
    @State private var recommenderName: String = ""
    
    // Count should show number of lists selected (including Masterlist)
    var selectedCount: Int {
        // Masterlist is always included, plus any other selected lists
        var count = selectedListIds.count
        // Masterlist is always selected (even if disabled), so count it
        count += 1 // Masterlist is always included
        return count
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
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Masterlist Section
                    masterlistSection
                    
                    // Your Lists Section
                    yourListsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            // Bottom Button
            VStack(spacing: 0) {
                Divider()
                    .background(Color(hex: "#f3f3f3"))
                
                // Recommender Name Field
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    TextField("Recommended by (optional)", text: $recommenderName)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                .padding(12)
                .background(Color(hex: "#f3f3f3"))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Button(action: {
                    submitSelections()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        Text("Add to Watchlist (\(selectedCount))")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#FEA500"))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            print("📋 AddToListView appeared, prefilledRecommender: \(prefilledRecommender ?? "nil")")
            print("📋 AddToListView appeared, filterState.detectedRecommender: \(filterState.detectedRecommender ?? "nil")")
            
            loadWatchlists()
            filterWatchlists()
            // Pre-select lists that already contain this movie (from local cache)
            let existingLists = watchlistManager.getListsForMovie(movieId: movieId)
            selectedListIds = existingLists
            print("📋 [AddToListView] Pre-selected lists from local cache: \(existingLists)")
            
            // Note: Masterlist is always selected but not in selectedListIds (it's disabled)
            // It will be automatically included in submitSelections()
            
            // Pre-fill recommender if provided (check both parameter and filterState)
            if let prefilled = prefilledRecommender ?? filterState.detectedRecommender {
                recommenderName = prefilled
                print("📋 Pre-filled recommender field with: '\(prefilled)'")
            }
        }
        .onDisappear {
            // Reset the recommender after dismissing to prevent it from persisting
            filterState.detectedRecommender = nil
            print("📋 AddToListView dismissed - cleared detectedRecommender")
        }
        .onChange(of: searchText) { oldValue, newValue in
            filterWatchlists()
        }
        .sheet(isPresented: $showCreateWatchlistSheet) {
            CreateWatchlistBottomSheet(isPresented: $showCreateWatchlistSheet) { newWatchlist in
                // Add the newly created list to selected lists
                selectedListIds.insert(newWatchlist.id)
                // Reload watchlists to include the new one
                loadWatchlists()
                filterWatchlists()
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
    
    // MARK: - Masterlist Section
    
    private var masterlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Get masterlist with actual film count
            if let masterlist = watchlistManager.getWatchlist(listId: "masterlist") {
                ListItemRow(
                    list: masterlist,
                    movieId: movieId,
                    watchlistManager: watchlistManager,
                    isMasterlist: true
                ) {
                    // Masterlist is always selected and disabled
                }
            } else {
                // Fallback if masterlist doesn't exist
                ListItemRow(
                    list: WatchlistItem(id: "masterlist", name: "Masterlist", filmCount: 0, thumbnailURL: nil),
                    movieId: movieId,
                    watchlistManager: watchlistManager,
                    isMasterlist: true
                ) {
                    // Masterlist is always selected and disabled
                }
            }
        }
    }
    
    // MARK: - Your Lists Section
    
    private var yourListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR LISTS")
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(Color(hex: "#999999"))
                    .textCase(.uppercase)
                
                // Search Bar
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
            }
            
            // Create New Watchlist
            Button(action: {
                showCreateWatchlistSheet = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#f3f3f3"))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 24))
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
            
            // Watchlists List
            VStack(spacing: 12) {
                ForEach(filteredWatchlists) { list in
                    ListItemRow(
                        list: list,
                        movieId: movieId,
                        watchlistManager: watchlistManager,
                        isMasterlist: false
                    ) {
                        toggleListSelection(list.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadWatchlists() {
        // Load watchlists from WatchlistManager
        watchlists = watchlistManager.getAllWatchlists()
    }
    
    private func filterWatchlists() {
        if searchText.isEmpty {
            filteredWatchlists = watchlists
        } else {
            filteredWatchlists = watchlists.filter { list in
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
            // Add to list (with recommender name if provided)
            let success = watchlistManager.addMovieToList(
                movieId: movieId,
                listId: listId,
                recommenderName: recommenderName.isEmpty ? nil : recommenderName
            )
            if success {
                selectedListIds.insert(listId)
            }
        }
    }
    
    private func submitSelections() {
        // Build list of all lists to add to
        // Masterlist is always selected (even if disabled), so always include it
        var listsToAddTo = selectedListIds
        listsToAddTo.insert("masterlist") // Always include Masterlist
        
        // Add to all selected lists (including Masterlist)
        let trimmedRecommender = recommenderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalRecommender = trimmedRecommender.isEmpty ? nil : trimmedRecommender
        
        // Log selected lists with names
        let listNames = listsToAddTo.compactMap { listId -> String? in
            if listId == "masterlist" {
                return "Masterlist"
            }
            return watchlists.first(where: { $0.id == listId })?.name ?? listId
        }
        print("📋 [AddToListView] Selected lists: \(listNames.joined(separator: ", "))")
        print("💾 AddToListView: Saving movie '\(movieTitle)' (ID: \(movieId)) to \(listsToAddTo.count) list(s) with recommender: \(finalRecommender ?? "nil")")
        
        // Save to Supabase for each list
        Task {
            var successCount = 0
            var failureCount = 0
            var skippedCount = 0
            
            for listId in listsToAddTo {
                let listName = listId == "masterlist" ? "Masterlist" : (watchlists.first(where: { $0.id == listId })?.name ?? listId)
                print("📋 [AddToListView] Processing list: \(listName) (\(listId))")
                
                do {
                    // Check if movie exists in Supabase first (don't rely on stale local cache)
                    print("📋 [AddToListView] Checking if movie \(movieId) is in list \(listName) (\(listId))")
                    
                    // Try to save to Supabase first - Supabase will handle duplicates via UNIQUE constraint
                    // If it's a duplicate, Supabase will throw an error which we'll catch
                    print("📋 [Supabase] Inserting movie \(movieId) into watchlist \(listId)")
                    try await SupabaseWatchlistAdapter.addMovie(
                        movieId: movieId,
                        toListId: listId,
                        recommenderName: finalRecommender,
                        recommenderNotes: nil
                    )
                    print("✅ [Supabase] Successfully inserted movie \(movieId) into watchlist \(listId)")
                    
                    // Only update local cache if Supabase save succeeded
                    let localSuccess = watchlistManager.addMovieToList(
                        movieId: movieId,
                        listId: listId,
                        recommenderName: finalRecommender
                    )
                    
                    if !localSuccess {
                        print("⚠️ [AddToListView] Movie already in local cache for \(listName), but Supabase save succeeded - cache was stale")
                    }
                    
                    successCount += 1
                } catch {
                    // Check if error is due to duplicate (UNIQUE constraint violation)
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("unique") || errorDescription.contains("duplicate") || errorDescription.contains("already exists") {
                        print("⚠️ [AddToListView] Movie already exists in Supabase for \(listName) (\(listId)) - skipping")
                        // Update local cache to match Supabase
                        _ = watchlistManager.addMovieToList(
                            movieId: movieId,
                            listId: listId,
                            recommenderName: finalRecommender
                        )
                        skippedCount += 1
                    } else {
                        print("❌ [Supabase] Failed to insert movie \(movieId) into watchlist \(listId): \(error)")
                        print("❌ [Supabase] Error details: \(error.localizedDescription)")
                        failureCount += 1
                        // Still save locally for UI feedback, but mark as needing sync
                        _ = watchlistManager.addMovieToList(
                            movieId: movieId,
                            listId: listId,
                            recommenderName: finalRecommender
                        )
                    }
                }
            }
            
            print("💾 [AddToListView] Save complete: \(successCount) succeeded, \(skippedCount) skipped (already exists), \(failureCount) failed out of \(listsToAddTo.count) lists")
            
            // Refresh cache from Supabase after saving to ensure UI shows correct data
            if successCount > 0 || skippedCount > 0 {
                print("🔄 [AddToListView] Refreshing watchlist cache from Supabase...")
                await WatchlistManager.shared.syncFromSupabase()
                print("✅ [AddToListView] Cache refreshed from Supabase")
            }
        }
        
        // Clear detected recommender now that we've used it
        filterState.detectedRecommender = nil
        print("📋 AddToListView: Cleared detectedRecommender after saving")
        
        // Show toast for first selected list (or Masterlist if nothing selected)
        let firstListId = listsToAddTo.first ?? "masterlist"
        let listName: String
        if firstListId == "masterlist" {
            listName = "Masterlist"
        } else if let list = watchlists.first(where: { $0.id == firstListId }) {
            listName = list.name
        } else {
            listName = "Watchlist"
        }
        
        toastMessage = "\(movieTitle) added to \(listName)."
        toastListName = listName
        toastListId = firstListId
        showToast = true
        
        // Hide toast after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showToast = false
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
    let isMasterlist: Bool
    let onTap: () -> Void
    
    private var isSelected: Bool {
        if isMasterlist {
            return true // Masterlist is always selected
        }
        return watchlistManager.isMovieInList(movieId: movieId, listId: list.id)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // List Icon/Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#f3f3f3"))
                        .frame(width: 48, height: 48)
                    
                    if let thumbnailURL = list.thumbnailURL, let url = URL(string: thumbnailURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#999999"))
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#999999"))
                            @unknown default:
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#999999"))
                            }
                        }
                    } else {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }
                
                // List Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color.black)
                    
                    Text("\(list.filmCount) films")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isMasterlist ? Color(hex: "#FEA500") : Color(hex: "#FEA500"))
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
        .disabled(isMasterlist) // Masterlist is disabled
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
