//  SortByBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-11-17 at 02:27 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-11-17 at 02:55 (America/Los_Angeles - Pacific Time)
//  Notes: Created Sort by bottom sheet with radio options (List order, Date added, Alphabetical) matching Figma design. Implemented sort functionality with callback.

import SwiftUI

struct SortByBottomSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    let currentSort: WatchlistManager.SortOption
    let onApply: (WatchlistManager.SortOption) -> Void
    
    @State private var selectedOption: WatchlistManager.SortOption
    
    init(isPresented: Binding<Bool>, currentSort: WatchlistManager.SortOption, onApply: @escaping (WatchlistManager.SortOption) -> Void) {
        self._isPresented = isPresented
        self.currentSort = currentSort
        self.onApply = onApply
        self._selectedOption = State(initialValue: currentSort)
    }
    
    private var sortOptions: [(WatchlistManager.SortOption, String)] {
        [
            (.listOrder, "List order"),
            (.dateAdded, "Date added"),
            (.alphabetical, "Alphabetical (A → Z)")
        ]
    }
    
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
                Text("Sort by")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#333333"))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Sort Options
            VStack(spacing: 0) {
                ForEach(sortOptions, id: \.0) { option in
                    SortOptionRow(
                        title: option.1,
                        isSelected: selectedOption == option.0
                    ) {
                        selectedOption = option.0
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Spacer()
            
            // Apply Button
            VStack(spacing: 0) {
                Divider()
                    .background(Color(hex: "#f3f3f3"))
                
                Button(action: {
                    onApply(selectedOption)
                    dismiss()
                }) {
                    Text("Apply")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#333333"))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(346)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Sort Option Row

struct SortOptionRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(Color(hex: "#333333"))
                
                Spacer()
                
                // Radio Button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "#FEA500") : Color(hex: "#b3b3b3"), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#FEC966"))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SortByBottomSheet(
        isPresented: .constant(true),
        currentSort: .listOrder
    ) { _ in }
}

