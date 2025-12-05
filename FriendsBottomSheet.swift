//  FriendsBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:15 (America/Los_Angeles - Pacific Time)
//  Notes: Friends bottom sheet component matching Figma design - shows friends who liked this movie

import SwiftUI

struct FriendsBottomSheet: View {
    @Binding var isPresented: Bool
    
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
            VStack(alignment: .leading, spacing: 24) {
                Text("Liked by:")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .padding(.top, 8)
                
                // Friends list (placeholder)
                VStack(spacing: 12) {
                    ForEach(["Sarah", "Mike", "Emma", "Alex"], id: \.self) { friend in
                        HStack {
                            Circle()
                                .fill(Color(hex: "#E0E0E0"))
                                .frame(width: 40, height: 40)
                            
                            Text(friend)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(Color(hex: "#333333"))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                }
                
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
}

#Preview {
    FriendsBottomSheet(isPresented: .constant(true))
}

