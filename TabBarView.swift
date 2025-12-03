//
//  TabBarView.swift
//  TastyMangoes
//
//  Rewritten to fix scroll-gesture conflicts with MoviePageView
//  Last updated on 2025-11-16 at 02:10 (California time)
//  Last modified: 2025-12-03 at 11:28 PST by Cursor Assistant
//  Notes: Added TalkToMango voice interaction with listening view and glow animation. Fixed stuck listening state: resets showListeningView on app launch, ensures recognizer stops on launch if active, prevents auto-restart after dismissal.
//

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab = 0   // Default to Home
    @ObservedObject private var filterState = SearchFilterState.shared
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showListeningView = false
    @State private var isListening = false
    @State private var animatePulse = false
    
    // Computed property for selection count
    private var totalSelections: Int {
        filterState.selectedPlatforms.count + filterState.selectedGenres.count
    }
    
    // Show tab bar only when no selections are made AND no search query
    private var shouldShowTabBar: Bool {
        totalSelections == 0 && filterState.searchQuery.isEmpty
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
                // Placeholder for AI chat / Talk to Mango
                Color(.systemBackground)
                    .overlay(
                        Text("Talk to Mango (Coming Soon)")
                            .font(.title3)
                            .foregroundColor(.gray)
                    )
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
                CustomTabBar(
                    selectedTab: $selectedTab,
                    showListeningView: $showListeningView,
                    isListening: $isListening,
                    animatePulse: $animatePulse,
                    speechRecognizer: speechRecognizer
                )
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showListeningView) {
            MangoListeningView(
                speechRecognizer: speechRecognizer,
                isPresented: $showListeningView
            )
            .onDisappear {
                // Ensure showListeningView is false when view disappears
                // This prevents stuck state after app restart
                if showListeningView {
                    print("🎤 fullScreenCover onDisappear - ensuring showListeningView is false")
                    showListeningView = false
                }
            }
        }
        .onAppear {
            // Ensure listening view is not shown on app launch
            // Reset to false in case it was stuck from previous session
            if showListeningView {
                print("⚠️ App launched with showListeningView=true - resetting to false")
                showListeningView = false
            }
            // Also ensure recognizer is in idle state
            let isActive: Bool
            switch speechRecognizer.state {
            case .listening, .requesting:
                isActive = true
            default:
                isActive = false
            }
            if isActive {
                print("⚠️ App launched with recognizer active - stopping")
                Task {
                    speechRecognizer.stopListening(reason: "appLaunch")
                }
            }
        }
        .onChange(of: speechRecognizer.state) { oldState, newState in
            print("🎤 TabBarView: speechRecognizer state changed from \(oldState) to \(newState)")
            // Update listening state for glow animation
            switch newState {
            case .listening, .requesting:
                isListening = true
                withAnimation {
                    animatePulse = true
                }
            case .idle, .processing, .error:
                isListening = false
                withAnimation {
                    animatePulse = false
                }
            }
        }
        .onChange(of: showListeningView) { oldValue, newValue in
            print("🎤 TabBarView: showListeningView changed from \(oldValue) to \(newValue)")
            
            // When listening view is dismissed, ensure we stop recording
            // But only if it was actually dismissed (not just initialized)
            if !newValue && oldValue {
                print("🎤 Listening view was dismissed")
                // Stop recording if still active
                if isListening || animatePulse {
                    print("🎤 Listening view dismissed while recording active, stopping recording")
                    Task {
                        speechRecognizer.stopListening(reason: "viewDismissed")
                    }
                }
                // IMPORTANT: Do NOT automatically restart or set showListeningView back to true
                // Only user tap should set it to true
            }
            
            // Prevent auto-restart: Never set showListeningView = true automatically
            // It should only be set by user tap on the button
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showListeningView: Bool
    @Binding var isListening: Bool
    @Binding var animatePulse: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    
    var body: some View {
        ZStack {
            // Tab bar background with gradient top border
            VStack(spacing: 0) {
                // Gradient border at top
                LinearGradient(
                    colors: [
                        Color(red: 255/255, green: 237/255, blue: 204/255),
                        Color(red: 255/255, green: 237/255, blue: 204/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                
                // White background
                Color.white
                    .frame(height: 60)
            }
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
                    // Present listening view instead of switching tabs
                    // Only set to true if not already true (prevent double-tap issues)
                    if !showListeningView {
                        print("🎤 User tapped TalkToMango button")
                        showListeningView = true
                    } else {
                        print("⚠️ TalkToMango button tapped but view already showing - ignoring")
                    }
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
                    .scaleEffect(animatePulse ? 1.06 : 1.0)
                    .shadow(
                        color: Color(hex: "#FFA500").opacity(animatePulse ? 0.6 : 0.4),
                        radius: animatePulse ? 16 : 12,
                        x: 0,
                        y: 4
                    )
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: animatePulse
                    )
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
