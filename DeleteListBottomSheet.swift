//  DeleteListBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-05 at 19:54 (America/Los_Angeles - Pacific Time)
//  Notes: Added onDeleteComplete callback to dismiss parent ManageListBottomSheet after deletion. Prevents automatically opening next list's delete dialog.

import SwiftUI

struct DeleteListBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    let listId: String
    let listName: String
    var onDeleteComplete: (() -> Void)? = nil // Callback to dismiss parent sheet
    
    @State private var showToast = false
    
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Delete List")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                
                Text("Are your sure you want delete \(listName) from your list? Films from this list will be available in Masterlist.")
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#333333"))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 0) {
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
                    
                    // Delete Button
                    Button(action: {
                        deleteList()
                    }) {
                        Text("Delete")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#e11a00"))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(262)])
        .presentationDragIndicator(.hidden)
        .overlay(alignment: .top) {
            if showToast {
                DeleteToastView(
                    listName: listName,
                    onUndo: {
                        // Undo delete - recreate the list
                        // Note: This is a simplified undo - in a real app, you'd want to restore the full state
                        _ = watchlistManager.createWatchlist(name: listName)
                        showToast = false
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
                .padding(.top, 60)
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func deleteList() {
        // Delete list from WatchlistManager
        watchlistManager.deleteWatchlist(listId: listId)
        showToast = true
        
        // Dismiss this sheet first
        dismiss()
        
        // Then dismiss the parent ManageListBottomSheet after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onDeleteComplete?()
        }
        
        // Hide toast after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - Delete Toast View

struct DeleteToastView: View {
    let listName: String
    let onUndo: () -> Void
    
    @State private var isVisible: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon Area
            ZStack {
                Circle()
                    .fill(Color(hex: "#fdfdfd"))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#e11a00"))
            }
            
            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text("The List Has Been Deleted")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                
                Text("\(listName) has been removed from your lists.")
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            Spacer()
            
            // Undo Button
            Button(action: onUndo) {
                Text("Undo")
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(Color(hex: "#414141"))
                    .underline()
            }
        }
        .padding(12)
        .background(Color(hex: "#f3f3f3"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#e11a00").opacity(0.24), lineWidth: 1)
        )
        .cornerRadius(8)
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
    DeleteListBottomSheet(isPresented: .constant(true), listId: "1", listName: "Must-Watch Movies")
}

