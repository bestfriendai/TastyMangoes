//
//  TabBarView.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-09 at 17:30 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude on 2025-12-09 at 19:15 (America/Los_Angeles - Pacific Time)
//
//  Version: v16
//  Changes: More translucent (0.85 opacity), shorter content area (72pt) to push icons lower
//

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0   // Default to Home
    @ObservedObject private var filterState = SearchFilterState.shared
    @StateObject private var mangoSpeechRecognizer = SpeechRecognizer()
    @State private var showMangoListeningView = false
    @State private var showSemanticSearch = false
    @State private var semanticSearchQuery: String = ""
    
    // Computed property for selection count
    private var totalSelections: Int {
        filterState.selectedPlatforms.count + filterState.selectedGenres.count
    }
    
    // Show tab bar always - it should be pinned at the bottom on all screens
    private var shouldShowTabBar: Bool {
        true // Always show the tab bar
    }
    
    var body: some View {
        // MARK: - Tab Content (NO TabView – manual switcher)
        Group {
            switch selectedTab {
            case 0:
                HomeView()
            case 1:
                SearchView()
            case 2:
                // Talk to Mango - show background, listening view will be presented as fullScreenCover
                Color(.systemBackground)
                    .onAppear {
                        // Automatically present MangoListeningView when tab 2 is selected
                        if !showMangoListeningView {
                            showMangoListeningView = true
                        }
                    }
                    .onChange(of: selectedTab) { oldValue, newValue in
                        // Dismiss listening view when switching away from tab 2
                        if newValue != 2 {
                            showMangoListeningView = false
                        } else if oldValue != 2 {
                            // Present when switching to tab 2 (only if coming from another tab)
                            showMangoListeningView = true
                        }
                    }
            case 3:
                WatchlistView()
            case 4:
                ProfileView(selectedTab: $selectedTab)
                    .environmentObject(AuthManager.shared)
                    .environmentObject(UserProfileManager.shared)
            default:
                SearchView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowTabBar {
                CustomTabBar(selectedTab: $selectedTab, showMangoListeningView: $showMangoListeningView)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showMangoListeningView) {
            MangoListeningView(
                speechRecognizer: mangoSpeechRecognizer,
                isPresented: $showMangoListeningView,
                onTranscriptReceived: { transcript in
                    // Route voice transcript to semantic search
                    semanticSearchQuery = transcript
                    showMangoListeningView = false
                    showSemanticSearch = true
                },
                skipAutoProcessing: true  // Skip VoiceIntentRouter, use callback instead
            )
        }
        .fullScreenCover(isPresented: $showSemanticSearch) {
            NavigationStack {
                SemanticSearchView(initialQuery: semanticSearchQuery)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showSemanticSearch = false
                            }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mangoNavigateToSearch)) { _ in
            print("🍋 [TabBarView] Received mangoNavigateToSearch notification - switching to Search tab")
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .mangoNavigateToHome)) { _ in
            print("🍋 [TabBarView] Received mangoNavigateToHome notification - switching to Home tab")
            selectedTab = 0
            showMangoListeningView = false  // Ensure listening view is dismissed
        }
    }
}

// MARK: - Custom Tab Bar (v16)
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showMangoListeningView: Bool
    
    var body: some View {
        // Content stays in 72pt (was 92pt), background extends into safe area
        ZStack {
            // Tab items
            HStack(spacing: 0) {
                TabBarItem(
                    icon: "house.fill",
                    label: "Home",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                TabBarItem(
                    icon: "magnifyingglass",
                    label: "Search",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                // Center spacer for AI button
                Spacer()
                    .frame(width: 88)
                
                TabBarItem(
                    icon: "list.bullet",
                    label: "Watchlist",
                    isSelected: selectedTab == 3
                ) {
                    selectedTab = 3
                }
                
                TabBarItem(
                    icon: "ellipsis",
                    label: "More",
                    isSelected: selectedTab == 4
                ) {
                    selectedTab = 4
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8) // Push icons down within the frame
            
            // Floating AI Button (Talk to Mango)
            VStack {
                Spacer()
                
                Button {
                    selectedTab = 2
                    showMangoListeningView = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#FFA500"),
                                        Color(hex: "#FF8C00")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        MangoLogoIcon(size: 28, color: .white)
                    }
                    .shadow(color: Color(hex: "#FFA500").opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .offset(y: -24) // Adjusted for shorter height
                
                Text("Talk to Mango")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                    .offset(y: -16) // Adjusted for shorter height
            }
        }
        .frame(height: 72) // Reduced from 92pt - pushes content closer to bottom
        .background(
            // This background extends into the safe area
            Color.white.opacity(0.85) // More translucent (was 0.92)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    // Gray color for tab bar icons
    private let grayColor = Color(red: 153/255, green: 153/255, blue: 153/255)
    
    // Render the appropriate TMIcon based on tab type and selection state
    @ViewBuilder
    private var iconView: some View {
        if icon == "house.fill" {
            // Home tab
            if isSelected {
                TMHomeFilledIcon(size: 24, color: grayColor)
            } else {
                TMHomeIcon(size: 24, color: grayColor)
            }
        } else if icon == "magnifyingglass" {
            // Search tab
            if isSelected {
                TMSearchFilledIcon(size: 24, color: grayColor)
            } else {
                TMSearchIcon(size: 24, color: grayColor)
            }
        } else if icon == "list.bullet" {
            // Watchlist tab
            if isSelected {
                TMListFilledIcon(size: 24, color: grayColor)
            } else {
                TMListIcon(size: 24, color: grayColor)
            }
        } else if icon == "ellipsis" {
            // More tab (no filled version, use same icon for both states)
            TMMenuDotsIcon(size: 24, color: grayColor)
        } else {
            // Fallback to SF Symbol if icon type not recognized
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(grayColor)
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Use TMIcon components - filled when selected, outline when not
                iconView
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? Color(red: 51/255, green: 51/255, blue: 51/255) : Color(red: 153/255, green: 153/255, blue: 153/255))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - More View (Placeholder)
struct MoreView: View {
    var body: some View {
        ZStack {
            Color(red: 253/255, green: 253/255, blue: 253/255)
                .ignoresSafeArea()
            Text("More")
                .font(.largeTitle)
        }
    }
}

#Preview {
    TabBarView()
}
