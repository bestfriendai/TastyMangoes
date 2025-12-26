//  SemanticSearchView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Main view for semantic search feature with Mango's AI personality

import SwiftUI

struct SemanticSearchView: View {
    @StateObject private var viewModel = SemanticSearchViewModel()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var searchText = ""
    @State private var showListeningView = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    let initialQuery: String?
    
    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if viewModel.isLoading && viewModel.movies.isEmpty && viewModel.refinementChips.isEmpty {
                    // Show loading only if we have no results and no chips yet
                    loadingView
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
                } else {
                    // Show results (chips + movies) or empty state
                    resultsView
                }
            }
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
                    RefinementChipsView(chips: viewModel.refinementChips) { chip in
                        Task {
                            await viewModel.refine(with: chip)
                        }
                    }
                    .padding(.top, viewModel.mangoText.isEmpty ? 8 : 0)
                }
                
                // Loading indicator (if loading and we have chips but no movies yet)
                if viewModel.isLoading && viewModel.movies.isEmpty && !viewModel.refinementChips.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Finding movies...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Movie cards
                if !viewModel.movies.isEmpty {
                    ForEach(viewModel.movies) { movie in
                        NavigationLink(destination: movieDetailView(for: movie)) {
                            SemanticMovieCard(movie: movie)
                                .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
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
            do {
                // Skip auto-processing since we handle it via callback
                try await speechRecognizer.startListening(config: .talkToMango, talkToMangoMode: .oneShot, skipAutoProcessing: true)
                showListeningView = true
            } catch {
                print("⚠️ Failed to start voice input: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private func movieDetailView(for semanticMovie: SemanticMovie) -> some View {
        // Convert SemanticMovie to Movie for navigation
        if let card = semanticMovie.card {
            // Create Movie from MovieCard
            let movie = Movie(
                id: card.tmdbId,
                title: card.title,
                year: card.year ?? 0,
                trailerURL: card.trailerYoutubeId.map { "https://www.youtube.com/watch?v=\($0)" },
                trailerDuration: nil,
                posterImageURL: card.poster?.medium ?? card.poster?.large ?? card.poster?.small,
                tastyScore: card.aiScore,
                aiScore: card.aiScore,
                voteAverage: card.sourceScores?.tmdb?.score,
                genres: card.genres ?? [],
                rating: card.certification,
                director: card.director,
                writer: card.writer,
                screenplay: card.screenplay,
                composer: card.composer,
                runtime: card.runtimeDisplay,
                releaseDate: card.releaseDate,
                language: nil,
                overview: card.overview ?? card.overviewShort
            )
            MovieDetailView(movie: movie)
        } else if let preview = semanticMovie.preview, let tmdbId = preview.tmdbId {
            // Create minimal Movie from preview (will fetch full details)
            let movie = Movie(
                id: String(tmdbId),
                title: preview.title,
                year: preview.year ?? 0,
                trailerURL: nil,
                trailerDuration: nil,
                posterImageURL: nil,
                tastyScore: nil,
                aiScore: nil,
                voteAverage: nil,
                genres: [],
                rating: nil,
                director: nil,
                writer: nil,
                screenplay: nil,
                composer: nil,
                runtime: nil,
                releaseDate: nil,
                language: nil,
                overview: nil
            )
            MovieDetailView(movie: movie)
        } else {
            // Fallback - shouldn't happen
            Text("Movie details unavailable")
        }
    }
}

