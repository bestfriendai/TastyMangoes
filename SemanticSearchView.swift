//  SemanticSearchView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Main view for semantic search feature with Mango's AI personality

import SwiftUI
import Auth

struct SemanticSearchView: View {
    @StateObject private var viewModel = SemanticSearchViewModel()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var searchText = ""
    @State private var showListeningView = false
    @State private var showAddToList = false
    @State private var showRateSheet = false
    @State private var selectedMovieForList: SemanticMovie?
    @State private var selectedMovieForRating: SemanticMovie?
    @State private var navigationPath = NavigationPath()
    @State private var refreshTrigger = UUID()
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watchlistManager = WatchlistManager.shared
    
    let initialQuery: String?
    
    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if viewModel.isLoading && viewModel.movies.isEmpty && viewModel.refinementChips.isEmpty {
                    // Show loading - Mango animation
                    loadingView
                        .background(Color(.systemBackground))
                } else if let error = viewModel.error {
                    // Show error state
                    VStack(spacing: 16) {
                        Text("⚠️")
                            .font(.system(size: 60))
                        Text("Something went wrong")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") {
                            performSearch()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    // Show results (chips + movies) or empty state
                    resultsView
                        .background(
                            // Faint orange background for semantic search results
                            Color.orange.opacity(0.08)
                        )
                }
            }
            .background(Color(.systemBackground))  // Ensure NavigationStack has proper background
            .navigationTitle("Ask Mango")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.canGoBack {
                        Button(action: {
                            viewModel.goBack()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.body)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: String.self) { movieId in
                MoviePageView(movieId: movieId)
            }
        }
        .task {
            // If initial query provided (from voice), perform search automatically
            // Use .task instead of .onAppear to ensure it runs even if view appears quickly
            if let query = initialQuery, !query.isEmpty, viewModel.movies.isEmpty {
                print("🔍 [SemanticSearchView] Auto-searching with initial query: '\(query)'")
                searchText = query
                await viewModel.search(query: query)
            }
        }
        .fullScreenCover(isPresented: $showListeningView) {
            MangoListeningView(
                speechRecognizer: speechRecognizer,
                isPresented: $showListeningView,
                onTranscriptReceived: { transcript in
                    searchText = transcript
                    showListeningView = false
                    performSearch()
                }
            )
        }
        .sheet(isPresented: $showAddToList) {
            if let movie = selectedMovieForList {
                let movieId = movie.card?.tmdbId ?? (movie.preview?.tmdbId.map { String($0) } ?? "")
                AddToListView(
                    movieId: movieId,
                    movieTitle: movie.displayTitle,
                    prefilledRecommender: SearchFilterState.shared.detectedRecommender
                )
                .onDisappear {
                    // Refresh watchlist data when sheet closes (user may have added to lists)
                    Task {
                        await WatchlistManager.shared.syncFromSupabase()
                        // Force view refresh
                        refreshTrigger = UUID()
                    }
                }
            }
        }
        .sheet(isPresented: $showRateSheet) {
            if let movie = selectedMovieForRating {
                let movieId = movie.card?.tmdbId ?? (movie.preview?.tmdbId.map { String($0) } ?? "")
                RateBottomSheet(
                    isPresented: $showRateSheet,
                    movieId: movieId,
                    movieTitle: movie.displayTitle,
                    onRatingSubmitted: { rating in
                        handleRatingSubmitted(movie: movie, rating: rating)
                    }
                )
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Try 'Christmas movies for kids'...", text: $searchText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Mic button (for voice input)
            Button(action: {
                startVoiceInput()
            }) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            // Mango animation placeholder
            Text("🥭")
                .font(.system(size: 60))
                .rotationEffect(.degrees(viewModel.isLoading ? 10 : -10))
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isLoading)
            
            Text("Finding perfect picks...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Mango's spoken text (shown as subtitle)
                if !viewModel.mangoText.isEmpty {
                    HStack {
                        Text("🥭")
                        Text(viewModel.mangoText)
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Refinement chips - show if available (even when loading or no movies)
                if !viewModel.refinementChips.isEmpty {
                    RefinementChipsView(
                        chips: viewModel.refinementChips,
                        selectedChip: viewModel.selectedChip,
                        isLoading: viewModel.isLoading
                    ) { chip in
                        Task {
                            await viewModel.refine(with: chip)
                        }
                    }
                    .padding(.top, viewModel.mangoText.isEmpty ? 8 : 0)
                }
                
                // Loading indicator (if loading and we have chips but no movies yet, OR if chip is tapped)
                if viewModel.isLoading && ((viewModel.movies.isEmpty && !viewModel.refinementChips.isEmpty) || viewModel.selectedChip != nil) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(viewModel.selectedChip != nil ? "Refining search..." : "Finding movies...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Movie cards
                if !viewModel.movies.isEmpty {
                    ForEach(viewModel.movies) { movie in
                        SwipeableMovieCard(
                            movie: movie,
                            onQuickAdd: {
                                quickAddToMasterlist(movie: movie)
                            },
                            onAddToList: {
                                selectedMovieForList = movie
                                showAddToList = true
                            },
                            onMarkWatched: {
                                selectedMovieForRating = movie
                                showRateSheet = true
                            },
                            onTap: {
                                navigateToMovie(movie: movie)
                            }
                        )
                        .padding(.horizontal, 16)
                        .id("\(movie.id)-\(refreshTrigger)")
                    }
                } else if !viewModel.isLoading && viewModel.refinementChips.isEmpty && viewModel.mangoText.isEmpty {
                    // Empty state - only show if not loading, no chips, and no mango text
                    VStack(spacing: 20) {
                        Text("🥭")
                            .font(.system(size: 80))
                        
                        Text("Hey! I'm Mango")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Ask me anything about movies.\nTry something like:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 12) {
                            suggestionButton("Christmas movies for kids")
                            suggestionButton("War movies based on true stories")
                            suggestionButton("Feel-good movies that aren't cheesy")
                            suggestionButton("Movies like Die Hard")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollContentBackground(.hidden)  // Hide default scroll background to use our custom background
    }
    
    
    private func suggestionButton(_ text: String) -> some View {
        Button(action: {
            searchText = text
            performSearch()
        }) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func performSearch() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }
        guard !viewModel.isLoading else { return }  // Prevent duplicate searches
        isSearchFocused = false
        
        Task {
            await viewModel.search(query: trimmedQuery)
        }
    }
    
    private func startVoiceInput() {
        Task {
            // Skip auto-processing since we handle it via callback
            await speechRecognizer.startListening(config: .talkToMango, talkToMangoMode: .oneShot, skipAutoProcessing: true)
            showListeningView = true
        }
    }
    
    private func quickAddToMasterlist(movie: SemanticMovie) {
        let movieId = movie.card?.tmdbId ?? (movie.preview?.tmdbId.map { String($0) } ?? "")
        guard !movieId.isEmpty else { return }
        
        Task {
            do {
                try await SupabaseWatchlistAdapter.addMovie(
                    movieId: movieId,
                    toListId: "masterlist",
                    recommenderName: SearchFilterState.shared.detectedRecommender,
                    recommenderNotes: nil
                )
                // Update local cache
                _ = watchlistManager.addMovieToList(
                    movieId: movieId,
                    listId: "masterlist",
                    recommenderName: SearchFilterState.shared.detectedRecommender
                )
                print("✅ [SemanticSearchView] Quick added \(movie.displayTitle) to Masterlist")
                
                // Refresh watchlist data to update card states
                await WatchlistManager.shared.syncFromSupabase()
                
                // Force view refresh
                refreshTrigger = UUID()
            } catch {
                print("❌ [SemanticSearchView] Error quick adding to Masterlist: \(error)")
            }
        }
    }
    
    private func handleRatingSubmitted(movie: SemanticMovie, rating: Int) {
        let movieId = movie.card?.tmdbId ?? (movie.preview?.tmdbId.map { String($0) } ?? "")
        guard !movieId.isEmpty else { return }
        
        Task {
            // Mark as watched
            watchlistManager.markAsWatched(movieId: movieId)
            
            // Save rating if provided (rating > 0)
            if rating > 0 {
                do {
                    guard let userId = try await SupabaseService.shared.getCurrentUser() else {
                        print("❌ [SemanticSearchView] No user ID for rating")
                        return
                    }
                    _ = try await SupabaseService.shared.addOrUpdateRating(
                        userId: userId.id,
                        movieId: movieId,
                        rating: rating,
                        reviewText: nil
                    )
                    print("✅ [SemanticSearchView] Saved rating \(rating)/5 for \(movie.displayTitle)")
                } catch {
                    print("❌ [SemanticSearchView] Error saving rating: \(error)")
                }
            }
            
            // Remove movie from all watchlists
            await removeMovieFromAllLists(movieId: movieId)
            
            // Refresh watchlist data to update card states
            await WatchlistManager.shared.syncFromSupabase()
            
            // Force view refresh
            refreshTrigger = UUID()
        }
    }
    
    private func removeMovieFromAllLists(movieId: String) async {
        // Get all lists containing this movie
        let allLists = watchlistManager.getListsForMovie(movieId: movieId)
        
        // Remove from local cache
        for listId in allLists {
            watchlistManager.removeMovieFromList(movieId: movieId, listId: listId)
        }
        
        // Sync with Supabase - remove from all lists
        do {
            for listId in allLists {
                try await SupabaseWatchlistAdapter.removeMovie(
                    movieId: movieId,
                    fromListId: listId
                )
                print("✅ [SemanticSearchView] Removed movie \(movieId) from list \(listId) in Supabase")
            }
        } catch {
            print("❌ [SemanticSearchView] Failed to remove movie \(movieId) from Supabase: \(error)")
        }
    }
    
    private func getMovieId(for movie: SemanticMovie) -> String {
        if let card = movie.card {
            return card.tmdbId
        } else if let preview = movie.preview, let tmdbId = preview.tmdbId {
            return String(tmdbId)
        }
        return ""
    }
    
    private func navigateToMovie(movie: SemanticMovie) {
        let movieId = getMovieId(for: movie)
        if !movieId.isEmpty {
            navigationPath.append(movieId)
        }
    }
}

