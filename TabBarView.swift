//
//  TabBarView.swift
//  TastyMangoes
//
//  Rewritten to fix scroll-gesture conflicts with MoviePageView
//  Last updated on 2025-11-16 at 02:10 (California time)
//

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0   // Default to Home
    @ObservedObject private var filterState = SearchFilterState.shared
    @StateObject private var mangoSpeechRecognizer = SpeechRecognizer()
    @State private var showMangoListeningView = false
    
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
            // MARK: - Custom Tab Bar - anchored to bottom safe area
            // Only show when no selections are made
            if shouldShowTabBar {
                VStack(spacing: 0) {
                    // No separator - just the tab bar
                    CustomTabBar(selectedTab: $selectedTab, showMangoListeningView: $showMangoListeningView)
                }
                .background(Color.white.ignoresSafeArea(edges: .top)) // Extend white background upward to cover any separator
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showMangoListeningView) {
            MangoListeningView(
                speechRecognizer: mangoSpeechRecognizer,
                isPresented: $showMangoListeningView
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .mangoNavigateToSearch)) { _ in
            print("🍋 [TabBarView] Received mangoNavigateToSearch notification - switching to Search tab")
            selectedTab = 1
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showMangoListeningView: Bool
    
    var body: some View {
        ZStack {
            // Tab bar background - white background extends fully
            Color.white
                .frame(height: 60)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: -2)
            
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
            .frame(height: 60)
            .padding(.horizontal, 16)
            
            // Floating AI Button (Talk to Mango) - prominent orange circular background
            VStack {
                Spacer()
                
                Button {
                    // Switch to tab 2 and show listening view
                    selectedTab = 2
                    showMangoListeningView = true
                } label: {
                    ZStack {
                        // Prominent filled orange circular background with gradient
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
                                // Border with white opacity
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    .frame(width: 56, height: 56)
                            )
                            .overlay(
                                // Inner shadow/glow effect
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                    .blendMode(.overlay)
                            )
                        
                        // White mango logo icon inside the circle (matches Figma)
                        MangoLogoIcon(size: 28, color: .white)
                    }
                    .shadow(color: Color(hex: "#FFA500").opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .offset(y: -34)
                
                // Label below button
                Text("Talk to Mango")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                    .offset(y: -24)
            }
        }
        .frame(height: 60)
        .background(Color.white)
    }
}

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


// WatchlistView is now in its own file

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
