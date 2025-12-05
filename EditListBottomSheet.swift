//  EditListBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 03:22 (America/Los_Angeles - Pacific Time)
//  Notes: Created bottom sheet for editing watchlist name with text field and save/cancel actions matching Figma design

import SwiftUI

struct EditListBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchlistManager: WatchlistManager
    let listId: String
    let currentName: String
    
    @State private var newListName: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
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
                Text("Edit List")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Text Field
            VStack(alignment: .leading, spacing: 8) {
                Text("List Name")
                    .font(.custom("Inter-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "#666666"))
                
                TextField("Enter list name", text: $newListName)
                    .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(Color(hex: "#1a1a1a"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#f3f3f3"))
                    .cornerRadius(8)
                    .submitLabel(.done)
                    .onSubmit {
                        if isValidName {
                            saveListName()
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
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
                            .foregroundColor(Color(hex: "#333333"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#f3f3f3"))
                            .cornerRadius(8)
                    }
                    
                    // Save Button
                    Button(action: {
                        saveListName()
                    }) {
                        Text("Save")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isValidName ? Color(hex: "#333333") : Color(hex: "#b3b3b3"))
                            .cornerRadius(8)
                    }
                    .disabled(!isValidName)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            newListName = currentName
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isValidName: Bool {
        !newListName.trimmingCharacters(in: .whitespaces).isEmpty && newListName != currentName
    }
    
    private func saveListName() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "List name cannot be empty"
            showAlert = true
            return
        }
        
        guard trimmedName != currentName else {
            dismiss()
            return
        }
        
        watchlistManager.updateWatchlistName(listId: listId, newName: trimmedName)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    EditListBottomSheet(isPresented: .constant(true), listId: "1", currentName: "My Watchlist")
        .environmentObject(WatchlistManager.shared)
}

