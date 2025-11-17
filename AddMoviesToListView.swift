//  AddMoviesToListView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 03:17 (America/Los_Angeles - Pacific Time)
//  Notes: Created view for adding movies to a watchlist with search functionality. When a movie is tapped, it's added directly to the list with a toast notification.

import SwiftUI

struct AddMoviesToListView: View {
    let listId: String
    let listName: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#fdfdfd")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    headerView
                    
                    // Search Content
                    searchContentView
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastNotificationView(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
                    .padding(.top, 60)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Movies")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Text("to \(listName)")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#666666"))
                
                TextField("Search movies...", text: $searchViewModel.searchQuery)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchViewModel.searchQuery.isEmpty {
                    Button(action: {
                        searchViewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Search Content View
    
    private var searchContentView: some View {
        Group {
            if searchViewModel.showSuggestions || (searchViewModel.searchQuery.isEmpty && !SearchHistoryManager.shared.getSearchHistory().isEmpty) {
                suggestionsView
            } else if searchViewModel.isSearching {
                loadingView
            } else if let error = searchViewModel.error {
                errorView(error: error)
            } else if searchViewModel.hasSearched && searchViewModel.searchResults.isEmpty {
                emptyStateView
            } else if !searchViewModel.searchResults.isEmpty {
                resultsListView
            } else {
                categoriesView
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Searching movies...")
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(error: TMDBError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FF6B6B"))
            
            Text("Oops!")
                .font(.custom("Nunito-Bold", size: 24))
                .foregroundColor(Color(hex: "#1a1a1a"))
            
            Text(error.localizedDescription)
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#CCCCCC"))
            
            Text("No movies found")
                .font(.custom("Nunito-Bold", size: 24))
                .foregroundColor(Color(hex: "#1a1a1a"))
            
            Text("Try a different search term")
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Suggestions View
    
    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if searchViewModel.searchQuery.isEmpty {
                    // Show search history
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Recent Searches")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            ForEach(SearchHistoryManager.shared.getSearchHistory().prefix(5), id: \.self) { query in
                                SearchHistoryItem(
                                    query: query,
                                    onTap: {
                                        searchViewModel.selectSuggestion(query)
                                    },
                                    onRemove: {
                                        SearchHistoryManager.shared.removeFromHistory(query)
                                    }
                                )
                            }
                        }
                    }
                } else {
                    // Show search suggestions
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(searchViewModel.searchSuggestions.prefix(5), id: \.self) { suggestion in
                            SearchSuggestionItem(
                                suggestion: suggestion,
                                query: searchViewModel.searchQuery,
                                onTap: {
                                    searchViewModel.selectSuggestion(suggestion)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Results List View
    
    private var resultsListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Results count
                HStack {
                    Text("\(searchViewModel.searchResults.count) results found")
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Movie cards
                LazyVStack(spacing: 12) {
                    ForEach(searchViewModel.searchResults) { movie in
                        Button(action: {
                            addMovieToList(movieId: String(movie.id), movieTitle: movie.title)
                        }) {
                            SearchMovieCard(movie: movie)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Categories View
    
    private var categoriesView: some View {
        SearchCategoriesView()
    }
    
    // MARK: - Helper Methods
    
    private func addMovieToList(movieId: String, movieTitle: String) {
        let wasAdded = watchlistManager.addMovieToList(movieId: movieId, listId: listId)
        
        if wasAdded {
            toastMessage = "\(movieTitle) added to \(listName)"
            withAnimation {
                showToast = true
            }
            
            // Hide toast after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showToast = false
                }
            }
        } else {
            toastMessage = "\(movieTitle) is already in \(listName)"
            withAnimation {
                showToast = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showToast = false
                }
            }
        }
    }
}

// MARK: - Toast Notification View

struct ToastNotificationView: View {
    let message: String
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#648d00"))
            
            Text(message)
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#333333"))
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
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
    AddMoviesToListView(listId: "1", listName: "My Watchlist")
        .environmentObject(WatchlistManager.shared)
}

