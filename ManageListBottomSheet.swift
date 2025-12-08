//  ManageListBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 03:44 (America/Los_Angeles - Pacific Time)
//  Notes: Created Manage List bottom sheet with Edit, Manage, Duplicate List, and Delete options matching Figma design. Implemented Edit, Manage, and Duplicate functionality. Fixed deprecated NavigationLink by using fullScreenCover for navigation.

import SwiftUI

struct ManageListBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    let listId: String
    let listName: String
    
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showManageView = false
    
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
            
            // Menu Items
            VStack(spacing: 4) {
                // Edit
                MenuItemRow(
                    icon: "pencil",
                    title: "Edit",
                    description: nil,
                    isDestructive: false
                ) {
                    showEditSheet = true
                }
                
                // Manage
                MenuItemRow(
                    icon: "list.bullet.rectangle",
                    title: "Manage",
                    description: "Quickly change the order, move, or delete items from the list.",
                    isDestructive: false
                ) {
                    dismiss()
                    // Trigger navigation after sheet dismisses
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showManageView = true
                    }
                }
                
                // Duplicate List
                MenuItemRow(
                    icon: "doc.on.doc",
                    title: "Duplicate List",
                    description: nil,
                    isDestructive: false
                ) {
                    duplicateList()
                }
                
                // Delete
                MenuItemRow(
                    icon: "trash",
                    title: "Delete",
                    description: nil,
                    isDestructive: true
                ) {
                    showDeleteConfirmation = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(314)])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteListBottomSheet(
                isPresented: $showDeleteConfirmation,
                listId: listId,
                listName: listName
            )
            .environmentObject(watchlistManager)
        }
        .sheet(isPresented: $showEditSheet) {
            EditListBottomSheet(
                isPresented: $showEditSheet,
                listId: listId,
                currentName: listName
            )
            .environmentObject(watchlistManager)
        }
        .fullScreenCover(isPresented: $showManageView) {
            NavigationStack {
                IndividualListView(listId: listId, listName: listName)
                    .environmentObject(watchlistManager)
            }
        }
    }
    
    private func duplicateList() {
        if watchlistManager.duplicateWatchlist(listId: listId) != nil {
            dismiss()
            // Optionally show a toast or navigate to the new list
        }
    }
}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let icon: String
    let title: String
    let description: String?
    let isDestructive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isDestructive ? Color(hex: "#e11a00") : Color(hex: "#333333"))
                    .frame(width: 24, height: 24)
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(isDestructive ? Color(hex: "#e11a00") : Color(hex: "#333333"))
                    
                    if let description = description {
                        Text(description)
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ManageListBottomSheet(isPresented: .constant(true), listId: "1", listName: "Must-Watch Movies")
}

