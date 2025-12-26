//  RefinementChipsView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Horizontal scrollable chips for search refinement

import SwiftUI

struct RefinementChipsView: View {
    let chips: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button(action: { onSelect(chip) }) {
                        Text(chip)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

