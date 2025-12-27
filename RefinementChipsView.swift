//  RefinementChipsView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Horizontal scrollable chips for search refinement with loading states

import SwiftUI

struct RefinementChipsView: View {
    let chips: [String]
    let selectedChip: String?
    let isLoading: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    ChipButton(
                        chip: chip,
                        isSelected: selectedChip == chip,
                        isLoading: isLoading && selectedChip == chip,
                        isDisabled: isLoading && selectedChip != chip,
                        onSelect: { onSelect(chip) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ChipButton: View {
    let chip: String
    let isSelected: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isDisabled && !isLoading else { return }
            onSelect()
        }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                }
                
                Text(chip)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected 
                    ? Color.orange.opacity(0.3)  // Selected/loading state - more opaque
                    : Color.orange.opacity(0.15)  // Normal state
            )
            .foregroundColor(
                isDisabled 
                    ? Color.orange.opacity(0.5)  // Disabled state - dimmed
                    : Color.orange  // Normal/selected state
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.orange : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

