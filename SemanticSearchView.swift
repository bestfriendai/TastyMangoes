//  SemanticSearchView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Main view for semantic search feature with Mango's AI personality

import SwiftUI

struct SemanticSearchView: View {
    @StateObject private var viewModel = SemanticSearchViewModel()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.movies.isEmpty {
                    resultsView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Ask Mango")
            .navigationBarTitleDisplayMode(.inline)
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
            
            // Mic button (for voice input - integrate with existing voice system)
            Button(action: {
                // TODO: Trigger voice input
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
                
                // Refinement chips
                if !viewModel.refinementChips.isEmpty {
                    RefinementChipsView(chips: viewModel.refinementChips) { chip in
                        Task {
                            await viewModel.refine(with: chip)
                        }
                    }
                }
                
                // Movie cards
                ForEach(viewModel.movies) { movie in
                    SemanticMovieCard(movie: movie)
                        .padding(.horizontal)
                        .onTapGesture {
                            // Navigate to movie detail
                            // TODO: Integrate with existing navigation
                        }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var emptyStateView: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchFocused = false
        
        Task {
            await viewModel.search(query: searchText)
        }
    }
}

