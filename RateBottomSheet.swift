//  RateBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:50 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-12-03 at 16:57 (America/Los_Angeles - Pacific Time)
//  Notes: Rate bottom sheet component matching Figma design - allows users to rate movies with 1-5 star rating system. Updated from 1-10 to 1-5 stars to match database schema.

import SwiftUI
import Auth

struct RateBottomSheet: View {
    @Binding var isPresented: Bool
    let movieId: String
    let movieTitle: String
    @State private var selectedRating: Int = 0 // 0 = no rating, 1-5 = star rating
    @State private var showToast: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
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
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("Rate This Movie")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                    
                    Text(movieTitle)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#666666"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, 8)
                
                // Star Rating (1-5 stars)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { rating in
                        Button(action: {
                            // Toggle: if tapping the same star, clear rating (set to 0)
                            selectedRating = (selectedRating == rating) ? 0 : rating
                        }) {
                            Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(rating <= selectedRating ? Color(hex: "#FFA500") : Color(hex: "#e0e0e0"))
                                .accessibilityLabel("\(rating) out of 5 stars")
                                .accessibilityHint(selectedRating == rating ? "Tap to remove rating" : "Tap to rate \(rating) stars")
                        }
                    }
                }
                .padding(.vertical, 16)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rating: \(selectedRating > 0 ? "\(selectedRating) out of 5 stars" : "No rating selected")")
                
                // Rating Label
                if selectedRating > 0 {
                    Text("\(selectedRating) / 5")
                        .font(.custom("Nunito-Bold", size: 18))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                } else {
                    Text("Tap a star to rate")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(hex: "#999999"))
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                }
                
                // Submit Button
                Button(action: {
                    Task {
                        await submitRating()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(selectedRating > 0 ? "Submit Rating" : "Remove Rating")
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedRating > 0 ? Color(hex: "#333333") : Color(hex: "#999999"))
                .cornerRadius(8)
                .disabled(isLoading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
        .task {
            await loadExistingRating()
        }
    }
    
    private func loadExistingRating() async {
        do {
            guard let userId = try await supabaseService.getCurrentUser()?.id else {
                print("⚠️ RateBottomSheet: No authenticated user")
                return
            }
            
            if let existingRating = try await supabaseService.getUserRating(userId: userId, movieId: movieId) {
                // Load existing rating (1-5) into selectedRating
                selectedRating = existingRating.rating
                print("✅ Loaded existing rating: \(selectedRating) stars for movie \(movieId)")
            }
        } catch {
            print("⚠️ Error loading existing rating: \(error)")
            // Don't show error to user - just proceed with no rating
        }
    }
    
    private func submitRating() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            guard let userId = try await supabaseService.getCurrentUser()?.id else {
                errorMessage = "Please sign in to rate movies"
                return
            }
            
            if selectedRating > 0 {
                // Save rating (1-5 stars) with feedback_source = "quick_star"
                _ = try await supabaseService.addOrUpdateRating(
                    userId: userId,
                    movieId: movieId,
                    rating: selectedRating,
                    reviewText: nil,
                    feedbackSource: "quick_star"
                )
                print("✅ Rating saved: \(selectedRating) stars for movie \(movieId) (user: \(userId.uuidString))")
            } else {
                // Remove rating (delete from database)
                try await supabaseService.deleteRating(userId: userId, movieId: movieId)
                print("✅ Rating removed for movie \(movieId) (user: \(userId.uuidString))")
            }
            
            // Show success toast and dismiss
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPresented = false
            }
        } catch {
            // Log detailed error information
            print("❌ Failed to save rating for movie \(movieId):")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error userInfo: \(nsError.userInfo)")
            }
            
            // Show user-friendly error message
            errorMessage = "Failed to save rating. Please try again."
        }
    }
}

// MARK: - Preview

#Preview {
    RateBottomSheet(
        isPresented: .constant(true),
        movieId: "550",
        movieTitle: "Fight Club"
    )
}

