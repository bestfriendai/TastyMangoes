//  SwipeableMovieCard.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-27 at 15:45 (America/Los_Angeles - Pacific Time)
//  Notes: Wrapper view that adds swipe-left functionality to SemanticMovieCard, revealing action buttons

import SwiftUI

struct SwipeableMovieCard: View {
    let movie: SemanticMovie
    let onQuickAdd: () -> Void
    let onAddToList: () -> Void
    let onMarkWatched: () -> Void
    var onTap: (() -> Void)? = nil // Optional tap handler for navigation
    
    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed: Bool = false
    @State private var isDragging: Bool = false
    @State private var isHorizontalDrag: Bool? = nil // nil = undetermined
    
    // Button width (each button is 80pt wide)
    private let buttonWidth: CGFloat = 80
    private let totalButtonWidth: CGFloat = 240 // 3 buttons × 80pt
    private let minimumDragThreshold: CGFloat = 30 // Increased to let ScrollView win for vertical scrolls
    
    var body: some View {
        SemanticMovieCard(movie: movie)
            .offset(x: dragOffset)
            .background(
                // Action buttons positioned behind the card, right-aligned
                // Only show buttons when card is swiped (dragOffset < -10)
                Group {
                    if dragOffset < -10 {
                        HStack(spacing: 0) {
                            Spacer() // Push buttons to the right
                            
                            HStack(spacing: 0) {
                                // Quick Add button (green)
                                quickAddButton
                                // Lists button (blue)
                                listsButton
                                // Watched button (gray)
                                watchedButton
                            }
                        }
                    }
                }
            )
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: minimumDragThreshold)
                    .onChanged { value in
                        // On first movement, determine if this is horizontal or vertical
                        if isHorizontalDrag == nil {
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            // Only treat as horizontal swipe if width > height * 1.5
                            isHorizontalDrag = horizontal > vertical * 1.5
                            print("🎬 [Swipe] Drag direction determined - horizontal: \(isHorizontalDrag ?? false), h: \(horizontal), v: \(vertical)")
                            
                            // If vertical, don't process at all - let ScrollView handle it
                            if isHorizontalDrag == false {
                                return
                            }
                        }
                        
                        // Only process if determined to be horizontal
                        guard isHorizontalDrag == true else { return }
                        
                        print("🎬 [Swipe] Horizontal drag, translation: \(value.translation.width)")
                        isDragging = true
                        // Only allow swiping left (negative width)
                        let newOffset = min(0, max(-totalButtonWidth, value.translation.width))
                        dragOffset = newOffset
                    }
                    .onEnded { value in
                        // Only process if it was a horizontal drag
                        if isHorizontalDrag == true {
                            print("🎬 [Swipe] Horizontal drag ended, final offset: \(dragOffset)")
                            // Determine if we should snap to revealed or closed position
                            let threshold = -totalButtonWidth / 2
                            
                            if dragOffset < threshold {
                                // Snap to revealed position (show buttons)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = -totalButtonWidth
                                    isRevealed = true
                                }
                            } else {
                                // Snap back to closed position
                                slideBack()
                            }
                            
                            // Reset isDragging after a short delay to allow tap detection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isDragging = false
                            }
                        }
                        // Reset for next gesture
                        isHorizontalDrag = nil
                    }
            )
            .onTapGesture {
                print("🎬 [Swipe] Tap detected, isDragging: \(isDragging), dragOffset: \(dragOffset), isRevealed: \(isRevealed)")
                // Tap card to close if revealed
                if isRevealed {
                    slideBack()
                } else if !isDragging && dragOffset == 0 {
                    // Only navigate if NOT dragging AND card is in default position
                    onTap?()
                }
            }
    }
    
    // MARK: - Action Buttons
    
    private var quickAddButton: some View {
        Button(action: {
            onQuickAdd()
            slideBack()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                Text("Add")
                    .font(.caption2)
            }
            .frame(width: buttonWidth)
            .frame(maxHeight: .infinity)
            .foregroundColor(.white)
            .background(Color(hex: "#648d00"))
        }
    }
    
    private var listsButton: some View {
        Button(action: {
            onAddToList()
            slideBack()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 22))
                Text("Lists")
                    .font(.caption2)
            }
            .frame(width: buttonWidth)
            .frame(maxHeight: .infinity)
            .foregroundColor(.white)
            .background(Color(hex: "#007AFF"))
        }
    }
    
    private var watchedButton: some View {
        Button(action: {
            onMarkWatched()
            slideBack()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                Text("Watched")
                    .font(.caption2)
            }
            .frame(width: buttonWidth)
            .frame(maxHeight: .infinity)
            .foregroundColor(.white)
            .background(Color(hex: "#8E8E93"))
        }
    }
    
    private func slideBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = 0
            isRevealed = false
            isDragging = false
        }
    }
}

