//  CreateWatchlistBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:52 (America/Los_Angeles - Pacific Time)
//  Notes: Created bottom sheet for creating new watchlists with name input field matching Figma design

import SwiftUI

struct CreateWatchlistBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    
    @State private var listName: String = ""
    @State private var isCreating: Bool = false
    
    var onCreate: ((WatchlistItem) -> Void)?
    
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
            
            // Title
            HStack {
                Text("Create New Watchlist")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                // List Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.custom("Nunito-SemiBold", size: 14))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    TextField("Enter list name...", text: $listName)
                        .font(.custom("Inter-Regular", size: 16))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#f3f3f3"))
                        .cornerRadius(8)
                        .submitLabel(.done)
                        .onSubmit {
                            if !listName.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating {
                                createWatchlist()
                            }
                        }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.vertical, 12)
            
            // Buttons
            VStack(spacing: 0) {
                Divider()
                    .background(Color(hex: "#f3f3f3"))
                
                HStack(spacing: 12) {
                    // Cancel Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(Color(hex: "#414141"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                            .cornerRadius(8)
                    }
                    
                    // Create Button
                    Button(action: {
                        createWatchlist()
                    }) {
                        Text("Create")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(listName.trimmingCharacters(in: .whitespaces).isEmpty ? Color(hex: "#b3b3b3") : Color(hex: "#333333"))
                            .cornerRadius(8)
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(262)])
        .presentationDragIndicator(.hidden)
    }
    
    private func createWatchlist() {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        isCreating = true
        
        // Create the watchlist
        let newWatchlist = watchlistManager.createWatchlist(name: trimmedName)
        
        // Call the callback if provided
        onCreate?(newWatchlist)
        
        // Dismiss the sheet
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    CreateWatchlistBottomSheet(isPresented: .constant(true))
        .environmentObject(WatchlistManager.shared)
}

