//  RateBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 14:50 (America/Los_Angeles - Pacific Time)
//  Notes: Rate bottom sheet component matching Figma design - allows users to rate movies with star rating system

import SwiftUI

struct RateBottomSheet: View {
    @Binding var isPresented: Bool
    let movieId: String
    let movieTitle: String
    @State private var selectedRating: Int = 0
    @State private var showToast: Bool = false
    
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
                
                // Star Rating
                HStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { rating in
                        Button(action: {
                            selectedRating = rating
                        }) {
                            Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(rating <= selectedRating ? Color(hex: "#FFA500") : Color(hex: "#e0e0e0"))
                        }
                    }
                }
                .padding(.vertical, 16)
                
                // Rating Label
                if selectedRating > 0 {
                    Text("\(selectedRating) / 10")
                        .font(.custom("Nunito-Bold", size: 18))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                }
                
                // Submit Button
                Button(action: {
                    submitRating()
                }) {
                    Text("Submit Rating")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedRating > 0 ? Color(hex: "#333333") : Color(hex: "#e0e0e0"))
                        .cornerRadius(8)
                }
                .disabled(selectedRating == 0)
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
    }
    
    private func submitRating() {
        // TODO: Save rating to backend/database
        print("Rating submitted: \(selectedRating)/10 for movie \(movieId)")
        
        // Show toast notification
        showToast = true
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
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

