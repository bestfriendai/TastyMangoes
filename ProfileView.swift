//  ProfileView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 16:20 (America/Los_Angeles - Pacific Time)
//  Notes: User profile view for managing username and streaming subscriptions - matches app design patterns

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var profileManager: UserProfileManager
    @Binding var selectedTab: Int
    @State private var editingUsername = false
    @State private var newUsername = ""
    @State private var selectedSubscriptions: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let allPlatforms = SupabaseConfig.availablePlatforms
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header Section
                        VStack(spacing: 16) {
                            // Avatar
                            Circle()
                                .fill(Color(hex: "#E0E0E0"))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(hex: "#666666"))
                                )
                            
                            // Username Section
                            VStack(spacing: 12) {
                                if editingUsername {
                                    HStack(spacing: 12) {
                                        TextField("Username", text: $newUsername)
                                            .font(.custom("Inter-Regular", size: 16))
                                            .foregroundColor(Color(hex: "#333333"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color(hex: "#f3f3f3"))
                                            .cornerRadius(8)
                                        
                                        Button(action: {
                                            saveUsername()
                                        }) {
                                            Text("Save")
                                                .font(.custom("Nunito-SemiBold", size: 14))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(Color(hex: "#FEA500"))
                                                .cornerRadius(8)
                                        }
                                        
                                        Button(action: {
                                            editingUsername = false
                                            newUsername = profileManager.username
                                        }) {
                                            Text("Cancel")
                                                .font(.custom("Nunito-SemiBold", size: 14))
                                                .foregroundColor(Color(hex: "#666666"))
                                        }
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Text(profileManager.username.isEmpty ? "No username" : profileManager.username)
                                            .font(.custom("Nunito-Bold", size: 20))
                                            .foregroundColor(Color(hex: "#1a1a1a"))
                                        
                                        Button(action: {
                                            newUsername = profileManager.username
                                            editingUsername = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "#666666"))
                                        }
                                    }
                                }
                                
                                // Email (read-only)
                                if let email = getCurrentUserEmail() {
                                    Text(email)
                                        .font(.custom("Inter-Regular", size: 14))
                                        .foregroundColor(Color(hex: "#666666"))
                                }
                            }
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                        
                        // Streaming Subscriptions Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Streaming Subscriptions")
                                .font(.custom("Nunito-Bold", size: 18))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                                .padding(.horizontal, 20)
                            
                            // Platform Checkboxes
                            VStack(spacing: 12) {
                                ForEach(allPlatforms, id: \.self) { platform in
                                    PlatformSubscriptionRow(
                                        platform: platform,
                                        isSelected: selectedSubscriptions.contains(platform),
                                        onToggle: {
                                            if selectedSubscriptions.contains(platform) {
                                                selectedSubscriptions.remove(platform)
                                            } else {
                                                selectedSubscriptions.insert(platform)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                        
                        // Save Button
                        Button(action: {
                            saveSubscriptions()
                        }) {
                            Text("Save Subscriptions (\(selectedSubscriptions.count))")
                                .font(.custom("Nunito-Bold", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#FFC966"), Color(hex: "#FFA500")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                        
                        // Sign Out Button
                        Button(action: {
                            Task {
                                do {
                                    try await authManager.signOut()
                                } catch {
                                    self.errorMessage = "Error signing out: \(error.localizedDescription)"
                                }
                            }
                        }) {
                            Text("Sign Out")
                                .font(.custom("Nunito-Bold", size: 16))
                                .foregroundColor(Color(hex: "#333333"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#f3f3f3"))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(hex: "#fdfdfd"))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Reload profile and subscriptions from database when view appears
                await profileManager.loadProfile()
                selectedSubscriptions = Set(profileManager.subscriptions)
            }
            .onChange(of: profileManager.subscriptions) { oldValue, newValue in
                // Update selected subscriptions when profileManager updates
                selectedSubscriptions = Set(newValue)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserEmail() -> String? {
        // TODO: Get email from auth manager when available
        // For now, return nil - will be implemented when auth is fully set up
        return nil
    }
    
    private func saveUsername() {
        guard !newUsername.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Username cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await profileManager.updateUsername(newUsername.trimmingCharacters(in: .whitespaces))
                editingUsername = false
                isLoading = false
            } catch {
                errorMessage = "Error updating username: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func saveSubscriptions() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await profileManager.updateSubscriptions(Array(selectedSubscriptions))
                // Reload to ensure we have the latest data from database
                await profileManager.loadProfile()
                selectedSubscriptions = Set(profileManager.subscriptions)
                isLoading = false
                errorMessage = nil
                
                // Navigate back to Search view (tab 1) after saving
                selectedTab = 1
            } catch {
                errorMessage = "Error saving subscriptions: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Platform Subscription Row

struct PlatformSubscriptionRow: View {
    let platform: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color(hex: "#FEA500") : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color(hex: "#FEA500") : Color(hex: "#b3b3b3"), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Platform Name
                Text(platform)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ProfileView(selectedTab: .constant(4))
        .environmentObject(AuthManager.shared)
        .environmentObject(UserProfileManager.shared)
}
